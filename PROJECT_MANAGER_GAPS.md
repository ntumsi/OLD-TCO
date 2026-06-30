# Project Manager — Migration Gap Analysis

_Old (`AMCOS.Web` WebForms + `project-manager.js`) vs. new (`AMCOS.Web.Core` Razor Pages). Produced from a full old-vs-new feature inventory of both code bases._

> **STATUS: all gaps resolved (June 2026).** GAP 1 and GAP 2 fixed; minor validation items addressed/confirmed. Details inline below under each item.

## Verdict

The new Razor Pages Project Manager is **largely at parity** with the legacy four-step wizard. Confirmed present and working:

- **Index** — project list, **Create**, **Copy** (`Project.Copy`), **Delete** (cascade).
- **Details / Properties** — name, description, start year, duration; save.
- **Details / Add Unit** — UIC lookup, pay-plan exclusion checkboxes, **Replace / Append / Subproject**, unit location **Unchanged / National Average / Change**, MTOE **Sync / Freeze** + SACS-extend (**Last MTOE / OTOE**), CCE contractor-overhead % — full parity with the legacy Step 1.
- **Details / Faces & Spaces** — category tabs, inventory grid with per-year editing, **bulk update**, delete checkboxes; subproject **create / rename / delete**; **copy between sub-projects** (with the legacy duplicate guard).
- **Details / Output** — pay-plan × sub-project selection, check/uncheck all, **Build Report**.
- **Report** — properties, selection, inflation factors, discount/PVF, inventory, **undiscounted + discounted** cost summaries with APPN sub-totals + appropriation colour-coding, and **Aspose Excel export**.
- **Duplicate-position prevention** is ported (`Details.cshtml.cs:341`).
- Supporting REST endpoints (`LookupApiController`: `/api/categories`, `/api/locations`, `/api/strls`, `/api/grades`, `/api/units/...`) all exist.

Two gaps were found — one significant, one cleanup.

---

## GAP 1 — "Add Position" uses free-text code inputs instead of cascading dropdowns  **(MAJOR) — ✅ FIXED**

**Resolution:** The Add Position form ([Details.cshtml](AMCOS.Web.Core/Pages/App/Project/Details.cshtml)) was rebuilt as a native, pay-plan-driven **cascade** mirroring the AMCOS Lite fix: Pay Plan → Category (`/api/categories`, decoded via `parseCategory`) → Location (`/api/locations`) → STRL (`/api/strls`, lab-demo) → Dependent Status / # Dependents (conditional) → **Grade Level** (`/api/grades`), with pay-plan-driven show/hide and Active-Duty-Days (NG/Reserve) and Overhead % (CCE) appearing only when relevant. The cascade engine lives in the repurposed [wwwroot/dist/js/project-manager.js](AMCOS.Web.Core/wwwroot/dist/js/project-manager.js) (see GAP 2); it exposes `window.pmRequirement`, which the page's Insert handler reads. Grade selection is now required when shown. Server endpoints were already present. Build green; JS syntax-checked.

_Original finding:_

**Where:** Details page, Faces & Spaces tab, "Add Position to Current Category" form — [Details.cshtml:336-383](AMCOS.Web.Core/Pages/App/Project/Details.cshtml#L336).

**Old behavior** (`AMCOS.Web/App/Project/details.aspx` Step 2 + `src/js/project-manager.js`): a pay-plan-driven **cascade**, identical in spirit to AMCOS Lite —
- **Pay Plan** dropdown → drives which filters are visible.
- **Category** dropdown (group / subgroup / career program) loaded from `/api/categories/{payplan}`, decoded via `parseCategory`.
- **Location** dropdown loaded from `/api/locations/...`.
- **STRL** dropdown from `/api/strls/...` (lab-demo pay plans only).
- **Dependent Status** / **# Dependents** shown conditionally (military CONUS / civilian overseas).
- **Active Duty Days** (default 15) for NG/Reserve; **Overhead %** for CCE.
- **Grade Level** dropdown populated from `/api/grades/...` based on all prior selections.
- Invalid combinations are impossible because every field is a constrained, server-populated list.

**New behavior:** every field is a plain `<input>` the user must hand-type —
`reqPayPlan` (text), `reqGroup`, `reqSubgroup`, `reqCareerProgram` (text, "-1 = All"), `reqLocationId` (number), `reqLocationText` (text), `reqSTRL` (text), `reqGradeLevel` (number 1–20), `reqDependentStatus` (text), `reqNumDependents`, `reqActiveDutyDays`, `reqOverheadPct`. The submit JS ([Details.cshtml:945-953](AMCOS.Web.Core/Pages/App/Project/Details.cshtml#L945)) reads these raw values. There is **no cascade, no conditional visibility, no grade population, and no validation against valid codes**.

**Impact:** High. Users cannot realistically know the internal group/subgroup/career/grade codes, so the form is unusable as a real personnel-entry tool. A wrong code is accepted and persists a position that simply costs **$0** in the report (no error). This is the **same regression class** we already fixed in AMCOS Lite.

**Fix (server side already done):** reuse the AMCOS Lite cascade pattern (`wwwroot/dist/js/amcos-lite.js` + `object-payplan.js`) against the **same** `LookupApiController` endpoints, wiring Pay Plan → Category → Location → STRL → Grade with the pay-plan-driven show/hide and `parseCategory` decoding into the Add Position form. The endpoints and option-list logic (`AMCOS.Logic.Lite.GetOptionList*`) already exist; this is front-end work plus reading the grade endpoint. Estimated effort: moderate (comparable to the Lite rebuild, smaller surface).

---

## GAP 5 — No way to open/edit a project from the listing  **(MAJOR) — ✅ FIXED**

**Symptom:** From the Project Manager listing you could only **Report** or **Delete** a project — there was no link into the editable **Details** page, so units/positions could never be added to an existing project.

**Root cause:** [Index.cshtml](AMCOS.Web.Core/Pages/App/Project/Index.cshtml) rendered each row with only Report + Delete actions; neither the name nor any button linked to `/App/Project/Details/{projectId}`. The legacy listing had a "Select" command that redirected to `details.aspx?ProjectId=…`.

**Resolution:** Made the project name a link to Details and added a primary **Open** action (Report demoted to secondary); also added a delete confirmation to match the legacy prompt. The Details route is `@page "{projectId:int}"`, linked via `asp-page="/App/Project/Details" asp-route-projectId`.

---

## GAP 4 — Add Unit was completely non-functional (four separate defects)  **(MAJOR) — ✅ FIXED**

**Symptom:** No way to add a unit at all — the UIC field couldn't discover units, Lookup crashed, and the final import failed.

Four independent bugs all blocked the Add Unit flow:

1. **No unit picker (frontend).** The legacy app had a searchable unit **dropdown** (`<select id="unitList">` populated from `/api/units`); the new app had a bare free-text UIC box (placeholder "WAAA01") with no way to discover valid UICs. **Fix:** added a `<datalist id="uicOptions">` populated from `/api/units` ([Details.cshtml](AMCOS.Web.Core/Pages/App/Project/Details.cshtml)), restoring type-ahead discovery.

2. **Lookup threw NullReferenceException (backend).** [`Project.IsTda`](AMCOS.Logic/Project.cs) did `unitType.Contains("TDA")` on `AuthorizationDocument`, which was **NULL** for the seeded unit (`.First()` returned null → NRE → `OnGetUnitPersonnel` 500 → "No personnel data found"). **Fix:** `FirstOrDefault()` + `!string.IsNullOrEmpty(unitType) && unitType.Contains("TDA")`. (`IsMtoe` uses `== "MTOE"`, which is null-safe.)

3. **Add Unit insert failed — boolean passed as integer (backend).** `Project.AddUnit` invoked `web.projectaddunit(...)` with the `p_debug` argument as `(object)0` — an integer against a `boolean` param. PostgreSQL has no implicit int→bool cast, so overload resolution failed: `function web.projectaddunit(integer, …, integer) does not exist`, on **every** call. **Fix:** pass real `false`. (Verified: int `0` → "function does not exist"; `false` → imports AE×2, AO×1. Also note `p_debug=true` is a dry run — `IF NOT p_debug` — so an int that mis-resolved looked like a no-op.) Scanned `AMCOS.Logic`; no other boolean-as-integer calls.

4. **Append had no target category (frontend).** Categories load lazily on the Faces & Spaces tab, so Append from a fresh Add Unit tab posted `categoryId = 0`. **Fix:** load categories on demand in the Append path, with a clear message if none exist.

**Data:** seed `003` now sets `unitpersonnel.authorizationdocument = 'MTOE'` (was unset → NULL), and existing live rows were repaired. Build green; full chain verified end-to-end (discover → Lookup returns AE/AO → import).

---

## GAP 3 — New projects had no default category, so positions couldn't be added  **(MAJOR) — ✅ FIXED**

**Symptom:** On a freshly-created project, Faces & Spaces showed "No categories found" and Add Position was permanently blocked ("Please select a category first"); Add Unit → Replace silently no-opped.

**Root cause:** The legacy app always carried a default "main" category named after the project — `Project.GetMainCategoryId` matches it by name and `web.PMGetCategories` treats it as the main bucket. The migrated [`AMCOS.Logic.Project.AddProject()`](AMCOS.Logic/Project.cs) inserted only the `PMProject` row and **never created that category**, so `web.PMGetCategoriesAll` returned an empty list → no category tab → `activeCategoryId` stayed null → inserts blocked. (`GetMainCategoryId` returning 0 also made Add-Unit "Replace" a no-op.)

**Resolution:** `AddProject()` now creates the default category named after the project. Existing app-created projects in any environment were repaired with an idempotent backfill (`INSERT … WHERE NOT EXISTS` a category named = project name), and seed `004` now creates the project-named main category alongside `Operators`/`Maintainers`. Build green; verified the three live projects now each carry their main category.

---

## GAP 2 — Orphaned `project-manager.js`  **(CLEANUP) — ✅ FIXED**

**Resolution:** The dead file was **rewritten** as the native cascade engine that powers the GAP 1 fix (no jQuery/selectize), and is now referenced from the Details page. Option (b) below — repurpose, not delete.

_Original finding:_

**Where:** [AMCOS.Web.Core/wwwroot/dist/js/project-manager.js](AMCOS.Web.Core/wwwroot/dist/js/project-manager.js) (was 481 lines of unused legacy port).

It is **not referenced by any page** (the Details page uses its own inline fetch-based JS). It is a partial port of the legacy `project-manager.js` and is dead code — the same situation as the orphaned `amcos-lite.js` before the Lite rebuild. Notably, it already contains a usable cascade skeleton (`changePayPlan`, `changeCategory`, `changeLocation`, `setVisibleElements`, the pay-plan family arrays).

**Fix options:** (a) delete it, or (b) **repurpose its cascade logic as the basis for GAP 1** and then wire it into the page. Option (b) kills two birds.

---

## Verified NON-gaps (do not "fix")

- **Cost-element output-field selection.** The legacy `cblSumOutputFields` checkbox list lived inside `<div style="display:none">` ([details.aspx:970](AMCOS.Web/App/Project/details.aspx#L970)) and `report.aspx.vb` never reads `CheckedFields` — it was hidden/non-functional in the old app. The new Report omitting it is correct.
- **`waitreport.aspx` loading popup.** Legacy used a popup → `waitreport.aspx` → `report.aspx` redirect; the new app navigates straight to the Report page. Modernization, not a gap.
- **Duplicate-position prevention** — present in the new app.

---

## Minor items — status

- **Properties validation parity:** ✅ already present — `EditYearStart` enforces `min=@Model.MinimumStartYear` / `max=@Model.MaximumStartYear` ([Details.cshtml:98-101](AMCOS.Web.Core/Pages/App/Project/Details.cshtml#L98)) and `EditYearDuration` enforces 1–30. No change needed.
- **Active-duty-days default:** ✅ the cascade shows the Active Duty Days field only for NG/Reserve pay plans and resets it to **15** on each pay-plan change.
- **Server-side code validation (defense in depth):** ⚠️ _still open (low priority)._ Inputs are now dropdowns sourced from the option lists, so bad codes are no longer reachable through the UI; `OnPostAddRequirement` still clamps grade/active-duty/overhead ranges ([Details.cshtml.cs:327-331](AMCOS.Web.Core/Pages/App/Project/Details.cshtml.cs#L327)) but does not re-validate the classification codes against the option lists. Optional hardening if non-UI callers are a concern.

---

## Resolution summary

1. **GAP 1 — FIXED.** Add Position rebuilt as the cascading, pay-plan-driven dropdown set against the existing `/api` endpoints (incl. grade-level loading the old app had).
2. **GAP 2 — FIXED.** Orphaned `project-manager.js` repurposed as the cascade engine and wired into the Details page.
3. **Minor items** — validation parity confirmed already present; active-duty-days default handled by the cascade; server-side code validation remains an optional low-priority hardening.
