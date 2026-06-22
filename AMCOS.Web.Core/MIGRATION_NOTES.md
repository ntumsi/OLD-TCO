# AMCOS WebForms to ASP.NET Core 8 migration notes

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

1. Re-point legacy JavaScript AJAX calls from `LiteService.asmx/LogChoices` and `ProjectService.asmx/LogAddUnit` to `/api/lite/LogChoices` and `/api/project/LogAddUnit`.
2. Port the remaining client-side behavior from `amcos-lite.js` and `project-manager.js` if exact UX parity is required.
3. Recreate the full WebForms report formatting logic from `report.aspx.vb` if subtotal rows, CCE salary-limit highlighting, expandable discounted views, and multi-grid parity are required.
4. Complete the Xwalk, Civilian PCS, and Admin modules beyond the placeholder pages added here.
5. Review production OpenID Connect metadata, callback URLs, cookie hardening, and distributed cache implementation before go-live.
6. Align `AMCOS.Data.AppConfiguration` on a final Core connection string key. The new `appsettings.json` includes `AmcosPostgres` for current shared-library compatibility alongside `AmcosEF` and `AmcosAdo`.
7. Review Web.config-only settings not yet surfaced in `appsettings.json` (QuickSight dashboard IDs, email settings, feature flags, banner settings, and internal tester values).

## Known compatibility choices

- The Core app intentionally favors buildable scaffolding and direct reuse of `AMCOS.Logic` / `AMCOS.Data` over pixel-perfect UI parity.
- Razor Pages handlers now return JSON tables for AMCOS Lite instead of WebForms postback-bound `GridView` controls.
- Project Manager report export currently focuses on data preservation across worksheets instead of reproducing every legacy formatting rule.
