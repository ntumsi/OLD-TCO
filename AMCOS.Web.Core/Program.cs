using System.Security.Claims;
using AMCOS.Data;
using AMCOS.Web.Core.Authentication;
using Microsoft.AspNetCore.Authentication;
using Microsoft.AspNetCore.Authentication.Cookies;
using Microsoft.AspNetCore.Authentication.OpenIdConnect;
using Microsoft.AspNetCore.Mvc.RazorPages;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.FileProviders;
using Microsoft.Extensions.Options;
using Microsoft.IdentityModel.Protocols.OpenIdConnect;

// Load a local .env file (KEY=VALUE lines) into environment variables when one is present, so a
// new/deployed environment can supply every required setting from a single file instead of
// exporting each variable on the command line. Values use the ASP.NET double-underscore
// convention for nested keys, e.g. OpenIdConnect__ClientId=amcos-local. Already-set environment
// variables win (fill-if-missing), and everything then feeds the normal configuration via the
// default AddEnvironmentVariables() below.
// NOTE: In Development you normally need NO .env and NO env vars at all — appsettings.Development.json
// already provides these. Do not leave stray OpenIdConnect__* variables set, or they will override
// appsettings.Development.json and can cause a Keycloak "Client not found".
LoadDotEnv();

var builder = WebApplication.CreateBuilder(args);
var configuration = builder.Configuration;

// Npgsql 6+ requires UTC DateTimes for timestamptz; legacy mode accepts Local/Unspecified
// (matching SQL Server's timezone-unaware DateTime behaviour in the original codebase).
AppContext.SetSwitch("Npgsql.EnableLegacyTimestampBehavior", true);

// Fail fast in non-Development environments if required secrets are missing.
if (!builder.Environment.IsDevelopment())
{
    var authority = configuration["OpenIdConnect:Authority"];
    var clientId = configuration["OpenIdConnect:ClientId"];
    var clientSecret = configuration["OpenIdConnect:ClientSecret"];
    if (string.IsNullOrWhiteSpace(authority) || string.IsNullOrWhiteSpace(clientId) || string.IsNullOrWhiteSpace(clientSecret))
    {
        throw new InvalidOperationException(
            "OpenIdConnect:Authority, OpenIdConnect:ClientId, and OpenIdConnect:ClientSecret must all be set " +
            "via environment variables (OpenIdConnect__Authority, etc.) before running in a non-Development environment.");
    }

    var connString = configuration.GetConnectionString("AmcosPostgres")
        ?? configuration.GetConnectionString("AmcosEF")
        ?? configuration.GetConnectionString("AmcosAdo");
    if (string.IsNullOrWhiteSpace(connString))
    {
        throw new InvalidOperationException(
            "A database connection string (ConnectionStrings__AmcosPostgres, ConnectionStrings__AmcosEF, or " +
            "ConnectionStrings__AmcosAdo) must be set via environment variable before running in a non-Development environment.");
    }

    if (string.IsNullOrWhiteSpace(configuration["AllowedHosts"]))
    {
        throw new InvalidOperationException(
            "AllowedHosts must be set to one or more hostnames (e.g. amcos.example.com) via " +
            "the AllowedHosts environment variable before running in a non-Development environment.");
    }

    if (string.IsNullOrWhiteSpace(configuration["CaveUrl"]) || string.IsNullOrWhiteSpace(configuration["AmcosUrl"]))
    {
        throw new InvalidOperationException(
            "CaveUrl and AmcosUrl must be set via environment variables before running in a non-Development environment.");
    }
}

var postgresConnection = configuration.GetConnectionString("AmcosPostgres")
    ?? configuration.GetConnectionString("AmcosEF")
    ?? configuration.GetConnectionString("AmcosAdo")
    ?? string.Empty;

builder.Services.AddDbContext<ApplicationDbContext>(options => options.UseNpgsql(postgresConnection));
builder.Services.AddDistributedMemoryCache();
builder.Services.AddSession(options =>
{
    options.IdleTimeout = TimeSpan.FromMinutes(20);
    options.Cookie.HttpOnly = true;
    options.Cookie.IsEssential = true;
    options.Cookie.SameSite = SameSiteMode.Lax;
});

// Keep the auth cookie small by storing the (token-heavy) ticket server-side in the distributed
// cache rather than serializing it into the cookie. See DistributedCacheTicketStore for why.
builder.Services.AddSingleton<ITicketStore, DistributedCacheTicketStore>();
builder.Services.AddSingleton<IPostConfigureOptions<CookieAuthenticationOptions>, ConfigureCookieTicketStore>();

builder.Services
    .AddAuthentication(options =>
    {
        options.DefaultScheme = CookieAuthenticationDefaults.AuthenticationScheme;
        options.DefaultChallengeScheme = OpenIdConnectDefaults.AuthenticationScheme;
    })
    .AddCookie(options =>
    {
        options.LoginPath = "/account/login";
        options.LogoutPath = "/account/logout";
        options.SlidingExpiration = true;
        options.ExpireTimeSpan = TimeSpan.FromMinutes(15);
    })
    .AddOpenIdConnect(options =>
    {
        options.SignInScheme = CookieAuthenticationDefaults.AuthenticationScheme;
        options.Authority = configuration["OpenIdConnect:Authority"] ?? string.Empty;
        options.ClientId = configuration["OpenIdConnect:ClientId"] ?? string.Empty;
        options.ClientSecret = configuration["OpenIdConnect:ClientSecret"] ?? string.Empty;
        options.ResponseType = OpenIdConnectResponseType.Code;
        options.SaveTokens = true;
        options.GetClaimsFromUserInfoEndpoint = true;
        options.Scope.Clear();
        options.Scope.Add("openid");
        options.Scope.Add("profile");
        options.Scope.Add("email");
        options.RequireHttpsMetadata = !builder.Environment.IsDevelopment();
        options.CallbackPath = "/signin-oidc";
        options.SignedOutCallbackPath = "/signout-callback-oidc";

        // SameSite=None without Secure is rejected by modern browsers on plain HTTP.
        // Lax allows these cookies to travel on the top-level redirect back from Keycloak.
        options.CorrelationCookie.SameSite = SameSiteMode.Lax;
        options.NonceCookie.SameSite = SameSiteMode.Lax;

        options.Events = new OpenIdConnectEvents
        {
            OnTokenValidated = context =>
            {
                if (context.Principal?.Identity is ClaimsIdentity identity)
                {
                    var adminClaim = identity.Claims.FirstOrDefault(claim =>
                        claim.Type == ClaimTypes.Role
                        || claim.Type == "role"
                        || claim.Type == "roles"
                        || claim.Type == "groups");

                    if (adminClaim?.Value?.Contains("amcos-admin", StringComparison.OrdinalIgnoreCase) == true
                        && !identity.HasClaim(ClaimTypes.Role, "Admin"))
                    {
                        identity.AddClaim(new Claim(ClaimTypes.Role, "Admin"));
                    }
                }

                return Task.CompletedTask;
            },
            OnRemoteFailure = context =>
            {
                context.HandleResponse();
                var msg = Uri.EscapeDataString(context.Failure?.Message ?? "OIDC authentication failed");
                context.Response.Redirect($"/Error?msg={msg}");
                return Task.CompletedTask;
            },
            OnRedirectToIdentityProviderForSignOut = async context =>
            {
                var idTokenHint = await context.HttpContext.GetTokenAsync("id_token");
                if (!string.IsNullOrWhiteSpace(idTokenHint))
                {
                    context.ProtocolMessage.IdTokenHint = idTokenHint;
                }
            }
        };
    });

builder.Services.AddAntiforgery(o => o.HeaderName = "RequestVerificationToken");
builder.Services.AddAuthorization();
builder.Services.AddRazorPages();
builder.Services.AddControllers();

var app = builder.Build();

if (!app.Environment.IsDevelopment())
{
    app.UseExceptionHandler("/Error");
    app.UseHsts();
    app.UseHttpsRedirection();
}

// Serve the Core project's own wwwroot first so its assets (e.g. /dist/js/pcs-civilian.js) take
// precedence. The legacy AMCOS.Web/dist folder is registered afterwards as a *fallback* only — it
// supplies assets that have not yet been migrated into Core's wwwroot. Registering it first (as it
// was) shadowed Core's updated copies with the stale legacy versions.
app.UseStaticFiles();

var legacyDistPath = Path.GetFullPath(Path.Combine(app.Environment.ContentRootPath, "..", "AMCOS.Web", "dist"));
if (Directory.Exists(legacyDistPath))
{
    app.UseStaticFiles(new StaticFileOptions
    {
        FileProvider = new PhysicalFileProvider(legacyDistPath),
        RequestPath = "/dist"
    });
}

// Serve the legacy public documents (release notes, tutorials, fact sheets) referenced by the
// migrated pages (e.g. the home page's "AMCOS Release/Update History" PDF) at /Public.
var legacyPublicPath = Path.GetFullPath(Path.Combine(app.Environment.ContentRootPath, "..", "AMCOS.Web", "Public"));
if (Directory.Exists(legacyPublicPath))
{
    app.UseStaticFiles(new StaticFileOptions
    {
        FileProvider = new PhysicalFileProvider(legacyPublicPath),
        RequestPath = "/Public"
    });
}

app.UseRouting();

// Clean up orphaned auth-cookie chunks left over from the pre-ticket-store cookie format.
// A genuinely chunked cookie has a base value of "chunks-N"; with the server-side ticket store
// the base auth cookie is never chunked, so any ".AspNetCore.CookiesCn" seen alongside a
// non-chunked (or dropped) base cookie is stale. Left in place, ~8 KB of stale chunks re-inflate
// the Cookie header past the request-header size limit, causing the real (small) auth cookie to
// be dropped and the user to be logged out on every request — an unrecoverable login loop.
// Expiring the orphans lets the browser self-heal on the next request.
app.Use(async (context, next) =>
{
    var cookies = context.Request.Cookies;
    if (cookies.ContainsKey(".AspNetCore.CookiesC1"))
    {
        var baseIsChunked = cookies.TryGetValue(".AspNetCore.Cookies", out var baseVal)
            && baseVal.StartsWith("chunks-", StringComparison.Ordinal);
        if (!baseIsChunked)
        {
            for (var i = 1; cookies.ContainsKey($".AspNetCore.CookiesC{i}"); i++)
            {
                context.Response.Cookies.Delete($".AspNetCore.CookiesC{i}");
            }
        }
    }
    await next();
});

app.UseSession();
app.UseAuthentication();
app.UseAuthorization();

app.MapControllers();
app.MapRazorPages();

// Startup diagnostic: log the EFFECTIVE OIDC configuration (after all sources — appsettings,
// appsettings.Development.json, environment variables, .env — are merged) so an override coming
// from a stray env var or .env is immediately visible in the console. A wrong/empty ClientSecret
// makes Keycloak's token exchange fail with "unauthorized_client"; a wrong/empty ClientId yields
// "Client not found". The secret VALUE is never logged — only whether it is present.
app.Logger.LogInformation(
    "OIDC effective config -> Environment={Environment}, Authority={Authority}, ClientId={ClientId}, ClientSecret={ClientSecret}",
    app.Environment.EnvironmentName,
    string.IsNullOrWhiteSpace(configuration["OpenIdConnect:Authority"]) ? "(EMPTY)" : configuration["OpenIdConnect:Authority"],
    string.IsNullOrWhiteSpace(configuration["OpenIdConnect:ClientId"]) ? "(EMPTY)" : configuration["OpenIdConnect:ClientId"],
    string.IsNullOrWhiteSpace(configuration["OpenIdConnect:ClientSecret"]) ? "(EMPTY!)" : "set");

app.Run();

// Minimal .env loader (no external dependency). Reads the first .env found in the current working
// directory or the app base directory; parses simple KEY=VALUE lines (supports # comments, blank
// lines, and optional surrounding quotes). Existing environment variables are never overwritten.
static void LoadDotEnv()
{
    foreach (var dir in new[] { Directory.GetCurrentDirectory(), AppContext.BaseDirectory })
    {
        var path = Path.Combine(dir, ".env");
        if (!File.Exists(path))
        {
            continue;
        }

        foreach (var raw in File.ReadAllLines(path))
        {
            var line = raw.Trim();
            if (line.Length == 0 || line.StartsWith('#'))
            {
                continue;
            }

            var idx = line.IndexOf('=');
            if (idx <= 0)
            {
                continue;
            }

            var key = line[..idx].Trim();
            var value = line[(idx + 1)..].Trim().Trim('"');
            if (string.IsNullOrEmpty(Environment.GetEnvironmentVariable(key)))
            {
                Environment.SetEnvironmentVariable(key, value);
            }
        }

        return; // first .env found wins
    }
}
