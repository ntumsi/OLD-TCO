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

```sql
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

## Connecting to a pre-existing PostgreSQL and Keycloak (same ports)

Use this when a PostgreSQL server **and** a Keycloak instance are **already running**
(e.g. in another Docker stack) on the ports this project uses — `5432` for Postgres
and `8180` for Keycloak — and you want to reuse them instead of the bundled compose
services (which would collide on those ports).

**Do not** start the bundled `amcos-db` / `keycloak*` services. Either skip
`docker compose up` entirely, or bring up only services that don't conflict. The app
defaults already point at these ports, so if the existing services match the layout
below **no `appsettings` change is needed**:

- DB (`ConnectionStrings.Amcos*` in `appsettings.json`):
  `Host=localhost;Database=amcos;Username=postgres;Password=postgr3s`
- Keycloak (`appsettings.Development.json`):
  `Authority = http://localhost:8180/auth/realms/cave`, `ClientId = amcos-local`

### 1. PostgreSQL — create the database, then migrate + seed

The existing server **must have PostGIS available** — `migrations/000_schemas.sql`
runs `CREATE EXTENSION IF NOT EXISTS postgis`. If the server is a plain `postgres`
image without the PostGIS library, that statement fails and you must install PostGIS
there first (or repoint at a PostGIS-capable server).

`init.sh` connects with `psql`, so run it from any host that has a `psql` client and
network access to the server. It takes the target as flags (defaults shown in
`--help`). Because it connects **directly to `--db`**, create the database first
(don't use `--fresh` against a shared server — that **drops** the `amcos` database):

```bash
# create the database on the pre-existing server (one time)
PGPASSWORD=postgr3s createdb -h localhost -p 5432 -U postgres amcos

# apply all migrations + seed to it
./init.sh --host localhost --port 5432 --db amcos --user postgres --password postgr3s
```

If the `amcos` schema is **already present** and you only need the seed data (init’s
compose guard, and re-running full migrations, are otherwise no-ops), load the seed
files directly in numeric order:

```bash
export PGPASSWORD=postgr3s
for f in AMCOS.PostgreSQL/seed/*.sql; do
  psql -h localhost -p 5432 -U postgres -d amcos -v ON_ERROR_STOP=1 -f "$f"
done
```

To add only the crunch-engine input tables/views to an existing `amcos`, apply the
`002b`–`002e` + `008d` files as shown in the Docker section above (they are
`IF NOT EXISTS` / `CREATE OR REPLACE`, safe to re-run).

### 2. Keycloak — import the `cave` realm into the running instance

The app needs realm **`cave`** with client **`amcos-local`**, served under the
**`/auth`** relative path (that is why the authority is `…:8180/auth/realms/cave`).
The bundled compose imports `keycloak/cave-realm.json` for you; against a
**pre-existing** Keycloak you import it yourself, without restarting that instance:

**Option A — Admin console (simplest).** Open `http://localhost:8180/auth/admin`
(admin user/password of the existing instance; the bundled default is `admin`/`admin`),
then **Create realm → Resource file → `keycloak/cave-realm.json` → Create**. If a
`cave` realm already exists, delete it first or use **Realm settings → Partial import →
overwrite** so the `amcos-local` client and test users are refreshed.

**Option B — CLI (`kcadm.sh`) into the running container.** Replace `<kc>` with the
existing Keycloak container name:

```bash
docker cp keycloak/cave-realm.json <kc>:/tmp/cave-realm.json
docker exec <kc> /opt/keycloak/bin/kcadm.sh config credentials \
  --server http://localhost:8080/auth --realm master --user admin --password admin
docker exec <kc> /opt/keycloak/bin/kcadm.sh create realms -f /tmp/cave-realm.json
```

Notes:
- If the pre-existing Keycloak is **not** served under `/auth`
  (`KC_HTTP_RELATIVE_PATH`), the realm URL won’t match — either set that relative
  path on the existing instance or change `Authority`/`CaveUrl` in
  `appsettings.Development.json` to the actual base path.
- `kc.sh import` (the offline command the compose file uses) requires the server to
  be **stopped**; for a live instance use the admin console or `kcadm.sh` as above.

## Follow-up work

This bundle focuses on the requested tables and `web` stored procedures. Remaining SQL Server functions, views, and non-web stored procedures should be migrated next, then validated against a PostgreSQL instance with representative AMCOS seed data.
