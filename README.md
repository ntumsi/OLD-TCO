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

Run the PostgreSQL migrations in order from `AMCOS.PostgreSQL/migrations/`:

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

> **Note:** `006_functions.sql` and `008_views.sql` are currently placeholders. Non-web functions and views from the legacy SQL Server database project (`AMCOS.AMCOS2020_MAR`) still need to be migrated.

Load seed data after running migrations. See `AMCOS.PostgreSQL/seed/README.md` for instructions.

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
- **Blocker:** `AMCOS.PostgreSQL/seed/` contains no seed data scripts — lookup and reference data must be exported from the legacy SQL Server database and loaded before the app will function correctly.
- **Blocker:** `AMCOS.Web/dist/` is not committed — the legacy frontend build artifacts must be generated (`npm install && npx gulp default` in `AMCOS.Web/`) and included in the deployment package.
- **Blocker:** Xwalk, Civilian PCS, and Admin modules are placeholder pages — full feature implementation is required.
- **Post-launch:** Session storage **and authentication tickets** use the in-memory `IDistributedCache` (`AddDistributedMemoryCache`). The OIDC auth cookie is kept small by storing the (token-heavy) ticket server-side via `DistributedCacheTicketStore`. In-memory means sessions/logins do **not** survive an app restart and are **not** shared across nodes — swap for a Redis-backed `IDistributedCache` before any multi-node deployment.
- **Post-launch:** ETL pipeline has no retry/backoff logic or transaction rollback for partial failures.
- **Post-launch:** ETL test coverage covers only 2 of 40+ loader modules.

See `AMCOS.Web.Core/MIGRATION_NOTES.md` for the full WebForms → ASP.NET Core migration notes.
