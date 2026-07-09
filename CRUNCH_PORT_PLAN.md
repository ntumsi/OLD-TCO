# Cost-Crunch Engine → PostgreSQL Porting Plan

_Status: **STRUCTURAL PORT COMPLETE (2026-07-09)** — all 4 phases ported. 44 crunch procedures + 15 functions + 5 warehouse populate procs + the CrunchAll orchestrator, all compiling, with the full `000→008` migration sequence applying from scratch. What remains is the DATA layer: run the Python ETL to load the input tables, resolve the gradelevel type coupling (below), then a numeric-validation pass against the legacy engine. Strategy: native PostgreSQL plpgsql, fully retiring SQL Server._

## Background

The web app's cost functions (`web.getcosts`, `web.costscce`, `web.pmcostsbypayplan*`, already ported in `006b`) READ from `crunch.Costs_*` tables. Nothing currently COMPUTES those tables in the Postgres stack:

- The Python ETL (`etl/`) builds staging inputs and only **shuttles pre-computed** cost CSVs between environments (`etl/datasync/import_costs.py`) — it has no cost-computation stage.
- The computation lives as **44 SQL Server stored procedures** + **15 scalar/table functions** in `AMCOS.AMCOS2020_MAR/crunch/` (~46,000 lines of T-SQL), orchestrated by `crunch/Stored Procedures/CrunchAll.sql`.

This plan ports that engine to PostgreSQL plpgsql. Until it lands, `crunch.Costs_*` is empty in production and cost math is exercised only by the demo seed (`seed/006_costfact_grades.sql`).

## Execution DAG (from CrunchAll.sql)

```
ValidateAmcosVersion (guard)
 └─ JointInflationCalculator → LoadGSAPerDiem → ArmyBudget
     └─ CrunchInventoryWASS, CrunchInventoryDMDC          (inventory)
         ├─ [OPM_G]  CrunchPayScheduleGSeries → CrunchGSeries
         │           CrunchPayScheduleCY → CrunchCY
         │           CrunchPayScheduleNF → CrunchNF
         ├─ [SES]    CrunchSES; CrunchPayScheduleCA/EX/IG
         ├─ [Wage]   CrunchPayScheduleWage → CrunchWage
         ├─ [GFEBS]  CrunchGFEBS; CrunchPayScheduleGP
         └─ [Mil]    DMDCPay → CostOfBasePay
                      → CostOfSimpleCEs, CostOfFICAandRetiredPay, CostOfClothing,
                        CostOfPCS, CostOfFamilySeparation, CostOfSeparationPay,
                        CostOfSpecialPays, CostOfBAS, CostOfBAHandCOLA, CostOfOverseas,
                        CostOfSelectiveRetentionBonus, CostOfRecruiting,
                        CostOfOfficerAcquisition, CostOfTraining        (recursive)
                      → CostOfMisc (after benefit/misc), CostOfMilAverages,
                        Crunch1ActiveDay
     └─ CrunchPayScheduleDSeriesNSeries
     └─ warehouse.PopulateCategory / PopulateLocationByCategory /
        PopulateUnitPersonnel / PopulatePPXwalk
     └─ CalculatePayPlanMinMax
```

## What already exists on the PG side (prior work)

| Layer | Status |
|---|---|
| Final `crunch.Costs_*` output tables (AE/AO/AWO/CY/G/GFEBS/NE/NF/NO/NWO/RE/RO/RWO/SES/Wage/1ActiveDay) + inventoryprocessed/inventory_gfebs/wass_processed/gsaperdiem/payscheduleminmax | ✅ `005b` |
| Read-side web functions (`web.getcosts`, `web.costscce`, `web.pmcostsbypayplan*`, …) + `crunch.getsinglevalue` | ✅ `006b` |

## Phase 0 — Foundation (IN PROGRESS)

**Goal:** the tables and helper functions every crunch proc depends on.

| Item | File | Status |
|---|---|---|
| 11 intermediate/staging tables (costs_crunchtemp[_1ad], payprocessed, nfpayprocessed, opm{ca,ex,ig}processed, inventorydmdc, inventorywass, timeingrade, armybudgetsinglevalues) | `migrations/005c_crunch_intermediate_tables.sql` | ✅ applied + verified |
| 10 scalar helper functions (validateamcosversion, getlatestamcosversionid, getarmybudgetsinglevalue, getmaximumgspaylimit, getreservecomponentbah, getparentmos, getinventorybycategorysubgroup, gettotalsiblinginventory, getchildinventorypercentage, getparentinventory) | `migrations/006c_crunch_helper_functions.sql` | ✅ applied + smoke-tested |
| `init.sh` wired to run 005c/006c in order; full 000→008 sequence re-verified from scratch | `init.sh` | ✅ |
| **Deferred:** `crunch.get1daycosts` (TVF) | — | ⏳ needs `costs_1activeday.categorygroupcode` reconciliation (see Open Questions) |
| **Deferred:** 3 `getchild*recursive` functions | — | ⏳ read Tier-3 `crunch_temp.*` schema; port with the training/bonus procs |

## Phase 1 — Simple military cost procs (COMPLETE, 2026-07-09)

All 10 ported to `migrations/006d_crunch_cost_procs_phase1.sql` as `LANGUAGE plpgsql`
procedures (invoked via `CALL`; `p_debug = true` is a dry run): `costofbasepay`,
`costofsimpleces`, `costofficaandretiredpay`, `costofclothing`, `costofmisc`,
`costofpcs`, `costoffamilyseparation`, `costofseparationpay`,
`costofbasicallowanceforsubsistence`, `crunch1activeday`. Wired into `init.sh`.

**Verified:** all 10 compile; a stub-and-rollback smoke test (empty ETL-input
tables created in a transaction, every proc `CALL`ed for real with `p_debug=false`,
then `ROLLBACK`) passes with no column/relation errors — so every `INSERT` column
list resolves against the real `crunch.Costs_*` tables. Full `000→008` sequence
still applies from scratch. Numeric validation is deferred until the ETL loads the
input tables (below).

**Resolved open issue #2:** `crunch.costs_1activeday` was missing `categorygroupcode`
+ `crunchtime` (present in the legacy schema + PK); added to `005b` so
`crunch1activeday`'s two rollup tiers (group-avg vs pay-plan-avg) are faithful.

**Intentional deviations (documented in the file):** NULLIF(denominator,0) on
budget/inventory spreads; `crunch1activeday` adds an `amcosversionid` predicate to
the pay-schedule joins the source omits; `costofsimpleces` preserves a source bug
(RE SLRP divides the *NE* loan-repayment budget) verbatim.

**Phase-1 ETL input tables the procs read** (must exist with these schema-qualified
names before a real crunch run — case matters, see open issue #4): `data.knowninventory`,
`"PaySchedule".payschedule_military`, `"DMDC".pay`, `dataload.armybudgetmanualvalues`,
`crunch.payprocessed` (defined empty in 005c, populated by Phase-2 DMDCPay), `data.costs`
(view, exists).

## Remaining phases

| Phase | Scope | Procs | ~Lines |
|---|---|---|---|
| **2 — Pay-schedule / civilian / inventory** ✅ COMPLETE (25/25) | see Phase-2 status below | 25 | ~16,800 |
| **3 — Complex military cost procs** ✅ COMPLETE (8/8) | see Phase-3 status below | 8 | ~22,900 |
| **4 — Orchestrator + warehouse populate** ✅ COMPLETE (6/6) | see Phase-4 status below | 6 | ~3,800 |

### Phase 2 status (in progress) — `migrations/006e_crunch_procs_phase2.sql`

**Done (15/25):**
- *Wave 1 (foundational):* `armybudget`, `dmdcpay`, `jointinflationcalculator`, `loadgsaperdiem`, `calculatepayplanminmax`, `createtimeingradetable`.
- *Wave 2 (inventory):* `crunchinventorywass`, `crunchinventorydmdc`, `crunchdmdcvantageinventory`.
- *Wave 3 (civilian cost):* `crunchcy`, `crunchnf`, `crunchses`, `crunchgseries`, `crunchwage`, `crunchgfebs` (the last also writes `crunch.inventory_gfebs`; two PIVOTs → FILTER, a PERCENTILE_CONT window → ordered-set aggregate).
- *Wave 4 (pay-schedule processing + utility, in `006f`):* `crunchpayschedulegseries/cy/nf/ca/ex/ig/wage/gp/dseriesnseries` (9) + `copyvalues` (cursor→FOR loop, inner cursor→`string_agg`, dynamic `EXEC`→`EXECUTE format()` with `%I` for case-safe identifiers). Needed new schema: `005d` creates the 4 processed `"PaySchedule".*` tables + 4 raw input tables, and `008b` creates the `data.payschedules` union view (the civilian crunches read it; a view resolves relations at CREATE time, so those tables had to exist first). `CrunchPayScheduleWage` UNPIVOT → LATERAL VALUES.

Wired into `init.sh`; all 15 compile; full `000→008` applies from scratch (25 crunch procedures total with Phase 1). Execution-tested (stub-and-rollback) the 4 procs whose inputs exist — `dmdcpay`, `jointinflationcalculator`, `createtimeingradetable`, `crunchnf` — which **caught + fixed 3 real varchar/smallint bugs**: JIC FY→`lookup.jicinflationrates.year` (`::smallint`), `createtimeingradetable` `data.inventory.gradelevel`→int temp (`::integer`), and `crunchnf` `data.inventory.gradelevel = payband` (`::smallint`). The rest depend on ETL inputs (`dataload.*`, `"PaySchedule".*`, `load_inventory.*`, `"load_GFEBS".*`, `xwalk.*`, `data.payschedules`) — execution/numeric validation deferred to real data. **Watch:** the same `data.inventory.gradelevel` is varchar (view unions a text GFEBS branch); any join to a smallint grade in CY/SES/GSeries/Wage/GFEBS likely needs the same `::smallint` cast at real-data time.

**Runtime risks flagged by the ports (verify against real ETL inputs):** many procs join a
varchar `gradelevel`/`step` against possibly-integer lookup columns (may need casts);
`crunchdmdcvantageinventory` assumes `xwalk.fips_wagearea` has `amcosversionidstart/end` (checked-in
DDL shows a single `amcosversionid`) and references an unconfirmed `"POS"."711"` table;
`crunchinventorydmdc` leaves `crunch.inventorydmdc.zip`/`dutystationzip` unpopulated;
`calculatepayplanminmax` dropped a `careerprogramnumber` column the dest table lacks and
preserved two source bugs (an always-false CIV-ALL predicate; a scalar SES subquery that errors
if >1 Annual row per payplan).

**Phase 2 COMPLETE (25/25).** All compile; `data.payschedules` view creates; full `000→008`
applies from scratch (35 crunch procedures total). Execution-tested one representative
pay-schedule proc (`crunchpayscheduleex`) via stub-and-rollback. Remaining runtime risks are
the ETL-input coupling already documented (varchar `gradelevel`/`step` casts; the many
`"PaySchedule".*_raw` / `dataload.*` / `load_inventory.*` inputs the ETL must load).

### Phase 3 status — `migrations/006h_crunch_cost_procs_phase3.sql` (7/8 done)

**Foundation added:** the `crunch_temp` schema + its 25 staging tables (`005e`); the 3 recursive
MOS-tree helpers + `get1daycosts` (`006g`, resolving the last two Phase-0 deferrals); and the
`data.knowninventory` view (`008c`) that both Phase-1 and Phase-3 military procs read.

**Ported (7/8):** `costofselectiveretentionbonus`, `costofrecruiting`, `costofofficeracquisition`,
`costofbasicallowanceforhousingandcola` (2 PIVOTs → FILTER), `costofspecialpays`, `costofoverseas`
(ROUND integer-division preserved), `costofmilaverages`. Each also writes its `crunch_temp.*`
staging tables where the source does. All compile; full `000→008` applies from scratch
(**42 crunch procedures + 15 functions**). Many self-join / LEFT-JOIN→correlated-subquery rewrites
and several preserved source bugs are documented inline.

**`CostOfTraining` DONE** (`006i_crunch_costoftraining.sql`, 13,151 lines) — the single largest
object in the port. Compiles under `check_function_bodies=on`; statement counts match the source
(420 INSERTs / 86 UPDATEs / 11 TRUNCATEs / 19 DELETEs); stages into 11 `crunch_temp.*` tables and
writes all nine `crunch.Costs_*`. 13 self-join rewrites; two window-function CTE UPDATEs done via
`ctid` join; the recursive training helpers called as ported. **Caveat:** a proc this size cannot be
hand-reviewed line-by-line and cannot be execution-tested without the full `load_training.*` ETL
pipeline — it needs real-data validation more than any other proc (a documented follow-up, not a
claim of verified numeric faithfulness).

### Phase 4 status — COMPLETE (6/6)

- **`006j_warehouse_populate_procs.sql`:** the 5 `warehouse.*` post-crunch populate procs
  (`updatelocationid` [PostGIS `ST_SetSRID(ST_MakePoint(lon,lat),4326)::geography`],
  `populatecategory`, `populatelocationbycategory`, `populateunitpersonnel`, `populateppxwalk`)
  that rebuild the category/location/unit-personnel/pay-plan-crosswalk tables driving the app's
  dropdowns and Project Manager.
- **`006k_crunchall.sql`:** the `crunch.crunchall` orchestrator — 45 `CALL`s in dependency order,
  each timed into `analysis.crunchtime` (`005f`), with the `p_whichtorun` family selector preserved.
  Compiling it validated **all 45 CALL targets + named arguments** against the real signatures
  (including the two renamed inventory procs `CrunchWASSInventory`→`crunchinventorywass`,
  `CrunchDMDCInventory`→`crunchinventorydmdc`). Verified it executes (early-returns on an invalid
  version via the validate guard).

**Whole engine now ports and applies cleanly from scratch (26 migrations).** The only remaining
work is the data layer — the two items below.

### ⚠ #1 runtime blocker before any real crunch run: gradelevel type

`data.inventory.gradelevel` (and therefore `data.knowninventory.gradelevel`) is **varchar** — the
008 view unions a text GFEBS branch. The military cost procs read it into smallint/integer grade
columns, so at real-data time they need `::smallint` casts (found+fixed 3 such spots by execution
testing: jic, createtimeingradetable, crunchnf). This is systemic across the Phase-1/3 military
procs and must be resolved (per-proc casts, or a typed `data.knowninventory` that casts grade for
the numeric-grade pay-plan families) alongside loading the ETL inputs, before the engine produces
real numbers. Structural port + schema are complete and apply cleanly; this is the data-layer
reconciliation step.

Each phase: port DDL/procs → apply to a throwaway DB → validate outputs against the legacy engine's numbers for a known `AmcosVersionId` (requires the Python ETL to have loaded the input schemas below).

## T-SQL portability hazards (counts across all procs)

Mechanical, high-volume: `ISNULL`→`COALESCE` (189), `GETDATE`→`now()` (145), `CONVERT`→`CAST`/`to_char` (82), `SELECT INTO #tmp`→`CREATE TEMP TABLE AS` (204), `CREATE TABLE #`→`CREATE TEMP TABLE` (70), `TOP n`→`LIMIT` (14), `RAISERROR`→`RAISE NOTICE`/`EXCEPTION` (94), `PIVOT`→`CASE`/`FILTER`/`crosstab` (7).
Case-by-case: recursion (3 `GetChild*Recursive` self-calls), 1 table-valued fn (`Get1DayCosts`), cursors (3, in 2 non-orchestrated utilities), dynamic SQL (2, in `CopyValues` only).
Wins: **0** `CROSS/OUTER APPLY`, **0** `MERGE`.
Gotchas (per project memory): `ROUND(double, int)` — cast `::numeric` first; BOOLEAN params must be real bools, not int 0/1.

## Input schemas the Python ETL must populate before a crunch run

`payschedule.*` (military/GS/CY/NF/Wage/SES/OPM raw + processed), `dataload.*` (ArmyBudget, BAH/COLA, inflation, spendable income, bonus caps, per-diem), `DMDC.*` (Pay, MembersAndDependents), `data.*` (KnownInventory, Inventory, Costs, AsafmcJointInflationRates), `load_inventory.*`, `load_training.*`, `load_GFEBS.Cleaned`, plus ~25 `lookup.*` and ~15 `xwalk.*` tables. (Detailed list in the migration inventory notes.)

## Open questions to resolve

1. **Proc-name mismatch:** `CrunchAll` EXECs `crunch.CrunchWASSInventory` / `crunch.CrunchDMDCInventory`, but the files are named `CrunchInventoryWASS` / `CrunchInventoryDMDC`, and `CrunchDMDCVantageInventory` (writes `InventoryProcessed`) is newer and NOT called by CrunchAll. Determine which inventory crunch is authoritative before porting Phase 2.
2. **`costs_1activeday` schema:** ✅ RESOLVED (2026-07-09) — added `categorygroupcode char(2)` + `crunchtime timestamp` (and the legacy PK) to `005b`, matching the legacy table. `crunch1activeday` now writes them and its rollup tiers are faithful. `Get1DayCosts` (still deferred) can now join on `categorygroupcode`.
3. **Dead tables:** `crunch.CGLA`, `crunch.CGLATEMP`, `crunch.Costs_G_Overseas` have no writer among the 44 procs (the `CGLA…` strings in CostOf* procs are computed `#temp` column names). Confirm dead and skip.
4. **`crunch_temp` schema:** `CostOfTraining` and the recursive helpers stage into ~11 `crunch_temp.*` tables (not in `crunch/Tables`). This schema must be reverse-engineered from CostOfTraining and ported alongside Phase 3.
