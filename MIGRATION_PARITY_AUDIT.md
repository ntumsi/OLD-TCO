# AMCOS Migration Parity Audit — WebForms/SQL Server → ASP.NET Core 8/PostgreSQL

Date: 2026-06-25. Scope: verify (a) functional parity between the legacy WebForms app and the migrated Core app, and (b) that the Core app works against PostgreSQL the way the legacy app worked against SQL Server.

## How the migration is structured (important context)

- `AMCOS.Logic` and `AMCOS.Data` are **net8.0 C# libraries shared/already-migrated** (they use Npgsql; no SQL Server provider remains). The legacy `AMCOS.Web` (VB.NET, .NET Framework 4.8) is kept only as the "before" reference — its reference to these net8.0 libs is no longer buildable.
- So the migration is really three layers: **web UI** (WebForms `.aspx`/`.asmx` → Razor Pages/Controllers), **data access** (shared libs converted to Npgsql/EF Core), and the **database** (SQL Server DB project `AMCOS.AMCOS2020_MAR` → hand-written PG migrations `AMCOS.PostgreSQL/migrations`).
- `MIGRATION_NOTES.md` is **stale** — it claims Xwalk, Civilian PCS, Admin, and Project Details are placeholders, but they are actually implemented. It should be rewritten.

## Severity legend
- **CRITICAL** = the feature will throw / return wrong data at runtime on Postgres (verified).
- **HIGH** = likely broken or silently wrong.
- **MEDIUM** = functional gap vs legacy (feature regression).

---

## 1. Database-layer correctness (Postgres) — CRITICAL, verified directly

The data layer is where the migration is most incomplete. The EF LINQ paths for *correctly-mapped* entities are Postgres-correct (an `OnModelCreating` loop lowercases identifiers to match PG folding). But large gaps remain:

### 1.1 Core data tables are never created
`data.Costs`, `data.Inventory`, `data.PaySchedules`, `data.LocalityRates`, `data.CategoryGroup`, `data.CategorySubgroup`, and `BLS_OES.OccupationalEmploymentStatistics*` have EF `DbSet`s and are referenced **108×** by the stored procedures in `007_stored_procedures.sql`, but have **no `CREATE TABLE` in any migration** (`002_data_tables.sql` only creates asafmc/avalara/fms* tables). Costing/inventory/pay cannot work. *(verified)*

### 1.2 `006_functions.sql` is an empty placeholder (0 functions)
None of the ~36 `web.*` scalar/table functions exist. This breaks:
- **Called directly from C#:** `web.CostsCCE`, `web.CostsCCEInflated` (Lite/Costs), `web.PMGetCategories`, `web.PMGetCategoriesAll`, `web.PMGetProjectOutputs`, `web.GetPMReportInflationRateHeader`, `web.ProjectCategoryCount`, `web.GetPendingUserCount` (rendered on every authenticated page header). *(verified `costscce` absent)*
- **Helpers the 29 ported procs call internally:** `web.GetCosts`, `web.FormatGradeLevel`, `web.PMCostsByPayPlan[/CCE/ReserveComponents]`, `web.GetUnitPersonnel` — so even the procs that *are* present in `007` fail at runtime.

### 1.3 Missing web views — `008_views.sql` defines only 1 of ~6
Missing: `web.CivLocationPerDiem`, `web.PendingUsers`, `web.AMCOSVersionCY`, `web.Inventory`, `web.PMCategorySkillInventory`. Note `CivLocationPerDiem` was a **VIEW** in SQL Server but was migrated as an **empty TABLE** (`004`), so per-diem lookups silently return nothing.

### 1.4 Entities mapped with dotted `[Table("schema.Name")]` resolve to the wrong schema — verified
EF Core does **not** split a dotted `[Table("lookup.AOC")]` into schema+table; it becomes table name `"lookup.aoc"` in the **default** schema. Confirmed at runtime: `AOC -> schema=(null) table=lookup.aoc`. Any query throws `relation "lookup.aoc" does not exist`. Affected (no fluent `ToTable`): `AOC, MOS, WOMOS, Grade, WageArea, Organization, Role, LocalityRates, CMF_Branch_FA, FIPS_ZIP, LocalityPayArea_FIPS, GS_OccupationalGroup/Series, AMCOSVersion`, the `crunch/data Costs_*` entities, and `webuser.User_Macom/User_Roles/User_Summaries/User_SummaryElements`. Entities with explicit fluent `ToTable(name, schema)` (e.g. `AMCOSUser`, `PMProject`) are fine. **Fix:** change to `[Table("AOC", Schema="lookup")]` or add fluent `ToTable`.

### 1.5 `lookup.validemailsuffix` created with zero columns — verified
`001_lookup_tables.sql:558` creates the table with an empty body while EF maps `EmailSuffix` → email-suffix validation throws.

### 1.6 Raw-SQL SQL-Server-isms in `AMCOS.Logic` (hard errors)
- **`CALL` on functions** — `web.pmcopyproject`/`projectaddunit`/`deleteproject` are `FUNCTION ... RETURNS void` (verified), but called via `CALL`/`CommandType.StoredProcedure`; PG only allows `CALL` on procedures → throws. (`Project.cs:36,492,667`, `ProjectManager.cs:528`) **Fix:** `SELECT web.fn(...)`.
- **`CommandType.StoredProcedure` against jsonb-returning functions** — `web.getinventory[wage]`, `web.getpayplancrosswalk*`, `web.getcivpcs*` return `(result_set_name text, row_data jsonb)`; the C# expects flat tabular columns. Wrong call mechanism *and* wrong result shape. (`Inventory.cs`, `PayPlanCrosswalk.cs`, `Helpers/PCSPropertyHelper.cs`)
- **`DELETE <table>` without `FROM`** — `ProjectFactory.cs:64`, `ProjectCategorySkillInventory.cs:125`, `CategoryFactory.cs:15` → syntax error in PG.
- **`@@IDENTITY`** — `CategoryFactory.cs:30` → use `INSERT ... RETURNING categoryid`.
- **`[ProjectName]` bracket identifiers + missing/mismatched params** — `ProjectFactory.cs:87-109`.
- `DataAccessUtility.cs:37` `CommandTimeout = 900000` — Npgsql timeout is **seconds** (≈250 hrs); likely intended ms.

### 1.7 Other schema/type fidelity
- **Composite PK loss:** `CostSummary`, `CostElement`, `MetropolitanStatisticalArea` — EF keys on a single/nullable column vs the real `(…, AmcosVersionId[End])` PK → wrong identity-map/joins. **HIGH**
- **`WarehouseContext`** lacks the identifier-lowercasing loop → its PascalCase `ToTable("Category","warehouse")` mappings query quoted mixed-case names that don't exist. **HIGH (if used)**
- **`GENERATED ALWAYS AS IDENTITY`** on all id PKs blocks explicit-id inserts (data migration/seeding); SQL Server `IDENTITY` was permissive. `GENERATED BY DEFAULT` is the faithful choice. **MEDIUM**
- **Timestamps:** all datetime → `timestamp` (without tz) + `EnableLegacyTimestampBehavior=true` is a faithful pairing for SQL Server `DATETIME`. Low risk; just ensure the AppContext switch runs before any Npgsql connection opens.
- `bit→boolean`, `numeric`, `float→double precision`, PostGIS `geometry/geography` targets are correct where present (spatial columns aren't actually mapped by EF — acceptable only if unused).

---

## 2. Web functional parity — mostly good, with specific regressions

Most pages are genuinely ported (contrary to MIGRATION_NOTES). Confirmed regressions vs legacy:

| Area | Status | Gap |
|---|---|---|
| **AMCOS Lite** (`Pages/App/Lite`) | PARTIAL | Lost the C3.js cost chart, appropriation color-coding, weapon-system & CCE salary-limit highlighting, and secondary appropriation/inflation summary grids — Core renders only `tables[0]`. Numbers correct, analytical presentation gone. |
| **Project Report** (`Report.cshtml.cs`) | PARTIAL | Data preserved (6 worksheets, Excel export) but missing subtotal rows, salary-limit highlighting, expandable discounted views, per-appropriation coloring. (matches README #3) |
| **Admin user delete** | MISSING | Legacy `UpdateMyProfile.aspx` let an admin delete a user and cascade-purge their projects/reports/login history. No delete path exists in Core. |
| **Admin user-list filters** (`Admin/Users`) | PARTIAL | Lost CompanyName + date-range filters (created/updated/last-login/login-history/approved/denied). |
| **RSS note viewer** (`Public/note.aspx`) | MISSING | In-app news viewer (`note.aspx?noteid=`) has no Core counterpart. |
| **Resources doc menu / `dist/` assets** | PARTIAL | `_Layout` links only 2 PDFs vs the legacy doc set; depends on un-packaged legacy `dist/` (README #3). |
| Xwalk, Civilian PCS, Admin (Users/Approvals/SponsorAction/Inventory/Log/Dashboards), Project Details wizard, Data Calculations/Skills | PORTED | Implemented (MIGRATION_NOTES wrongly lists as placeholders). Config-gated where QuickSight is involved. |

AJAX endpoints were correctly re-pointed (`.asmx` → `/api/lite/LogChoices`, `/api/project/LogAddUnit`, `LookupApiController`).

---

## 3. Prioritized remediation plan

**P0 — Postgres data layer (app is non-functional for costing/projects without these):**
1. Author `006_functions.sql` — port all `web.*` functions actually used (direct + helper). Source: `AMCOS.AMCOS2020_MAR/web/Functions/*.sql`.
   - **DONE (Tier A, 2026-06-25):** Ported the self-contained PM/admin functions — `web.getpendingusercount`, `web.formatgradelevel`, `web.projectcategorycount`, `web.pmgetcategories`, `web.pmgetcategoriesall`, `web.pmgetprojectoutputs`. Verified by running migrations 000-008 + seed against a throwaway Postgres 16/PostGIS container (all create cleanly; functions return correct results).
   - **DONE (Tier B, 2026-06-25):** Ported all ~29 cost-engine functions into `006b_costengine_functions.sql` as `LANGUAGE plpgsql` (deferred resolution) — `crunch.getsinglevalue`, `web.getcosts`, `web.costscce`, `web.costscceinflated`, `web.getminmaxpay`, `web.pmcostsbypayplan[/cce/reservecomponents]`, `web.getinflationrateheader`, `web.getpmreportinflationrateheader`, `web.pminflatedvalue`, `web.getunitpersonnel` (+ `getsacsyears`/`getextendedyears`/`getalllocationidbyinstallation`/`getlastmtoeunityear`/`getunitauthorizationdocument`/`getlocationdisplayname`), `web.pminventorybyskillid`, `web.pmvalidateunitrequirement[/cce/noncce]`, `web.payplancontainstag`, `web.getcostsummaryid/name`, `web.getarmycestitles`, `web.getadjustedavgannualizedcostoffica`, `web.getprojectyearstart/duration`. **All 12 entry-point functions execute without error** against a freshly-migrated+seeded throwaway DB (return empty until ETL loads `crunch.*`).
2. **DONE (Tier B, 2026-06-25):** Created the web-needed cost-engine base layer in `005b_costengine_tables.sql` — the 15 `crunch.Costs_*` tables, `crunch.InventoryProcessed/Inventory_GFEBS/WASS_Processed`, `crunch.GSAPerDiem`, `crunch.PayScheduleMinMax`, `crunch.Costs_1ActiveDay`, `dataload.DoSPerDiem`, and the two `"BLS_OES".OccupationalEmploymentStatistics*` tables; plus the `data.*` **views** (`data.costs` [15-way union], `data.costscce`, `data.inventory`, `data.costelement`, `data.currentdefaultsummarycostelements`) in `008`. The `PaySchedule.*` schema + pay-processing crunch tables were intentionally OMITTED (crunch-engine internals not read by the web app). These tables are EMPTY until the Python `etl/` populates them.
3. Author the missing `web.*` views in `008_views.sql`; make `CivLocationPerDiem` a view again (not an empty table).
   - **DONE (2026-06-25):** Added `web.amcosversioncy`, `web.pendingusers` (and removed its placeholder table from `004`), `web.pmcategoryskillinventory`, plus the `data.*` views above. Verified against seed data.
   - **REMAINING:** `web.Inventory` and `web.CivLocationPerDiem` (currently empty tables) could be re-expressed as views; low priority since the EF entities read them fine and they're ETL-populated.

**Status:** the entire migration set (000 → 008, incl. 005b/006b) + seed applies cleanly from scratch, and every web-app DB dependency now exists — the app no longer throws "relation/function does not exist". **What remains for Tier B is DATA, not schema:** run the Python ETL to populate `crunch.*`/`data.*`, then do a cost-MATH validation pass (the function bodies are faithful translations but unverifiable against empty tables; a few flagged runtime nuances — e.g. `crunch.costs_1activeday` lacks a `categorygroupcode` column its caller references — only surface with real data).
4. Fix raw-SQL bugs in `AMCOS.Logic` (CALL→SELECT, DELETE FROM, @@IDENTITY→RETURNING, brackets, jsonb-result unpacking, CommandType).
   - **DONE (2026-06-25):** `Project.cs` — the three `CALL web.fn(...)` invocations (Copy / AddUnit / DeleteProject) changed to `SELECT web.fn(...)` since those are functions, not procedures. These are the live project paths used by the web pages.
   - **N/A — dead code:** `ProjectFactory`, `CategoryFactory`, `ProjectManager`, `ProjectCategorySkillInventory`, `DataLayerModule` are NOT referenced anywhere in `AMCOS.Web.Core`/`AMCOS.Logic` (confirmed by grep). Their `DELETE`-without-`FROM`, `@@IDENTITY`, `[bracket]`, and broken-`Update` bugs do not affect the running app and were left untouched (fixing confused dead code risks introducing wrong behavior). They should be deleted or rewritten if ever revived.
   - **No change needed:** `ProjectRequirement.cs` calls `web.PMGetCategories`/`PMGetCategoriesAll` which now exist (item 1); its SQL is already correct (`SELECT * FROM web.fn(...)`, `CommandType.Text`).
   - **DONE (2026-06-25, jsonb-shape):** Added shared helper `AMCOS.Logic/Helpers/StoredFunction.QueryAsTable` that invokes a `web.*` function as `SELECT row_data FROM fn(args)` and projects the `(result_set_name, row_data jsonb)` result into a flat `DataTable` (columns = jsonb keys; works for fixed and dynamic/pivot shapes; DataTable lookups are case-insensitive so callers keep PascalCase names). Rewired `Helpers/PCSPropertyHelper.cs` (4 functions), `Inventory.cs` (GetInventoryOther/GetInventoryWage), and `PayPlanCrosswalk.cs` (5 functions) to use it, and fixed a null→DBNull parameter in the PCS query method. Also fixed a pre-existing bug in `007`'s `getmaxreleaseversionsperyear` (`WHERE CY >= p_start` compared text≥integer → added `CY::integer` cast). Verified: `getmaxreleaseversionsperyear(2020)` returns correct rows; the Tier-B functions (`getpayplancrosswalk*`, `getcivpcs*`, `getinventory*`) now fail **only** on missing `data.costs`/`crunch.gsaperdiem` (their real Tier-B dependency) instead of on the wrong call mechanism.
5. Fix dotted `[Table]` entity mappings (schema split).
   - **DONE (2026-06-25):** All 44 entity `[Table("schema.Name")]` attributes in `AMCOS.Data/Entities/` changed to `[Table("Name", Schema = "schema")]`. Verified at runtime that EF now resolves e.g. `AOC -> lookup.aoc`, `MOS -> lookup.mos`, `UserMACOM -> webuser.user_macom` (was `(null).lookup.aoc` before). Confirmed `lookup.aoc` is queryable against a seeded DB.
6. Fix `lookup.validemailsuffix` columns; fix composite PKs; add lowercasing to `WarehouseContext`.
   - **DONE (2026-06-25):** `lookup.validemailsuffix` now has its `emailsuffix varchar(25)` PK column (`001`). Verified against a freshly-migrated+seeded throwaway Postgres.
   - **N/A — dead code:** `WarehouseContext` is not referenced by the web app; left untouched (noted for if revived).
   - **REMAINING:** composite-PK entities (`CostSummary`, `CostElement`, `MetropolitanStatisticalArea`) feed the cost layer (Tier B) and need the entity classes' version columns + `HasKey` corrected — deferred with the cost-engine work.

**P1 — feature regressions:**
- **DONE (2026-06-25, navigation):** Restored full legacy nav in `_Layout.cshtml` — Data menu now has the QuickSight visualizations (Inventory / Pay Schedule / GS Locality Rates by ZIP) via a new user-facing `Pages/App/Data/Visualization.cshtml` (mirrors the Xwalk embed; `[Authorize]`, slug-mapped), kept Cost Elements/Skills; expanded **Resources** to the legacy "Help Docs" set (CBA Guide, Fact Sheet, FAQ, Cost Model Docs, Cost Element Data Dictionary, the four Methodologies, the five Tutorials, Data Exports, Request Data Export, CES Xwalk); added the **ASA (FM&C)** external link; added **HelpSpot Historical Data** to Admin. Verified all items render and the viz page returns 200 (valid slug) / 404 (bad slug).
- **DONE (2026-06-25, admin user-delete):** Added `OnPostDelete` to `Admin/Users` — a transactional cascade delete (inventory → reports → skills → categories → projects → pcs projects → login history → user, in FK order) with a per-row Delete button (confirm dialog; self-delete blocked). Cascade order validated against a seeded throwaway DB (user + project removed cleanly, COMMIT, no FK violations).
- **DONE (2026-06-25, user-list filters):** Added the legacy `CompanyName` filter plus date-range filters (Created, Last Login, Approved, Denied) to `Admin/Users`. Verified rendering against the local DB.
- **DONE (2026-06-25, AMCOS Lite):**
  - *Data path* — `DataAccessUtility.ExecuteStoredProcDataSet` now invokes the function as `SELECT * FROM fn(...)` (was `CALL`, invalid on a function), fixes the 900000→900 s timeout, and expands the `(result_set_name, row_data jsonb)` result into a multi-table DataSet — handling both the per-row shape AND the nested-payload shape (`{costs:[…], appropriationsummary:[…]}`) that `getamcoslitecosts` returns. (This also repairs the Project Report data path, which uses the same helper.) Fixed `Lite.cs` `@CareerProgramNumber` param type (Integer→Text). Fixed three runtime bugs in `007`'s `getamcoslitecosts`: inflation-year `text≥smallint` cast, a `row_data` OUT-param/column ambiguity (`#variable_conflict use_column`), and the missing `analysis.getpayplans` helper (ported to `006b`). Verified: `getamcoslitecosts` executes cleanly for 8 pay plans (GS/AE/AO/NE/NO/RE/GG/SES) against a freshly-migrated+seeded DB.
  - *Presentation* — `Pages/App/Lite/Index.cshtml` now renders ALL result grids (not just the first), adds a **C3.js cost-by-grade chart** (CDN d3+c3; hidden for CCE / non-Default summary like the legacy), **appropriation color-coding** using the legacy palette (`AMCOS.Logic` GetAppropriationColor hex values), **weapon-system** (orange) and **CCE over-salary-limit** (yellow) highlighting, and a color legend. Page loads (200) with all elements.
  - *Caveat:* visual fidelity (actual bars / grid contents) can't be confirmed until the ETL loads `crunch.*` cost data — the path executes and returns the correct structure against empty tables.
- **DONE (2026-06-25, Project Report):** Fixed a broken `ReportSelections` query (quoted PascalCase `webuser."PMReport"`/`"CategoryId"` → lowercase unquoted, which is what the migrated tables actually are). Added a formatted cost-report partial (`Pages/Shared/_CostReportTable.cshtml`): per-appropriation **color-coding** (legacy palette), **(sub)total-row shading**, **CCE over-salary-limit** highlighting (threshold from `SingleValue.Get("CCE","MaxPayFootnote")`), plus discounted-column tagging with a **Show/Hide discounted** toggle and a legend. The Report **data** path was already repaired via the shared `ExecuteStoredProcDataSet` fix. (Visual fidelity needs ETL cost data; build + page load verified.)
- **DONE (2026-06-25, RSS news viewer):** Ported `note.aspx` to `Pages/Note.cshtml` — reads `wwwroot/Public/rss.xml`, supports `?noteId=` (matched against `<guid>`) or lists all items, renders title/description/category/content/pubDate, and degrades gracefully when the feed file is absent. Added a **News** nav item and the RSS `<link rel="alternate">` in the layout head. Verified: `/Note` and `/Note?noteId=5` return 200.

**P1 status: COMPLETE.** All identified feature regressions (navigation, admin user-delete, user-list filters, AMCOS Lite, Project Report formatting, RSS news viewer) are restored. Items needing real ETL cost data for final visual validation: AMCOS Lite grids/chart and the Project Report cost grid.

**P2 — cleanup:** RSS note viewer (confirm still needed), `dist/` asset packaging, rewrite `MIGRATION_NOTES.md`.

**Verification approach:** these need a seeded Postgres DB to exercise end-to-end. Recommend standing up the DB (`AMCOS.PostgreSQL` + seed) and smoke-testing each module, since many failures only surface at query time.
