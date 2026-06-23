using System.Security.Claims;
using AMCOS.Data;
using Microsoft.AspNetCore.Authentication.Cookies;
using Microsoft.AspNetCore.Authentication.OpenIdConnect;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.FileProviders;
using Microsoft.IdentityModel.Protocols.OpenIdConnect;

var builder = WebApplication.CreateBuilder(args);
var configuration = builder.Configuration;

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
        options.CallbackPath = "/signin-oidc";
        options.SignedOutCallbackPath = "/signout-callback-oidc";
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

                    var idToken = context.TokenEndpointResponse?.IdToken;
                    if (!string.IsNullOrWhiteSpace(idToken) && !identity.HasClaim(claim => claim.Type == "id_token"))
                    {
                        identity.AddClaim(new Claim("id_token", idToken));
                    }
                }

                return Task.CompletedTask;
            },
            OnRemoteFailure = context =>
            {
                context.HandleResponse();
                context.Response.Redirect("/Error");
                return Task.CompletedTask;
            },
            OnRedirectToIdentityProviderForSignOut = context =>
            {
                var idTokenHint = context.HttpContext.User.FindFirst("id_token")?.Value;
                if (!string.IsNullOrWhiteSpace(idTokenHint))
                {
                    context.ProtocolMessage.IdTokenHint = idTokenHint;
                }

                return Task.CompletedTask;
            }
        };
    });

builder.Services.AddAuthorization();
builder.Services.AddRazorPages();
builder.Services.AddControllers();

var app = builder.Build();

if (!app.Environment.IsDevelopment())
{
    app.UseExceptionHandler("/Error");
    app.UseHsts();
}

app.UseHttpsRedirection();

var legacyDistPath = Path.GetFullPath(Path.Combine(app.Environment.ContentRootPath, "..", "AMCOS.Web", "dist"));
if (Directory.Exists(legacyDistPath))
{
    app.UseStaticFiles(new StaticFileOptions
    {
        FileProvider = new PhysicalFileProvider(legacyDistPath),
        RequestPath = "/dist"
    });
}

app.UseStaticFiles();
app.UseRouting();
app.UseSession();
app.UseAuthentication();
app.UseAuthorization();

app.MapControllers();
app.MapRazorPages();

app.Run();
