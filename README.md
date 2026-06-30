# AMCOS — Army Civilian and Military Operational Support

AMCOS is a cost-estimation and workforce-analysis platform used by the U.S. Army. This repository contains all application code, ETL pipelines, and database migration scripts.

---

## Repository layout

| Directory | Purpose |
|---|---|
| `AMCOS.Web.Core/` | ASP.NET Core 8 Razor Pages web application (active migration target) |
| `AMCOS.Logic/` | Business logic library shared by Web and Console |
| `AMCOS.Data/` | Entity Framework Core data access layer |
| `AMCOS.Tests/` | xUnit / MSTest unit tests for C# projects |
| `AMCOS.Console/` | Batch-processing console application |
| `etl/` | Python ETL pipeline that replaces legacy SSIS DataLoad packages |
| `AMCOS.PostgreSQL/` | PostgreSQL schema migrations and seed-loading notes |
| `AMCOS.Web/` | Legacy WebForms frontend assets (gulp/Bower build → `dist/`) |
| `AMCOS.SSIS.*` | Legacy SSIS packages (retained for reference; Python ETL is the active replacement) |
| `AMCOS.AMCOS2020_MAR/` | Legacy SQL Server database project (source for PostgreSQL migration) |

---

## Prerequisites

### .NET (web + logic)
- .NET 8 SDK
- Visual Studio 2019 or later (or `dotnet` CLI)
- PostgreSQL 14+ with PostGIS (for geometry/geography column support)

### Python (ETL)
- Python 3.11+
- Dependencies: `pip install -r etl/requirements.txt`

### Frontend (legacy WebForms assets)
- Node.js 18+
- `npm install` then `npx gulp default` inside `AMCOS.Web/`

---

## Quick start — local development on Windows

This takes a fresh Windows machine from zero to a running, logged-in app: PostgreSQL + PostGIS, seed data, a local Keycloak (OIDC) login, and the web app. Commands are **PowerShell** unless noted. The `Development` environment is pre-wired (`AMCOS.Web.Core/appsettings.Development.json`) to the local Keycloak realm and database, so **no secrets or environment variables are required** for local dev.

> Adjust the PostgreSQL `bin` path (`...\PostgreSQL\16\bin`) and the repo path (`D:\OLD-TCO`) to match your machine.

### 1. Install prerequisites

| Tool | Install | Notes |
|---|---|---|
| **.NET 8 SDK** | `winget install Microsoft.DotNet.SDK.8` | Verify with `dotnet --version` (should print `8.x`). |
| **PostgreSQL 14+ with PostGIS** | [EDB installer](https://www.postgresql.org/download/windows/) | During install run **Application Stack Builder** and add the **PostGIS Bundle** — the migrations run `CREATE EXTENSION postgis`. Set the `postgres` superuser password to `postgr3s` to match the default dev connection string. Ensure `psql` is on `PATH` (e.g. `C:\Program Files\PostgreSQL\16\bin`). |
| **Docker Desktop** | `winget install Docker.DockerDesktop` | Runs the local Keycloak (OIDC) container. Start it before step 4. |
| **Git for Windows** (optional) | `winget install Git.Git` | Provides Git Bash, which can run the `init.sh` DB helper. Pure-PowerShell steps are given too. |

### 2. Create the database

The dev connection string in `AMCOS.Web.Core/appsettings.json` is `Host=localhost;Database=amcos;Username=postgres;Password=postgr3s`. Create the database (PostGIS is enabled automatically by the migrations):

```powershell
$env:PGPASSWORD = "postgr3s"
& "C:\Program Files\PostgreSQL\16\bin\psql.exe" -U postgres -h localhost -c "CREATE DATABASE amcos;"
```

> If your `postgres` password isn't `postgr3s`, either change it to match, or update the three `ConnectionStrings` in `appsettings.json` (or set `ConnectionStrings__AmcosPostgres`).

### 3. Apply migrations + seed data

**Option A — Git Bash** (uses the bundled helper; applies every migration then every seed file, including demo users and AMCOS Lite filter coverage):

```bash
cd /d/OLD-TCO
./AMCOS.PostgreSQL/init.sh            # add --fresh to drop & recreate the DB first
```

**Option B — PowerShell** (no Git Bash; runs the same files in the same order):

```powershell
$env:PGPASSWORD = "postgr3s"
$psql = "C:\Program Files\PostgreSQL\16\bin\psql.exe"
$root = "D:\OLD-TCO\AMCOS.PostgreSQL"
$files = @(
  "migrations\000_schemas.sql","migrations\001_lookup_tables.sql","migrations\002_data_tables.sql",
  "migrations\003_webuser_tables.sql","migrations\004_web_tables.sql","migrations\005_warehouse_tables.sql",
  "migrations\005b_costengine_tables.sql","migrations\006_functions.sql","migrations\006b_costengine_functions.sql",
  "migrations\007_stored_procedures.sql","migrations\008_views.sql",
  "seed\001_versions_and_lookups.sql","seed\002_cost_elements.sql","seed\003_warehouse_and_web.sql",
  "seed\004_demo_users_and_project.sql","seed\005_amcos_lite_coverage.sql"
)
foreach ($f in $files) { & $psql -U postgres -h localhost -d amcos -v ON_ERROR_STOP=1 -f "$root\$f" }
```

The seed scripts are **idempotent** (safe to re-run). They load representative lookups, AMCOS Lite filter coverage (pay plans → categories → locations), and two demo app users (`admin.demo`, `analyst.demo`). Details: `AMCOS.PostgreSQL/seed/README.md`.

### 4. Start Keycloak (OIDC login)

The app signs users in against a local Keycloak realm. With Docker Desktop running:

```powershell
cd D:\OLD-TCO
docker compose up -d
```

This starts Keycloak at `http://localhost:8180/auth` and auto-imports the **`cave`** realm (`keycloak/cave-realm.json`) with client `amcos-local` and two login users (password **`Password1!`** for both):

| Username | Realm role |
|---|---|
| `admin.user` | `amcos-admin` |
| `test.user` | `amcos-user` |

- Admin console: `http://localhost:8180/auth/admin` (`admin` / `admin`).
- First start takes ~20–30s; check readiness with `docker compose logs -f keycloak` (wait for "started").
- Stop with `docker compose down` (add `-v` to also wipe the realm database).

### 5. Run the web app

```powershell
cd D:\OLD-TCO\AMCOS.Web.Core
dotnet run
```

Open **`http://localhost:5050`**, click **Login**, and sign in as `admin.user` / `Password1!` (admin menu) or `test.user` / `Password1!` (standard user). To exercise AMCOS Lite, open **Applications → AMCOS Lite** and pick a pay plan such as *Active Enlisted (AE)*.

### Troubleshooting

| Symptom | Cause / fix |
|---|---|
| `No connection could be made ... localhost:8180` or `IDX20803: Unable to obtain configuration` | Keycloak isn't running. Run `docker compose up -d` (step 4) and retry. |
| `extension "postgis" is not available` | The PostGIS Bundle wasn't installed. Re-run EDB **Stack Builder**, add the PostGIS bundle, then re-run the migrations. |
| `password authentication failed for user "postgres"` | Local `postgres` password isn't `postgr3s` — change it to match or update `ConnectionStrings`. |
| Empty AMCOS Lite filters | Seed step 3 didn't run (or ran before migrations). Re-run step 3. |
| Port `5050` already in use | Change `applicationUrl` in `AMCOS.Web.Core/Properties/launchSettings.json`, and add the new redirect URI to `keycloak/cave-realm.json`. |

---

## Configuration

### Required environment variables (web application)

All secrets are injected via environment variables. ASP.NET Core maps `__`-delimited env vars to config paths (e.g., `OpenIdConnect__Authority` → `OpenIdConnect:Authority`).

| Environment variable | Description |
|---|---|
| `ConnectionStrings__AmcosPostgres` | PostgreSQL connection string |
| `OpenIdConnect__Authority` | OIDC provider base URL (e.g. Keycloak realm URL) |
| `OpenIdConnect__ClientId` | OIDC client ID |
| `OpenIdConnect__ClientSecret` | OIDC client secret |
| `AllowedHosts` | Comma-separated list of allowed hostnames (e.g. `amcos.example.com`) |
| `CaveUrl` | Base URL of the CAVE application |
| `AmcosUrl` | Callback URL for this application (`/signin-oidc`) |

The application will **fail to start** in non-Development environments if `OpenIdConnect__Authority`, `OpenIdConnect__ClientId`, `OpenIdConnect__ClientSecret`, or a database connection string are missing.

### Required environment variables (ETL)

| Environment variable | Description |
|---|---|
| `AMCOS_DB_CONNECTION` | PostgreSQL connection string for the ETL pipeline (**required**) |
| `AMCOS_DATA_DIR` | Directory containing raw source data files (default: `etl/data/`) |
| `AMCOS_OUTPUT_DIR` | Directory for ETL output/staging files (default: `etl/output/`) |
| `AMCOS_VERSION_ID` | AMCOS data version (default: `202501`) |
| `AMCOS_LOG_LEVEL` | Python logging level (default: `INFO`) |
| `AMCOS_BATCH_SIZE` | Database upsert batch size (default: `1000`) |

The ETL pipeline will **exit with an error** if `AMCOS_DB_CONNECTION` is not set.

---

## Running locally

### Web application

```bash
# 1. Set required environment variables (or use a .env file / user-secrets)
export OpenIdConnect__Authority="https://your-keycloak/realms/amcos"
export OpenIdConnect__ClientId="amcos-web"
export OpenIdConnect__ClientSecret="..."
export ConnectionStrings__AmcosPostgres="Host=localhost;Database=amcos;Username=amcos_user;******"

# 2. Run
cd AMCOS.Web.Core
dotnet run
```

For Development mode (bypasses OIDC validation), the `ASPNETCORE_ENVIRONMENT` variable defaults to `Development` and no OIDC config is required.

### ETL pipeline

```bash
export AMCOS_DB_CONNECTION="host=localhost dbname=amcos user=amcos_user ******"
cd etl
python -m dataload.main
```

### ETL tests

```bash
cd /path/to/repo
python -m pytest etl/tests -q
```

---

## Database setup

On Windows, follow the [Quick start](#quick-start--local-development-on-windows) above. On any platform, the bundled helper applies every migration (in order) and then every seed file:

```bash
./AMCOS.PostgreSQL/init.sh            # flags: --fresh, --no-seed, --host/--port/--db/--user/--password
```

To run them by hand, execute the migrations in numeric order — `000` → `001` → `002` → `003` → `004` → `005` → `005b` → `006` → `006b` → `007` → `008` — from `AMCOS.PostgreSQL/migrations/`, then the seed files `001` → `005` from `AMCOS.PostgreSQL/seed/`. The seed scripts are idempotent; see `AMCOS.PostgreSQL/seed/README.md` for what each loads.

> **Note:** some non-web functions/views carried over from the legacy SQL Server project (`AMCOS.AMCOS2020_MAR`) may still be stubs in `006_functions.sql` / `008_views.sql`; the cost-engine objects live in `005b`/`006b`.

---

## Deployment (GitLab CI/CD)

The active CI/CD pipeline is `.gitlab-ci.yml`. `azure-pipelines.yml` is the legacy Azure DevOps definition kept for reference only.

### Pipeline stages

| Stage | Jobs |
|---|---|
| `validate` | Check all required CI/CD variables are present |
| `build` | npm/gulp frontend build, NuGet restore, MSBuild |
| `test` | VSTest unit tests |
| `publish` | Zip artifact and upload to S3 |
| `deploy` | Run DB migrations, then trigger AWS CodeDeploy |

### Required CI/CD variables (GitLab Settings → CI/CD → Variables)

| Variable | Description |
|---|---|
| `AWS_ACCESS_KEY_ID` | IAM access key with S3 and CodeDeploy permissions |
| `AWS_SECRET_ACCESS_KEY` | Corresponding IAM secret |
| `AWS_DEFAULT_REGION` | AWS region (e.g. `us-east-1`) |
| `S3_BUCKET` | S3 bucket name for build artifacts |
| `CODEDEPLOY_APP` | AWS CodeDeploy application name |
| `CODEDEPLOY_GROUP` | AWS CodeDeploy deployment group name |
| `AMCOS_DB_HOST` | Database host for migration step |
| `AMCOS_DB_NAME` | Database name for migration step |
| `AMCOS_DB_USER` | Database user for migration step |
| `AMCOS_DB_PASSWORD` | Database password for migration step |

---

## Known gaps (work in progress)

The following items are tracked and require follow-up before or after go-live:

- **Blocker:** `AMCOS.PostgreSQL/migrations/006_functions.sql` and `008_views.sql` are placeholders — non-web SQL Server functions and views need to be converted to PostgreSQL.
- **Note:** `AMCOS.PostgreSQL/seed/` now ships a representative development/demo dataset (`001`–`005`, loaded by `init.sh`). It is **not** a full production reference load — production lookup/reference data is loaded by the Python ETL pipeline in `etl/`.
- **Blocker:** `AMCOS.Web/dist/` is not committed — the legacy frontend build artifacts must be generated (`npm install && npx gulp default` in `AMCOS.Web/`) and included in the deployment package.
- **Blocker:** Xwalk, Civilian PCS, and Admin modules are placeholder pages — full feature implementation is required.
- **Post-launch:** Session storage **and authentication tickets** use the in-memory `IDistributedCache` (`AddDistributedMemoryCache`). The OIDC auth cookie is kept small by storing the (token-heavy) ticket server-side via `DistributedCacheTicketStore`. In-memory means sessions/logins do **not** survive an app restart and are **not** shared across nodes — swap for a Redis-backed `IDistributedCache` before any multi-node deployment.
- **Post-launch:** ETL pipeline has no retry/backoff logic or transaction rollback for partial failures.
- **Post-launch:** ETL test coverage covers only 2 of 40+ loader modules.

See `AMCOS.Web.Core/MIGRATION_NOTES.md` for the full WebForms → ASP.NET Core migration notes.
