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

## Follow-up work

This bundle focuses on the requested tables and `web` stored procedures. Remaining SQL Server functions, views, and non-web stored procedures should be migrated next, then validated against a PostgreSQL instance with representative AMCOS seed data.
