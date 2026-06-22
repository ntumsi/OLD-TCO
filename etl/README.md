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

## Representative SSIS mappings

The implementation was based on the DTSX packages in:

- `AMCOS.SSIS.DataLoad.BAHRates.dtsx`
- `AMCOS.SSIS.DataLoad.JICInflationRates.dtsx`
- `AMCOS.SSIS.DataLoad.Locations.dtsx`
- `AMCOS.SSIS.DataLoad.OPM.dtsx`
- `AMCOS.SSIS.DataLoad.DCIPS.dtsx`
- `AMCOS.SSIS.DataLoad.Inventory.dtsx`
- `AMCOS.SSIS.DataLoad.DMDC.Inventory.dtsx`
- `AMCOS.SSIS.PaySchedule.DCPAS.dtsx`
- `AMCOS.SSIS.DataLoad.PaySchedule.Military.dtsx`
- `AMCOS.SSIS.DataLoad.PaySchedule.FWS.dtsx`
- `AMCOS.SSIS.DataLoad.OccupationalEmploymentStatistics.dtsx`
- `AMCOS.SSIS.DataLoad.LookupTables.dtsx`
- `AMCOS.SSIS.ImportLookup.dtsx`
- `AMCOS.SSIS.ImportCosts*.dtsx`
- `AMCOS.SSIS.ExportData.dtsx`
- `AMCOS.SSIS.ExportForRelease.dtsx`

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

- `dataload/bah_rates.py` – loads annual BAH rates, ZIP-to-MHA xwalk, and MHA names
- `dataload/jic_inflation_rates.py` – loads JIC inflation rate CSVs into `data.asafmcjointinflationrates`
- `dataload/opm.py` – loads OPM locality, COLA, raw GS/GL, and special rate reference files
- `dataload/dcips.py` – loads DCIPS cyber salary tables and GG base pay raw data
- `dataload/locations.py` – loads duty station lookup data
- `dataload/pay_schedule_gs.py` – loads GS-style schedules from DCPAS/OPM CSVs
- `dataload/pay_schedule_military.py` – loads military basic and drill pay
- `dataload/pay_schedule_fws.py` – loads FWS wage schedules from AF/NAF folders
- `dataload/inventory.py` – loads raw DMDC inventory extracts into staging
- `dataload/dmdc_inventory.py` – partitions raw DMDC inventory into civilian and military outputs
- `dataload/bls_oes.py` – loads BLS OES metro, national, and area-definition files
- `dataload/lookup_tables.py` – loads AOC, MOS, WOMOS, CMF, and GS series lookup data
- `dataload/main.py` – ordered orchestration for the primary dataload pipeline
- `datasync/import_lookup.py` – imports exported lookup CSVs back into PostgreSQL
- `datasync/import_costs.py` – imports exported crunch cost CSVs
- `datasync/export_data.py` – exports PostgreSQL tables to CSV, replacing raw/access-based exports

## Notes

- All configuration is environment-driven.
- Loaders are safe to rerun: they delete version-specific rows or use UPSERTs.
- Column matching is tolerant of SQL Server/Python naming differences by normalizing names before insert.
