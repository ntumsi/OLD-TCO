# AMCOS WebForms to ASP.NET Core 8 migration notes

> **Status (2026-07-09):** the follow-up items below were the state *at the start* of the migration. Most are now complete — the Xwalk, Civilian PCS, and all Admin pages are fully implemented (not placeholders), the AJAX endpoints were re-pointed, and the Report formatting was rebuilt. See `MIGRATION_PARITY_AUDIT.md` and `PROJECT_MANAGER_GAPS.md` for the authoritative, verified state; the per-item notes below have been annotated with ✅/⚠️ to match.

## Page and service mapping

| Legacy asset | New ASP.NET Core 8 asset | Notes |
| --- | --- | --- |
| `about.aspx` | `Pages/About.cshtml` | Static module overview ported to Razor Pages. |
| `Global.asax.vb` | `Program.cs` | Startup, middleware, static file hosting, auth, routing and session replacement now live in Core bootstrapping. |
| `Web.config` | `appsettings.json` + `Program.cs` | Core config keeps connection strings, OpenID Connect settings, and high-value app settings. |
| `App_Start/Startup.vb` | `Program.cs` | OWIN cookie/OpenID Connect middleware mapped to ASP.NET Core authentication middleware. |
| `App/Lite/default.aspx` | `Pages/App/Lite/Index.cshtml` | Core page includes a Razor Pages JSON handler that calls `AMCOS.Logic.Lite`. |
| `App/Lite/LiteService.asmx.vb` | `Controllers/LiteApiController.cs` | `LogChoices` preserved as GET/POST at `/api/lite/LogChoices`. |
| `App/Project/default.aspx` | `Pages/App/Project/Index.cshtml` | Core page lists projects and supports create/copy/delete operations. |
| `App/Project/report.aspx` | `Pages/App/Project/Report.cshtml` | Core page loads report data and exports an Excel workbook through Aspose.Cells. |
| `App/Project/ProjectService.asmx.vb` | `Controllers/ProjectApiController.cs` | `LogAddUnit` preserved as GET/POST at `/api/project/LogAddUnit`. |

## Authentication and startup

- OWIN `UseCookieAuthentication` + `UseOpenIdConnectAuthentication` were replaced with `AddAuthentication().AddCookie().AddOpenIdConnect()`.
- Role promotion for `amcos-admin` now occurs in the Core OpenID Connect token validated event.
- Login/logout moved to `Controllers/AccountController.cs`.
- `UseAuthentication()` and `UseAuthorization()` are part of the Core middleware pipeline.

## Session and state

- Legacy SQL-backed ASPState was replaced with `AddDistributedMemoryCache()` + `AddSession()`.
- If production parity requires shared session state across nodes, swap the in-memory cache for Redis-backed `IDistributedCache`.

## Static files

- The new layout references `~/dist/` to preserve the legacy asset convention.
- `Program.cs` maps `/dist` to the sibling `../AMCOS.Web/dist` directory when it exists.
- Manual follow-up: copy or re-publish the legacy built `dist/` assets into the Core deployment artifact. The repository currently does not contain `AMCOS.Web/dist`, so deployment packaging still needs attention.

## Excel export

- `Pages/App/Project/Report.cshtml.cs` keeps Aspose.Cells for workbook export.
- The license file is copied into `AMCOS.Web.Core/Licenses/Aspose.Cells.lic` and marked for output copying.

## Manual follow-up items

1. ✅ **Done.** Legacy JavaScript AJAX calls re-pointed to `/api/lite/LogChoices` and `/api/project/LogAddUnit`.
2. ✅ **Done.** `amcos-lite.js` and `project-manager.js` were repurposed as the native cascade engines and wired into the Lite and Project Details pages (see `PROJECT_MANAGER_GAPS.md` GAP 1/2).
3. ✅ **Done.** Report formatting rebuilt — subtotal rows, CCE salary-limit highlighting, expandable discounted views, per-appropriation colouring (`Pages/Shared/_CostReportTable.cshtml`). Final visual fidelity still needs real `crunch.*` cost data.
4. ✅ **Done.** Xwalk, Civilian PCS, and all Admin pages are fully implemented (no longer placeholders). Xwalk/Admin dashboards are real QuickSight embeds gated on AWS config.
5. ⚠️ **Partly done / pre-go-live.** OIDC fail-fast checks, HSTS/HTTPS redirect, and a server-side auth-ticket store are in place; still to do before a multi-node deploy: swap the in-memory `IDistributedCache` for Redis and review production callback URLs/cookie hardening.
6. ✅ **Done.** The app resolves the connection string in the order `AmcosPostgres` → `AmcosEF` → `AmcosAdo` (`Program.cs`); `AmcosPostgres` is the primary key.
7. ⚠️ **Open.** Web.config-only settings (QuickSight dashboard IDs, email/SMTP, feature flags, banner settings, internal-tester values) still need to be supplied in the target environment's config.

## Known compatibility choices

- The Core app intentionally favors buildable scaffolding and direct reuse of `AMCOS.Logic` / `AMCOS.Data` over pixel-perfect UI parity.
- Razor Pages handlers now return JSON tables for AMCOS Lite instead of WebForms postback-bound `GridView` controls.
- Project Manager report export currently focuses on data preservation across worksheets instead of reproducing every legacy formatting rule.
