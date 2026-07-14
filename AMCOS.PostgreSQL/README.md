# AMCOS PostgreSQL Migration

This directory contains a first-pass PostgreSQL translation of key AMCOS SQL Server database-project assets from `AMCOS.AMCOS2020_MAR`.

## Layout

- `migrations/000_schemas.sql` – schema bootstrap
- `migrations/001_lookup_tables.sql` – lookup schema tables
- `migrations/002_data_tables.sql` – data schema tables
- `migrations/003_webuser_tables.sql` – webuser schema tables
- `migrations/004_web_tables.sql` – web schema tables
- `migrations/005_warehouse_tables.sql` – warehouse schema tables
- `migrations/006_functions.sql` – placeholder for non-web function conversion
- `migrations/007_stored_procedures.sql` – converted web stored procedures
- `migrations/008_views.sql` – placeholder for view conversion
- `seed/README.md` – seed-loading notes

## Notes

- SQL Server identity columns were translated to PostgreSQL identity columns.
- SQL Server `bit` columns were translated to `boolean`.
- Spatial SQL Server types were mapped to `geometry` / `geography` and assume PostGIS-compatible deployment.
- Complex SQL Server procedures that returned multiple result sets or dynamic pivots were translated to functions returning `(result_set_name text, row_data jsonb)`.
- Simpler result-set procedures were also wrapped with the same JSON-row pattern for consistency.
- The migration intentionally preserves AMCOS schema names and table names in lower-case PostgreSQL form.

## Usage

Run the migrations in numeric order:

```sql
\i migrations/000_schemas.sql
\i migrations/001_lookup_tables.sql
\i migrations/002_data_tables.sql
\i migrations/003_webuser_tables.sql
\i migrations/004_web_tables.sql
\i migrations/005_warehouse_tables.sql
\i migrations/006_functions.sql
\i migrations/007_stored_procedures.sql
\i migrations/008_views.sql
```

In practice the migration + seed list is applied by **`init.sh`** (which enumerates
every file in the correct order, including the `002b`–`002e` input tables and the
`005*`/`006*`/`008*` crunch-engine + view files that are not shown in the abbreviated
list above):

```bash
./init.sh                 # apply all migrations + seed to localhost/amcos
./init.sh --fresh         # drop & recreate the database first (destructive)
./init.sh --no-seed       # migrations only
```

## Docker (`docker compose up`) and re-applying on an existing database

`docker-compose.yml` runs a one-shot `amcos-db-init` service that calls `init.sh`
against the `amcos-db` container. It is **guarded** — it only runs when the schema
is empty:

```
SELECT count(*) FROM pg_tables WHERE schemaname IN ('lookup','data','webuser','web','warehouse')
```

So on a **fresh volume** everything (all migrations, including newly added files) is
applied automatically. But on an **already-initialised `amcos_db_data` volume** the
guard sees existing tables and **skips init entirely** — newly added migration files
and changed procedures/views will *not* be picked up. To apply them, either:

- **Reset the volume:** `docker compose down -v && docker compose up` (clean re-init), or
- **Apply the changed files manually**, e.g. the input tables/views added for the
  crunch engine:
  ```bash
  docker compose exec amcos-db bash -c '
    for f in 002b_dataload_tables 002c_xwalk_tables 002d_staging_tables \
             002e_payschedule_raw_tables 008d_input_views; do
      psql -U postgres -d amcos -f /amcos-sql/migrations/$f.sql
    done'
  ```

Manual re-apply is safe: table migrations use `CREATE TABLE IF NOT EXISTS`, views use
`CREATE OR REPLACE VIEW`, and procedures use `CREATE OR REPLACE PROCEDURE`, so
re-running them against a populated database is idempotent.

## Follow-up work

This bundle focuses on the requested tables and `web` stored procedures. Remaining SQL Server functions, views, and non-web stored procedures should be migrated next, then validated against a PostgreSQL instance with representative AMCOS seed data.
