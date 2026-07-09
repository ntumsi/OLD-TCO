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
| **Docker Desktop** | `winget install Docker.DockerDesktop` | Runs the local **database** and **Keycloak** containers. This is the recommended way to get the database — no PostgreSQL install needed. Start it before steps 2 and 4. |
| **PostgreSQL 14+ with PostGIS** *(only if NOT using the Docker DB)* | [EDB installer](https://www.postgresql.org/download/windows/) | Alternative to the Docker database. During install run **Application Stack Builder** and add the **PostGIS Bundle** — the migrations run `CREATE EXTENSION postgis`. Set the `postgres` superuser password to `postgr3s` to match the default dev connection string. Ensure `psql` is on `PATH` (e.g. `C:\Program Files\PostgreSQL\16\bin`). |
| **Git for Windows** (optional) | `winget install Git.Git` | Provides Git Bash, which can run the `init.sh` DB helper. Pure-PowerShell steps are given too. |

### 2. Start the database

The dev connection string in `AMCOS.Web.Core/appsettings.json` is `Host=localhost;Database=amcos;Username=postgres;Password=postgr3s`. Choose **one** of the following.

**Option A — Docker (recommended; no local PostgreSQL install needed).** With Docker Desktop running, bring up the entire backend — database **and** Keycloak, fully migrated, seeded, and with the OIDC client imported — with a single command:

```powershell
cd D:\OLD-TCO
docker compose up -d
```

This starts and prepares everything the app needs, with **no manual migrate/seed step**:

- **`amcos-db`** — PostgreSQL 16 **with PostGIS** at `localhost:5432` (db `amcos`, user `postgres`, password `postgr3s`), matching the dev connection string. Data persists in the `amcos_db_data` volume (`docker compose down -v` wipes it).
- **`amcos-db-init`** — one-shot: applies every migration then seed file on first run; automatically skipped once the schema exists.
- **`keycloak`** — Keycloak at `http://localhost:8180/auth` (login users in step 4).
- **`keycloak-config`** — one-shot: (re)imports the `cave` realm + `amcos-local` client from `keycloak/cave-realm.json` on **every** `up` (`--override=true`), so a "Client not found" from a stale volume can't happen.

First run takes ~45–60s (DB migrate/seed + realm import). Check readiness with `docker compose ps`: `amcos-db` and `keycloak` show **healthy**; the two one-shot `*-init` / `*-config` containers show **Exited (0)** once done.

> **On the Docker path (Option A), steps 3 and 4 below are handled automatically — skip to step 5.** (`docker compose up -d --wait` also works but returns a non-zero exit code when the one-shot init containers exit — a known Compose quirk, not a failure. Prefer plain `docker compose up -d` and confirm with `docker compose ps`.)

**Option B — local PostgreSQL install.** Install PostgreSQL + the PostGIS bundle (see prerequisites), then create the database:

```powershell
$env:PGPASSWORD = "postgr3s"
& "C:\Program Files\PostgreSQL\16\bin\psql.exe" -U postgres -h localhost -c "CREATE DATABASE amcos;"
```

> If your `postgres` password isn't `postgr3s`, either change it to match, or update the three `ConnectionStrings` in `appsettings.json` (or set `ConnectionStrings__AmcosPostgres`).

> **Option B covers only the database.** Keycloak has no local install path — it always runs in Docker. Step 4 has a Keycloak-only command that starts Keycloak **without** the `amcos-db` container, so it won't clash with your local PostgreSQL on port 5432.

### 3. Apply migrations + seed data (local install / Option B only)

**If you used Docker (Option A)** this already ran automatically via the `amcos-db-init` service in step 2 — **nothing to do here**. (To force a re-seed later: `docker compose run --rm amcos-db-init`, or run `docker compose exec amcos-db bash /amcos-sql/init.sh` for a plain re-run.)

**If you used a local install (Option B)** — Git Bash: `./AMCOS.PostgreSQL/init.sh` (add `--fresh` to drop & recreate first). Or, with no Git Bash, PowerShell:

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
  "seed\004_demo_users_and_project.sql","seed\005_amcos_lite_coverage.sql","seed\006_costfact_grades.sql"
)
foreach ($f in $files) { & $psql -U postgres -h localhost -d amcos -v ON_ERROR_STOP=1 -f "$root\$f" }
```

The seed scripts are **idempotent** (safe to re-run). They load representative lookups, AMCOS Lite filter + cost data (pay plans → categories → locations → grade crosstab), and two demo app users (`admin.demo`, `analyst.demo`). Details: `AMCOS.PostgreSQL/seed/README.md`.

### 4. Start Keycloak (OIDC login)

The app signs users in against a local Keycloak realm that runs in Docker (there is no local Keycloak install path).

- **If you used Docker for the database (Option A):** step 2's `docker compose up -d` already started Keycloak — **nothing to do**, skip to step 5.
- **If you used a local PostgreSQL install (Option B):** start **only** the Keycloak services. This pulls in `keycloak-db` and the `keycloak-config` importer via `depends_on`, but does **not** start the `amcos-db` container — so there is no conflict with your local PostgreSQL on port 5432:

  ```powershell
  cd D:\OLD-TCO
  docker compose up -d keycloak
  ```

Either way, Keycloak is available at `http://localhost:8180/auth` with the **`cave`** realm (`keycloak/cave-realm.json`) imported — client `amcos-local` and two login users (password **`Password1!`** for both):

| Username | Realm role |
|---|---|
| `admin.user` | `amcos-admin` |
| `test.user` | `amcos-user` |

- Admin console: `http://localhost:8180/auth/admin` (`admin` / `admin`).
- The realm is re-imported with `--override=true` on every `up`, so editing `keycloak/cave-realm.json` and re-running `docker compose up -d` applies the change with no volume reset. (Un-exported changes made by hand in the admin console are overwritten on the next `up`.)
- Stop with `docker compose down` (add `-v` to also wipe both databases).

### 5. Run the web app

```powershell
cd D:\OLD-TCO\AMCOS.Web.Core
dotnet run
```

Open **`http://localhost:5050`**, click **Login**, and sign in as `admin.user` / `Password1!` (admin menu) or `test.user` / `Password1!` (standard user). To exercise AMCOS Lite, open **Applications → AMCOS Lite** and pick a pay plan such as *Active Enlisted (AE)*.

### Troubleshooting

| Symptom | Cause / fix |
|---|---|
| Keycloak **"Client not found"** at login — even in Development | A stray `OpenIdConnect__ClientId` (or `__Authority`) **environment variable** is overriding `appsettings.Development.json` (env vars win over the config file). Clear it and use a fresh shell: `Remove-Item Env:OpenIdConnect__ClientId,Env:OpenIdConnect__Authority,Env:OpenIdConnect__ClientSecret -ErrorAction SilentlyContinue`. Also clear any persistent ones: `[Environment]::SetEnvironmentVariable('OpenIdConnect__ClientId',$null,'User')`. In Development you should set **none** of these — the config file supplies them. Confirm with `Get-ChildItem env: \| ? Name -like 'OpenIdConnect__*'` (should be empty). |
| `No connection could be made ... localhost:8180` or `IDX20803: Unable to obtain configuration` | Keycloak isn't running. Start it with `docker compose up -d` (Docker DB, Option A) or `docker compose up -d keycloak` (local PostgreSQL, Option B), then retry. |
| `Bind for 0.0.0.0:5432 failed: port is already allocated` | You're on Option B (local PostgreSQL already on 5432) but started the **full** stack, which also runs `amcos-db`. Start only Keycloak instead: `docker compose up -d keycloak`. |
| `extension "postgis" is not available` | The PostGIS Bundle wasn't installed. Re-run EDB **Stack Builder**, add the PostGIS bundle, then re-run the migrations. |
| `password authentication failed for user "postgres"` | Local `postgres` password isn't `postgr3s` — change it to match or update `ConnectionStrings`. |
| Empty AMCOS Lite filters | Seed step 3 didn't run (or ran before migrations). On Docker, `docker compose run --rm amcos-db-init`; on a local install, re-run step 3. |
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

> **Config precedence (important):** these settings resolve in order `appsettings.json` → `appsettings.{Environment}.json` → **environment variables** → command line, where later wins. So an environment variable **overrides** `appsettings.Development.json` even when running as Development. If you set `OpenIdConnect__ClientId` once (e.g. while testing a non-Development run) and leave it set, it will keep overriding the local dev client and produce a Keycloak **"Client not found"**. For local Development, set **none** of these variables and let `appsettings.Development.json` supply them.

#### Using a `.env` file instead of setting variables individually

Rather than exporting each variable, drop a **`.env`** file next to the app (`AMCOS.Web.Core/.env`) with `KEY=VALUE` lines — `Program.cs` loads it on startup. Copy the committed template to get started:

```powershell
cd D:\OLD-TCO\AMCOS.Web.Core
Copy-Item .env.example .env    # then edit values as needed
dotnet run
```

- Keys use the same `__` convention (e.g. `OpenIdConnect__ClientId=amcos-local`). See [`.env.example`](AMCOS.Web.Core/.env.example) for the full list.
- The loader is **fill-if-missing**: a variable already set in the shell/OS takes precedence over the `.env` file, and the file is ignored if it doesn't exist.
- `.env` is **git-ignored** (it may hold secrets); only `.env.example` is committed.
- **For local Development you don't need a `.env` at all** — `appsettings.Development.json` already points at the local Docker Keycloak and Postgres. Use `.env` for staging/production-style runs where you'd otherwise export the variables by hand.

> This app `.env` (`AMCOS.Web.Core/.env`) and the Docker Compose `.env` (below) are **separate files** read by different tools from different folders — they don't collide.

### Configuring the Docker stack (Compose `.env`)

The container settings in `docker-compose.yml` (image tags, DB names/users/passwords, the host ports for Postgres `5432` and Keycloak `8180`, and the Keycloak admin login) are all parameterized as `${VAR:-default}`. The defaults reproduce the values documented above, so **`docker compose up` needs no `.env`**. To override any of them (e.g. a port already in use), copy the template at the repo root and edit it:

```powershell
cd D:\OLD-TCO
Copy-Item .env.example .env    # Compose auto-reads ./.env; edit the values you want to change
docker compose up -d
```

- See [`.env.example`](.env.example) for every overridable variable.
- `KEYCLOAK_HTTP_PORT` sets both the published port **and** the token-issuer port together; if you change it, also update the app's `OpenIdConnect__Authority` and the redirect URIs in `keycloak/cave-realm.json`.
- Like the app `.env`, the root `.env` is git-ignored; only `.env.example` is committed.

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
