# AMCOS seed data

A representative **development / demo** dataset for AMCOS. It populates the core
reference lookups, warehouse rollups, web configuration, and a small set of demo
users plus a worked Project Manager and Civilian PCS project — enough to exercise
the application end-to-end without a full production data load.

> These scripts are for **local / staging** use. The demo accounts
> (`admin.demo`, `analyst.demo`) and sample projects should be removed before a
> production deployment.

## Prerequisites

Run the schema and table migrations first (see `../migrations`), in order
`000` → `008`. The seed scripts assume those tables exist. Spatial
(`geometry` / `geography`) columns are left `NULL`, so PostGIS is **not** required
to load this seed.

## Load order

Run the seed scripts in numeric order — later files reference rows created by
earlier ones (e.g. projects reference users and warehouse locations):

```sql
\i seed/001_versions_and_lookups.sql
\i seed/002_cost_elements.sql
\i seed/003_warehouse_and_web.sql
\i seed/004_demo_users_and_project.sql
\i seed/005_amcos_lite_coverage.sql
\i seed/006_costfact_grades.sql
```

Or from a shell:

```bash
for f in seed/001_versions_and_lookups.sql \
         seed/002_cost_elements.sql \
         seed/003_warehouse_and_web.sql \
         seed/004_demo_users_and_project.sql \
         seed/005_amcos_lite_coverage.sql \
         seed/006_costfact_grades.sql; do
    psql "$AMCOS_DB_CONNECTION" -v ON_ERROR_STOP=1 -f "$f"
done
```

## What each file loads

| File | Contents |
|---|---|
| `001_versions_and_lookups.sql` | `lookup` schema: AMCOS versions, pay plans, grades, MACOMs, organizations, CMF/branch, MOS, AOC, career programs, component types, locality pay areas, GS occupational groups/series, JIC inflation rates |
| `002_cost_elements.sql` | `lookup.costelement`, `lookup.costsummary`, and `lookup.costsummaryelement` — composite Army cost elements per pay-plan family and their rollup membership |
| `003_warehouse_and_web.sql` | `warehouse` schema (locations, categories, location-by-category, joint inflation calculator, unit personnel) and `web` schema (`payplantag`, `qlikapplication`) |
| `004_demo_users_and_project.sql` | `webuser` schema: demo users + login history, a sample Project Manager project (categories → skills → inventory → report), and a sample Civilian PCS estimate |
| `005_amcos_lite_coverage.sql` | AMCOS Lite filter coverage: seeds `warehouse.category` + correctly-keyed `warehouse.locationbycategory` (incl. STRL) for the pay plans defined in `001`, so every filter cascade (Pay Plan → Category → Location → STRL / Dependent Status / Number of Dependents) populates. Filter coverage only — not the deep `web.getcosts` inputs |
| `006_costfact_grades.sql` | Grade-level coverage for the Lite + Project Manager cascades: generates `crunch.costs_*` rows (which the `data.costs` view exposes) keyed to the `005` categories/locations, so the **Grade** dropdown populates for AE/AO/AWO, GS/GG/GP, SES, WG/WL/WS, DB/NH, CY. Representative amounts only (not a full cost load); CCE is excluded (separate `data.costscce` path) |

## Conventions

- **Idempotent.** Every statement is guarded with `ON CONFLICT DO NOTHING` (on
  natural/primary keys) or `WHERE NOT EXISTS` (for identity-keyed tables), so the
  scripts can be re-run safely without creating duplicates.
- **Versioning.** Range-versioned reference rows use
  `amcosversionidstart = 1` / `amcosversionidend = 999999` to mean "currently
  effective". Single-version rows are stamped `amcosversionid = 202501`
  (the current demo version, matching the ETL `AMCOS_VERSION_ID` default).
- **Identity ids.** Tables with `GENERATED ALWAYS AS IDENTITY` keys let the
  database assign ids; downstream rows resolve those ids via subqueries on
  natural keys (e.g. a project is looked up by `userid` + `projectname`).

## Demo accounts

| User id | Role | Notes |
|---|---|---|
| `admin.demo` | `Admin` | Sees the Admin menu/pages |
| `analyst.demo` | `User` | Owns the sample Project Manager and PCS projects |

## Follow-up

This is a representative subset, not a comprehensive reference load. Production
reference data (full ZIP/FIPS/locality tables, pay schedules, BAH/BAS rates,
inventory, etc.) is loaded by the Python ETL pipeline in `../../etl`.
