# AMCOS Python ETL

Python replacements for key AMCOS SSIS packages. The scripts in this directory read source files from a configurable data directory, apply the same broad transformations found in the DTSX packages, and load data into PostgreSQL with idempotent delete-and-upsert patterns.

## Layout

- `config/settings.py` – environment-based configuration
- `common/db.py` – PostgreSQL helpers for deletes, inserts, and upserts
- `common/file_utils.py` – CSV/Excel/fixed-width readers and file discovery
- `common/logging_utils.py` – shared logging bootstrap
- `dataload/` – replacements for SSIS DataLoad packages
- `datasync/` – replacements for SSIS DataSync import/export packages
- `tests/` – unit tests for key transformations

## Environment variables

- `AMCOS_DB_CONNECTION` – PostgreSQL libpq connection string
- `AMCOS_DATA_DIR` – root folder containing source files referenced by the SSIS packages
- `AMCOS_OUTPUT_DIR` – export folder for generated CSVs
- `AMCOS_VERSION_ID` – AMCOS version id to stamp on versioned loads
- `AMCOS_LOG_LEVEL` – log level, default `INFO`
- `AMCOS_BATCH_SIZE` – bulk insert batch size, default `1000`

## Complete SSIS coverage map

Every active SSIS package in the repository is now replaced by a Python module.

### DataLoad replacements

| SSIS package | Python module |
|---|---|
| `AMCOS.SSIS.ATRRS-ATRMCrosswalk.dtsx` | `dataload/atrrs.py` |
| `AMCOS.SSIS.ATRRSCourseType.dtsx` | `dataload/atrrs.py` |
| `AMCOS.SSIS.DataLoad.ATRRSCourseType.dtsx` | `dataload/atrrs.py` |
| `AMCOS.SSIS.DataLoad.ArmyBudget.dtsx` | `dataload/army_budget.py` |
| `AMCOS.SSIS.DataLoad.ArmyPayType.dtsx` | `dataload/army_pay_type.py` |
| `AMCOS.SSIS.DataLoad.BAHRates.dtsx` | `dataload/bah_rates.py` |
| `AMCOS.SSIS.DataLoad.BLS.ECEC.dtsx` | `dataload/bls_ecec.py` |
| `AMCOS.SSIS.DataLoad.CareerProgram.dtsx` | `dataload/career_program.py` |
| `AMCOS.SSIS.DataLoad.CensusZIP.dtsx` | `dataload/census_zip.py` |
| `AMCOS.SSIS.DataLoad.ConusCola.dtsx` | `dataload/conus_cola.py` |
| `AMCOS.SSIS.DataLoad.DCIPS.dtsx` | `dataload/dcips.py` |
| `AMCOS.SSIS.DataLoad.DCPDS.dtsx` | `dataload/dcpds.py` |
| `AMCOS.SSIS.DataLoad.DFAS.dtsx` | `dataload/dfas.py` |
| `AMCOS.SSIS.DataLoad.DMDC.Inventory.dtsx` | `dataload/inventory.py` + `dataload/dmdc_inventory.py` |
| `AMCOS.SSIS.DataLoad.DMDC.Inventory2024.dtsx` | `dataload/inventory.py` (`load_inventory_2024`) |
| `AMCOS.SSIS.DataLoad.DMDC.InventoryCivilian.dtsx` | `dataload/dmdc_inventory.py` (`load_civilian_inventory`) |
| `AMCOS.SSIS.DataLoad.DMDC.InventoryMilitary.dtsx` | `dataload/dmdc_inventory.py` (`load_military_inventory`) |
| `AMCOS.SSIS.DataLoad.DMDC.InventoryMilitaryOfficer.dtsx` | `dataload/dmdc_inventory.py` (`load_military_inventory`) |
| `AMCOS.SSIS.DataLoad.DMDC.MembersAndDependents.dtsx` | `dataload/dmdc_members.py` |
| `AMCOS.SSIS.DataLoad.DMDC.Pay.dtsx` | `dataload/dmdc_pay.py` |
| `AMCOS.SSIS.DataLoad.DTMO.dtsx` | `dataload/dtmo.py` |
| `AMCOS.SSIS.DataLoad.FIPS_ZIP.dtsx` | `dataload/fips_zip.py` |
| `AMCOS.SSIS.DataLoad.FMSWeb.dtsx` | `dataload/fmsweb.py` |
| `AMCOS.SSIS.DataLoad.G1PAM.dtsx` | `dataload/g1pam.py` |
| `AMCOS.SSIS.DataLoad.GFEBS.dtsx` | `dataload/gfebs.py` |
| `AMCOS.SSIS.DataLoad.Inventory.dtsx` | `dataload/inventory.py` |
| `AMCOS.SSIS.DataLoad.JICInflationRates.dtsx` | `dataload/jic_inflation_rates.py` |
| `AMCOS.SSIS.DataLoad.Locations.dtsx` | `dataload/locations.py` |
| `AMCOS.SSIS.DataLoad.LookupGSOccupations.dtsx` | `dataload/lookup_gs_occupations.py` (also `dataload/lookup_tables.py`) |
| `AMCOS.SSIS.DataLoad.LookupLocalityRates.dtsx` | `dataload/opm.py` (`load_locality_rates`) |
| `AMCOS.SSIS.DataLoad.NewInventory.dtsx` | `dataload/inventory.py` (`load_inventory_2024`) |
| `AMCOS.SSIS.DataLoad.NonLocalityBAHRates.dtsx` | `dataload/non_locality_bah.py` |
| `AMCOS.SSIS.DataLoad.OPM.dtsx` | `dataload/opm.py` |
| `AMCOS.SSIS.DataLoad.OccupationalEmploymentStatistics.dtsx` | `dataload/bls_oes.py` |
| `AMCOS.SSIS.DataLoad.PaySchedule.FWS.dtsx` | `dataload/pay_schedule_fws.py` |
| `AMCOS.SSIS.DataLoad.PaySchedule.Military.dtsx` | `dataload/pay_schedule_military.py` |
| `AMCOS.SSIS.DataLoad.PaySchedules_SES.dtsx` | `dataload/pay_schedule_ses.py` |
| `AMCOS.SSIS.DataLoad.Training.dtsx` | `dataload/training.py` |
| `AMCOS.SSIS.DataLoad.WASS.dtsx` | `dataload/wass.py` |
| `AMCOS.SSIS.Export.LookupTables.dtsx` | `datasync/export_data.py` |
| `AMCOS.SSIS.ExportData.dtsx` | `datasync/export_data.py` |
| `AMCOS.SSIS.InsertUpdateCostElement.dtsx` | `dataload/cost_element.py` |
| `AMCOS.SSIS.Load.WageRaw.dtsx` | `dataload/pay_schedule_fws.py` |
| `AMCOS.SSIS.PaySchedule.DCPAS.dtsx` | `dataload/pay_schedule_gs.py` |
| `AMCOS.SSIS.Sync.Export.dtsx` | `datasync/export_data.py` |
| `AMCOS.SSIS.UpdateCostElement.dtsx` | `dataload/cost_element.py` |
| `AMCOS.SSIS.WageAreaDefinition.dtsx` | `dataload/wage_areas.py` |
| `LoadWageGrade.dtsx` | `dataload/pay_schedule_fws.py` |

### DataSync replacements

| SSIS package | Python module |
|---|---|
| `AMCOS.SSIS.ImportAll.dtsx` | `datasync/import_costs.py` + `datasync/import_inventory.py` |
| `AMCOS.SSIS.ImportCostsARNG.dtsx` | `datasync/import_costs.py` |
| `AMCOS.SSIS.ImportCostsActiveDuty.dtsx` | `datasync/import_costs.py` |
| `AMCOS.SSIS.ImportCostsCCE.dtsx` | `datasync/import_costs.py` |
| `AMCOS.SSIS.ImportCostsCivilian.dtsx` | `datasync/import_costs.py` |
| `AMCOS.SSIS.ImportCostsUSAR.dtsx` | `datasync/import_costs.py` |
| `AMCOS.SSIS.ImportInventory.dtsx` | `datasync/import_inventory.py` |
| `AMCOS.SSIS.ImportLookup.dtsx` | `datasync/import_lookup.py` |
| `AMCOS.SSIS.ImportPaySchedule.dtsx` | `datasync/import_pay_schedule.py` |
| `AMCOS.SSIS.ImportRaw-civilian-pcs.dtsx` | `datasync/import_raw.py` |
| `AMCOS.SSIS.ImportRaw-crunch-civilian.dtsx` | `datasync/import_raw.py` |
| `AMCOS.SSIS.ImportRaw-crunch-military.dtsx` | `datasync/import_raw.py` |
| `AMCOS.SSIS.ImportRaw-inventory.dtsx` | `datasync/import_raw.py` |
| `AMCOS.SSIS.ImportRaw-warehouse.dtsx` | `datasync/import_raw.py` |
| `AMCOS.SSIS.ImportWarehouse.dtsx` | `datasync/import_warehouse.py` |
| `AMCOS.SSIS.ImportWeb.dtsx` | `datasync/import_web.py` |
| `AMCOS.SSIS.MigrateExport.dtsx` | `datasync/migrate.py` |
| `AMCOS.SSIS.MigrateImport.dtsx` | `datasync/migrate.py` |
| `AMCOS.SSIS.MigrateUnitPersonnel.dtsx` | `datasync/migrate.py` |
| `AMCOS.SSIS.ExportForRelease.dtsx` | `datasync/export_data.py` |
| `AMCOS.SSIS.ExportRawFromDev.dtsx` | `datasync/export_data.py` |

> **Note:** `AMCOS.SSIS.DeployFixes.dtsx`, `AMCOS.SSIS.Enlisted-91C-Fix.dtsx`, and `AMCOS.SSIS.Migrate17C-Fix.dtsx` are one-time data-correction packages that do not have ongoing operational equivalents; they are intentionally omitted.

### Legacy replacements

| SSIS package | Python module |
|---|---|
| `AMCOS.SSIS.DataLoad.CostElement.dtsx` | `dataload/cost_element.py` |
| `AMCOS.SSIS.DataLoad.DMDC.AMOSTABS.dtsx` | `dataload/dmdc_legacy.py` |
| `AMCOS.SSIS.DataLoad.DMDC.ContinuationRates.dtsx` | `dataload/dmdc_legacy.py` |
| `AMCOS.SSIS.DataLoad.DMDC.ETS.dtsx` | `dataload/dmdc_legacy.py` |
| `AMCOS.SSIS.DataLoad.DMDC.OFBYMOS.dtsx` | `dataload/dmdc_legacy.py` |
| `AMCOS.SSIS.DataLoad.DMDC.RAR2409.dtsx` | `dataload/dmdc_legacy.py` |
| `AMCOS.SSIS.DataLoad.DMDC.SourceOfCommission.dtsx` | `dataload/dmdc_source_of_commission.py` |
| `AMCOS.SSIS.DataLoad.DMDC.TABMOS.dtsx` | `dataload/dmdc_legacy.py` |
| `AMCOS.SSIS.DataLoad.DutyStation.dtsx` | `dataload/locations.py` |
| `AMCOS.SSIS.DataLoad.LookupTables.dtsx` | `dataload/lookup_tables.py` |
| `AMCOS.SSIS.DataLoad.LookupUIC.dtsx` | `dataload/fmsweb.py` |
| `AMCOS.SSIS.DataLoad.MilitaryBase.dtsx` | `dataload/military_installations.py` |
| `AMCOS.SSIS.DataLoad.MilitaryInstallations.dtsx` | `dataload/military_installations.py` |
| `AMCOS.SSIS.DataLoad.SACSHeader.dtsx` | `dataload/fmsweb.py` |
| `AMCOS.SSIS.DataLoad.SingleValues.dtsx` | `dataload/single_values.py` |
| `AMCOS.SSIS.DataLoad.SpecialRates.dtsx` | `dataload/special_rates.py` |
| `AMCOS.SSIS.DataLoad.SpecialRates (1).dtsx` | `dataload/special_rates.py` |
| `AMCOS.SSIS.DataLoad.TableValues.dtsx` | `dataload/table_values.py` |
| `AMCOS.SSIS.DataLoad.UICLocation.dtsx` | `dataload/fmsweb.py` |
| `AMCOS.SSIS.DataLoad.WageAreas.dtsx` | `dataload/wage_areas.py` |
| `AMCOS.SSIS.ExportForRelease.dtsx` | `datasync/export_data.py` |

## Running

Install dependencies:

```bash
python -m pip install -r etl/requirements.txt
```

Run a single loader:

```bash
cd etl
python -m dataload.bah_rates
python -m dataload.jic_inflation_rates
python -m datasync.import_lookup
```

Run the orchestrator:

```bash
cd etl
python -m dataload.main
```

Run tests:

```bash
python -m pytest etl/tests -q
```

## Script summary

### dataload/

- `atrrs.py` – loads ATRRS/ATRM crosswalk and ATRRSCourseTypeMOS lookup
- `army_budget.py` – loads cProbe PB Army budget data into `dataload.ArmyBudget`
- `army_pay_type.py` – loads Army pay type / DMDC-to-AMCOS crosswalk into `lookup.ArmyPayType`
- `bah_rates.py` – loads annual BAH rates, ZIP-to-MHA xwalk, and MHA names
- `bls_ecec.py` – loads BLS ECEC area, estimate, and series files into `BLS_ECT.*`
- `bls_oes.py` – loads BLS OES metro, national, and area-definition files
- `career_program.py` – loads occupational-series-to-career-program matrix
- `census_zip.py` – loads Census ZIP and military installation geo data
- `conus_cola.py` – loads CONUS COLA ZIP locations and rate tables
- `cost_element.py` – loads and upserts cost element reference data
- `dcips.py` – loads DCIPS cyber salary tables and GG base pay raw data
- `dcpds.py` – loads DCPDS BoBI workforce data into `load_inventory.WASS_Raw`
- `dfas.py` – loads DFAS basic and drill pay schedules
- `dmdc_inventory.py` – partitions raw DMDC inventory into civilian/military staging tables (fine-grained)
- `dmdc_legacy.py` – loads legacy DMDC tables: AMOSTABS, ContinuationRates, ETS, OFBYPMOS, RAR2409, TABMOS
- `dmdc_members.py` – loads DMDC members and dependents data
- `dmdc_pay.py` – loads DMDC active duty and reserve component pay with validation
- `dmdc_source_of_commission.py` – loads DMDC military acquisition source of commission
- `dtmo.py` – loads DTMO military spendable income, OHA, and supplemental BAH/COLA files
- `fips_zip.py` – loads FIPS ZIP geographic crosswalk into `lookup.FIPS_ZIP`
- `fmsweb.py` – loads FMSWeb SACS header/personnel, lockpoint, UIC, and UIC-location data
- `g1pam.py` – loads G1 PAM position data (BRPEXP, CMF, 711 files) into `POS.*`
- `gfebs.py` – loads GFEBS functional area, activity type, and cost center lookups
- `inventory.py` – loads raw DMDC inventory flat-files and 2024-format CSVs into staging
- `jic_inflation_rates.py` – loads JIC inflation rate CSVs into `data.asafmcjointinflationrates`
- `locations.py` – loads duty station lookup data
- `lookup_gs_occupations.py` – loads GS occupational series and group data
- `lookup_tables.py` – loads AOC, MOS, WOMOS, CMF, and GS series lookup data
- `main.py` – ordered orchestration for the full dataload pipeline
- `military_installations.py` – loads military installations and base reference data
- `non_locality_bah.py` – loads non-locality BAH rates into `dataload.NonLocalityBAHRates`
- `opm.py` – loads OPM locality, COLA, GS/GL raw schedules, and locality rates
- `pay_schedule_fws.py` – loads FWS wage schedules from AF/NAF folders
- `pay_schedule_gs.py` – loads GS-style schedules from DCPAS/OPM CSVs
- `pay_schedule_military.py` – loads military basic and drill pay
- `pay_schedule_ses.py` – loads SES pay schedules into `load_payschedule.PaySchedule_SES`
- `single_values.py` – loads single-value reference constants
- `special_rates.py` – loads OPM special rate tables and agency/location/occupation crosswalks
- `table_values.py` – loads table-driven values (special pays eligibility, PCS rates, continuation rates)
- `training.py` – loads ATRM cost data and ATRRS CNTROST report into training staging tables
- `wage_areas.py` – loads DCPAS wage area definitions into `lookup.WageAreaNew`
- `wass.py` – loads WASS workforce data into `load_inventory.WASS_Raw`

### datasync/

- `export_data.py` – exports PostgreSQL tables to CSV, replacing ExportData/ExportForRelease/Sync.Export
- `import_costs.py` – imports exported crunch cost CSVs (all component variants)
- `import_inventory.py` – imports processed inventory CSVs into staging tables
- `import_lookup.py` – imports exported lookup CSVs back into PostgreSQL
- `import_pay_schedule.py` – imports exported pay schedule CSVs into staging tables
- `import_raw.py` – imports raw crunch, warehouse, inventory, and civilian-PCS CSVs from dev exports
- `import_warehouse.py` – imports warehouse category, location, and PPXwalk CSVs
- `import_web.py` – imports web PayPlanTag CSV
- `migrate.py` – exports and re-imports webuser/web tables for database migrations

## Notes

- All configuration is environment-driven.
- Loaders are safe to rerun: they delete version-specific rows or use UPSERTs.
- Column matching is tolerant of SQL Server/Python naming differences by normalizing names before insert.
