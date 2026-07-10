# AMCOS — Web Behavioral Parity Audit (New ASP.NET Core vs Legacy WebForms/MVC)

_Date: 2026-07-09. Method: seven parallel feature-area comparisons reading both the new
`AMCOS.Web.Core` and the legacy `AMCOS.Web` implementations. Every divergence is classified
**REMOVED** (in legacy, missing in new) / **ADDED** (in new, not in legacy) / **CHANGED**
(behaves differently), and **GENUINE** (a real functional/behavioral difference a user or admin
would notice) vs **MOD** (intentional transport-level modernization: AJAX-vs-postback, JSON grid
vs GridView, Foundation→Bootstrap, EAMS→Keycloak, popup removal — kept by design)._

> **Important nuance for "make it exactly the same."** Several new-app changes are legitimate
> **bug fixes** over the legacy (e.g. corrected an arg-order bug, added auth to a page that lacked
> it, fixed an "N tools" typo). Reverting those to be literally identical would re-introduce
> legacy defects. The recommendation below is: **fix genuine regressions, keep legitimate fixes and
> the transport modernizations** — call out any you'd rather revert.

## Scope covered
AMCOS Lite · Project Manager (list + Details wizard) · Project Cost Report + Excel export ·
Civilian PCS · Admin (Users/Approvals/SponsorAction/Inventory/Log/Dashboards) ·
Data (Calculations/Skills/Visualization) + Xwalk · common (nav/home/resources/profile/auth/
session/error/footer/notes).

---

## TIER 1 — CRITICAL: functional bugs, security, or wrong numbers (fix first)

**Status legend:** ✅ FIXED (behavioral-parity edit landed) · ➖ no change needed (already correct
in the migrated app) · ⬜ open.

**Tier 1 — COMPLETE.** Batch 1 (commit `00f309a`): **C1, C4, C9, C10, C11, C14**.
Batch 2: **C2** (workflow emails restored via `CoreEmailHelper`), **C5/C6/C7** (Add-Unit relocation
id, CCE-keyed overhead, SACS-extend gate), **C8** (main-category rename/delete guard), **C12** (APPN
colors), **C13** (CivPCS anti-forgery).
➖ **C3** — no change: the migrated `web.pmcostsbypayplancce` already caps CCE over-limit costs at
the DB layer (`v_maxpay*inventory`), so the on-screen values are already correct (and better than
legacy, which flat-capped the aggregate ignoring inventory). Re-capping in the C# builder would
re-introduce the legacy defect.
➖ **C15** — no change: `PMUserSummary`/`PMUserSummaryElement` do not exist in the PostgreSQL schema,
so the current cascade is already the complete correct set; adding those DELETEs would abort the
transaction. `pcsproject` is correctly present (CivPCS is ported). Delete-any-user is a deliberate
admin capability (kept).

| # | ✔ | Area | Divergence | Effect |
|---|---|---|---|---|
| C1 | ✅ | Admin · SponsorAction | Sponsor queue matches `sponsoruserid` against the **DoD-ID claim** (`NameIdentifier`) instead of `amcosuser.userid` (`SponsorAction.cshtml.cs:27-45`); the column references `amcosuser.userid`. | Sponsor approval queue **returns no rows** — the sponsor workflow is broken. |
| C2 | ✅ | Admin · Approvals/Sponsor | Approval / denial / sponsor-forward / rejection **emails are never sent in production** (only a dev-only preview string) (`Approvals.cshtml.cs:42-79`, `SponsorAction.cshtml.cs:70-109`). | Users & sponsors are never notified; the account-request workflow silently stalls. |
| C3 | ➖ | Report | On-screen: CCE rows over the salary limit are **highlighted but never capped/recomputed** (legacy overwrote Salary/Benefits/Overhead with capped values from `Tables(2)`) (`_CostReportTable.cshtml:57-82` vs `report.aspx.vb:417-452`). | **Wrong dollar values displayed** for capped CCE rows. |
| C4 | ✅ | Report | Report-selection query dropped the **owner `UserID` filter** — filters on `projectid` only (`Report.cshtml.cs:91-98` vs `report.aspx.vb:1031-1032`). | A project's report can be read without the owner check (**IDOR-class**). |
| C5 | ✅ | PM · Add Unit | **Unit relocation broken**: dropdown is populated from the unit's own personnel locations and sends the location **text** (or literal `"Change"`), not an installation **ID** from `/api/locations/installations` (`Details.cshtml:700-705,743-747` vs `amcos-common.js:1199-1215,935`). | "Change location" no longer relocates a unit. |
| C6 | ✅ | PM · Add Unit | **CCE overhead input keyed to MTOE**, not to CCE-in-pay-plans (`Details.cshtml:708-717` vs `project-manager.js:146-156`). | Wrong `contractorOverheadPercent` sent for TDA-with-CCE and MTOE-without-CCE units. |
| C7 | ✅ | PM · Add Unit | **SACS-extend (OTOE/Last-MTOE) choice inverted** — shown under Freeze, unreachable under Sync; `duration > unitYears` gate lost (`Details.cshtml:648-652` vs `project-manager.js:332-341`). | Sync projects that outrun SACS are silently forced to "Last MTOE". |
| C8 | ✅ | PM · Sub-projects | The **main/default category can now be renamed *and* deleted** (dropdowns source `PMGetCategoriesAll`; no main-category guard) (`Details.cshtml.cs:442-477` vs `details.aspx.vb:417-422`). | Renaming/deleting it desyncs `GetMainCategoryId` → **Add-Unit Replace / append-to-main break**. |
| C9 | ✅ | Common · News | RSS page reads `wwwroot/Public/rss.xml` (`Note.cshtml.cs:23`) but `/Public` is served from **legacy `AMCOS.Web/Public`** (`Program.cs:194-202`). `wwwroot/Public` doesn't exist. | News page always shows "No news feed available." |
| C10 | ✅ | Data · Visualization | Inventory dashboard config key renamed `InventoryDashboardId` → **`VisualizationDashboardId`** (`Visualization.cshtml.cs:21`, `appsettings.json:39`). | A straight config port silently breaks the Inventory dashboard. |
| C11 | ✅ | Common · Profile | **Company Name required-validation dropped** for CONTRACTOR accounts (`*` shown, no `required`, no server check) (`Profile/Index.cshtml:99-102`). | A CTR user can save a blank Company Name (legacy blocked it). |
| C12 | ✅ | Report | On-screen APPN cell **colors wrong and inconsistent with the export**; `Contractor`↔`CCE` key inverted (`_CostReportTable.cshtml:11-21` vs `report.aspx.vb:458-479`). | Mis-colored appropriations; grid disagrees with the exported workbook. |
| C13 | ✅ | Civilian PCS | **Anti-forgery removed** (`[IgnoreAntiforgeryToken]`, no token in JS) (`Index.cshtml.cs:14`). | CSRF protection on PCS save/delete/calc is gone. |
| C14 | ✅ | Common · Footer | **Incorrect AMCOS acronym** — "Army Civilian and Military Operational Support" vs the correct "Army Military-Civilian Cost System" (`_Layout.cshtml:136`). | Wrong product name shown site-wide. |
| C15 | ➖ | Admin · Users | The hidden self-only "Delete Me for Testing" hook is promoted to a production **"delete any user + cascade"**, with a **different cascade set** (adds `pcsproject`, **omits `PMUserSummary`/`PMUserSummaryElement`**) (`Users.cshtml.cs:356-413` vs `UpdateMyProfile.aspx.vb:97-110`). | New destructive admin capability + orphaned summary rows. |

---

## TIER 2 — GENUINE behavior/capability regressions (user-visible, not bugs)

### AMCOS Lite (output/presentation was thinned)
_Batch 3a status (on-screen output): ✅ currency+right-align, hidden internal columns, ShowOrder
sort, single-grid render, WSM/Federal-OM subtotals + grand Total, weapon zero-row suppression, CCE
column-highlight on the sentinel. ➖ grade-header relabeling — already done at the DB layer
(grades arrive as E1…E9 / MIN·AVG·MAX / GS1…GS15). ⏸ Appropriation-Group summary grid — DEFERRED:
the migrated `getcosts.appngroup` is a functional grouping (Military Pay/Benefits/Training), not the
legacy ARMY/DoD/FEDERAL/PA/OM appropriation-type key `GetAppropriationGroupColor`/`GetAppropriationGroupTable`
require, so it cannot be rebuilt faithfully without a data/proc decision on that classification.
✅ inflation-rate header table (3b) — endpoint `OnGetInflationHeader` + client render, family column
set chosen from hardcoded pay-plan arrays (the migrated payplantags lacks the fine-grained tags).
✅ required-filter validation + ButtonClick per-refresh logging (3d). ➖ pay-plan optgroups
(cosmetic: 3 groups vs legacy 6 — functional dropdown unchanged) and "plans-with-costs" filter
(investigator could not substantiate a legacy filter beyond `DisplayTitle != ""`, which the new app
already applies) left as-is. ✅ Excel export (3c) — `LiteExportHelper` (Aspose.Cells) + `OnGetExport`
handler + Download-Excel button: classification banner, AMCOS Lite title, inflation-rate header, filter
selections, and the shaped cost detail grid. **AMCOS Lite Tier 2 area COMPLETE** apart from the two
documented exceptions above (appropriation-group grid; cosmetic optgroups)._
- REMOVED: **Appropriation-Group summary grid** (replaced by generic per-APPN total rows, different grouping key). — `appendAppnTotals` vs `GetAppropriationGroupTable`.
- REMOVED: **Inflation-rate header table** (percent, column count varies by family) — absent entirely.
- REMOVED: **Excel/Download export** (formatted xlsx: filter block, summary, inflation table, CCE notes, classification banner) — no export button/endpoint.
- REMOVED: **Required-filter validation** — new only checks pay-plan≠-1; other filters can be left blank.
- REMOVED: **ButtonClick (per-refresh) audit logging** — only filter-change logging remains.
- REMOVED: **Currency formatting + right-align** of cost cells — raw values printed.
- REMOVED: **Grade-header relabeling** (E/O/W prefixes, SES→MIN/AVG/MAX, CCE→"Level N").
- REMOVED: **Weapon-System zero-row suppression**; **WSM/Federal-OM subtotal rows**.
- REMOVED: **Hidden internal columns leak** — `ShowOrder`/`appnGroup`/`Description` now displayed.
- CHANGED (GENUINE): CCE highlight trigger `= sentinel` → `> limit`; pay-plan optgroups collapse to
  "Military"/"Other"; pay-plan list no longer filtered to plans-with-costs; WSM warning text is a
  different message; row sort by `ShowOrder` dropped; renders **all** result sets (incl. intermediates).

### Project Manager (Add-Unit regressions are in Tier 1; remaining)
_Status: ✅ restored Duration + Create Date list columns; ✅ insert-inventory default 1 (was 0).
⬜ project-list sorting (medium; deferred). ➖ "Report" list action kept (harmless addition).
⬜ Update-also-deletes-checked-rows and insert re-validation deferred (need a separate Delete control /
server-side "All group/location" guards)._
- REMOVED: project-list **sorting**; **Duration** + **Create Date** columns.
- ADDED: "Report" action on the list + a "View Report" button that can show a stale/empty report
  without running Build Report.
- CHANGED: Insert client-validation weakened (allows "All group/All location" rows legacy blocked;
  no server-side code re-validation); Update button now also **deletes checked rows** (legacy Update
  ignored delete checkboxes); insert-inventory default `1`→`0`.

### Project Cost Report (on-screen + Excel)
_Batch 4 status — **DONE**: ✅ "BEGINNING OF SUB-PROJECT" divider banners (on-screen + export;
trailing banner dropped like legacy), ✅ gray "Total of All APPNs" combined row, ✅ regulatory notes
(JIC/14-factor, inflation example, OMB/DoDI on page; +OCONUS-groceries in export), ✅ total-row
coloring now blanks the columns left of Cost Element, ✅ CCE_ prefix strip 4→5, ✅ salary-limit
footnote second sentence restored, ✅ collapsible discounted view, ✅ Excel export borders + black
cost-header + bottom plain "UNCLASSIFIED//FOR OFFICIAL USE ONLY" banner. ➖ REMOVED the ADDED items to
match legacy: single-category grand-total row now gated to multi-category, in-grid "OMB Discount Rate"
row lifted to a heading, on-screen color legend removed. ➖ Special-pay note trigger kept data-driven
(more correct than the legacy `IndexOf>0` session check; not a regression to re-introduce)._
- REMOVED: **"BEGINNING OF SUB-PROJECT" divider banners**; the gray **"Total of All APPNs"** combined
  row; **expandable/collapsible** discounted view; **all regulatory explanatory notes** (JIC/14-factor,
  inflation-calc example, OMB/DoDI discounting, OCONUS-groceries) on page *and* in the export.
- ADDED: an **always-on grand-total** row for single-category projects (legacy didn't); an in-table
  **OMB Discount Rate** row; on-screen color legend.
- CHANGED: total/subtotal rows **color the entire row** (legacy blanked columns left of Cost Element);
  **inventory grid** loses header/row relabels + sort; `CCE_` prefix strip length 5→4; special-pay
  note trigger source (session→data rows); **Excel export** lost cell borders, black cost-header,
  non-cost number formats, and moved the **classification banner** to top and changed it
  "UNCLASSIFIED//FOUO" (bottom, no fill) → "UNCLASSIFIED" (top, green fill); salary-limit footnote
  second sentence dropped.

### Admin
_Status: ✅ restored on-screen Company/Phone/Created/Updated columns; ✅ Approved/Denied count label
("Approved Count = N" / "Denied Count = N" / "N user records found"); ✅ "N accounts pending" admin
banner (shown site-wide to admins). ⬜ column sorting, Last-Updated + Login-History date filters,
phone formatting, HelpSpot downloads deferred (medium effort). ➖ prefix→substring search KEPT
(UX improvement); delete-any-user + Inventory auth KEPT (legitimate)._
- REMOVED: user-list **"Last Updated"** + **"Login History"** date-range filters; **column sorting**;
  the **Approved/Denied count** reporting; on-screen columns Company/Phone/Created/Updated; phone
  formatting; the admin **"N accounts pending" blinking banner**; **HelpSpot file/detail downloads**;
  the **My-Profile self-service** page under Admin (re-homed to `/App/Profile`); sponsor columns +
  UserStatus on the approval screen; **Excel classification banner** on the user-list export.
- CHANGED: search **prefix-match → substring-match**; error Log source `aspnet_WebEvent_Events` →
  `web.applicationerrorlog` with far fewer fields, **no paging/sort**; QuickSight **JS-SDK → iframe**;
  dashboard **feature-flag gating removed**.
- ADDED: **delete-any-user** (Tier 1 C15); admin **auth** added to Inventory (closed a legacy gap);
  Dashboards landing page + Sponsor/Inventory nav items.

### Data / Xwalk / Visualization
_Status: ✅ QuickSight "Error"-sentinel guard (Visualization + admin Dashboard show an alert instead
of a broken iframe). ✅ Skills pay-plan label reverted to description-only. ⬜ default-record-on-load
(borderline; lazy cascade arguably better UX — deferred). ➖ JS-SDK→iframe transport kept (modernization)._
- CHANGED (GENUINE): QuickSight **JS-SDK → bare iframe** (loses SDK event hooks); swallowed exception
  → **broken `<iframe src="Error">`** on AWS failure; **no default record on page load** (legacy
  auto-selected the first cascade option); Skills pay-plan label now `code — desc`.
- ADDED (GENUINE): **Xwalk went from an "Under Construction" stub to a live embed** (legacy shipped it
  disabled).

### Common / session
_Status: ✅ session-warning modal "Stay Logged In" / "Log Out" buttons restored; ✅ footer CUI
accreditation statement + AESMP contact/primer links restored. ➖ session length KEPT at 15 min
(deliberate, self-coherent modernization — cookie + keepalive + JS agree; within DoD norms).
⬜ configurable global banner (lower urgency; needs config + layout injection) deferred._
- CHANGED: **session length 10→15 min**; the **session-warning modal lost its "Stay Logged In" /
  "Log Out" buttons** (activity-only extend); **KeepAlive no longer refreshes the anti-forgery token**.
- REMOVED: configurable **global banner notification**; the footer **CUI accreditation statement** +
  AESMP contact/primer links.
- CHANGED (GENUINE, minor): Profile email strict-regex → browser `type=email`; inflation
  conversion-type option order; label wording.

### Civilian PCS
_Status: ✅ House-Hunting "Spouse per diem is X%" 0% label bug fixed (#SpousePerDiemRate now updated
from the response). ➖ distance-via-PostGIS kept (intentional, per [[civpcs-migration-state]]).
⬜ auto-save-on-tab / arrow-key nav / persistent sidebar deferred (borderline; summary preserved on
its own tab)._
- CHANGED (GENUINE): **distance** now from PostGIS `warehouse.location.coordinates` (`ST_Distance`)
  instead of `CivLocationPerDiem` geography — the one number that can silently change.
- REMOVED: **auto-save on tab switch**; **keyboard navigation** (arrow keys); persistent summary sidebar.
- BUG (cosmetic): House-Hunting **"Spouse per diem is X%"** label stuck at **0%** (`#SpousePerDiemRate`
  never updated) — dollar totals are correct.
- ADDED: delete-confirm; "New Calculation"; double-click-to-open; a working "Set Default" tax button
  (was commented-out in legacy); on-open panel visibility sync (a fix).

---

## TIER 3 — Intentional modernizations (KEEP unless you want a literal revert)
AJAX/JSON handlers vs WebForms postbacks & `.asmx`; Foundation→Bootstrap nav + off-canvas→dropdown;
EAMS/ADFS federation → Keycloak OIDC (login/logout/role claim); `waitreport.aspx`/loading-popup
removal → direct navigation; selectize → native selects; server-side random home background; central
`/Error` page; About "three→four tools" text fix; PM Properties arg-order fix (C7 in the PM report);
CivPCS export MIME + sheet-name sanitization; QuickSight configurable region.

---

## Reconciliation plan (Phase 2)
1. **Tier 1 first** (C1–C15) — these are defects/security/wrong-number issues worth fixing regardless
   of parity philosophy. Several are one-line fixes (C1 sponsor key, C4 owner filter, C9 feed path,
   C10 config key, C11 Company-Name required, C14 acronym).
2. **Tier 2 by area**, heaviest first: **AMCOS Lite output** (appropriation-group grid, inflation
   table, Excel export, currency/grade formatting, WSM subtotals) and the **Report** (subtotal rows,
   export formatting, explanatory notes) are the largest — they require re-implementing legacy
   presentation logic (`default.aspx.vb` / `report.aspx.vb` / `GetCostTableWithOrder`).
3. **Confirm Tier 3** should stay modernized (recommended) — flag any you want literally reverted.

Each item above cites new + legacy `file:line`; reconciliation edits should update this doc's status.
