using Owin;
using Microsoft.Owin.Security;
using Microsoft.Owin.Security.Cookies;
using Microsoft.Owin.Security.OpenIdConnect;
using System.Threading.Tasks;
using System.Configuration;
using System.Net.Http;
using System.Security.Claims;
using Microsoft.Owin;
using System.Collections.Generic;
using Microsoft.Owin.Host.SystemWeb;
using System;
using System.IdentityModel.Tokens.Jwt;
using System.Linq;
using Microsoft.IdentityModel.Protocols.OpenIdConnect;

namespace AMCOS.Logic.Helpers
{
    public class KeyCloakHelper
    {
        public void Configuration(IAppBuilder app)
        {
            if (ConfigurationManager.AppSettings["Environment"] == "Development")
            {
                MockConfiguration(app);
                return;
            }

            var handler = new HttpClientHandler();
            var backchannelClient = new HttpClient(handler);
            backchannelClient.DefaultRequestHeaders.UserAgent.ParseAdd("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/107.0.0.0 Safari/537.36");

            app.SetDefaultSignInAsAuthenticationType(CookieAuthenticationDefaults.AuthenticationType);

            app.UseCookieAuthentication(new CookieAuthenticationOptions
            {
                AuthenticationType = CookieAuthenticationDefaults.AuthenticationType,
                LoginPath = new PathString("/Account/Login"),
                AuthenticationMode = AuthenticationMode.Active,
                ExpireTimeSpan = TimeSpan.FromMinutes(10),
                SlidingExpiration = true,
                CookieSameSite = SameSiteMode.Strict,
                CookieManager = new SystemWebCookieManager(),
                Provider = new CookieAuthenticationProvider
                {
                    OnResponseSignIn = context =>
                    {
                        var identity = context.Identity;
                        var properties = context.Properties;

                        // 1. EXTRACT ROLES FROM ACCESS TOKEN
                        if (properties.Dictionary.TryGetValue("access_token", out string accessToken))
                        {
                            var jwthandler = new System.IdentityModel.Tokens.Jwt.JwtSecurityTokenHandler();
                            var jwt = jwthandler.ReadJwtToken(accessToken);
                            var rawGroupClaims = jwt.Claims.Where(c =>
                                c.Type == "groups" || c.Type == "roles" ||
                                c.Type == "realm_access" || c.Type == "resource_access");
                            foreach (var claim in rawGroupClaims)
                            {
                                identity.AddClaim(new Claim("keycloak_roles", claim.Value));
                            }
                        }

                        // 2. ASSIGN ADMIN ROLE
                        bool isAdmin = false;
                        if (identity.HasClaim(c =>
                            (c.Type == ClaimTypes.Role || c.Type == "role" || c.Type == "roles" || c.Type == "groups" || c.Type == "keycloak_roles")
                            && c.Value.Contains("amcos-admin")))
                        {
                            isAdmin = true;
                            if (!identity.HasClaim(ClaimTypes.Role, "Admin"))
                            {
                                identity.AddClaim(new Claim(ClaimTypes.Role, "Admin"));
                            }
                        }

                        // 3. EXTRACT ID_TOKEN FOR LOGOUT
                        if (properties.Dictionary.TryGetValue("id_token", out string idToken))
                        {
                            identity.AddClaim(new Claim("id_token", idToken));
                        }

                        // 4. THE MAGIC TRICK: DELETE MASSIVE TOKENS TO PREVENT COOKIE BLOAT
                        properties.Dictionary.Remove("access_token");
                        properties.Dictionary.Remove("id_token");
                        properties.Dictionary.Remove("refresh_token");
                        properties.Dictionary.Remove("expires_at");

                        // 5. SET DYNAMIC 10/15 MINUTE EXPIRATION
                        int expirationMinutes = isAdmin ? 10 : 15;
                        var now = DateTimeOffset.UtcNow;
                        properties.IssuedUtc = now;
                        properties.ExpiresUtc = now.AddMinutes(expirationMinutes);
                        properties.IsPersistent = false;
                    }
                }
            });

            // Configure OpenID Connect authentication
            app.UseOpenIdConnectAuthentication(new OpenIdConnectAuthenticationOptions
            {
                ClientId = ConfigurationManager.AppSettings["KeyCloakClientId"],
                ClientSecret = SecurityHelper.GetKeyCloakPassword(),
                Authority = ConfigurationManager.AppSettings["KeyCloakAuthority"],
                RedirectUri = ConfigurationManager.AppSettings["AmcosUrl"],
                PostLogoutRedirectUri = ConfigurationManager.AppSettings["CaveUrl"],
                ResponseType = "code id_token",
                Scope = "openid profile email",
                RedeemCode = true,

                // FIX: Turn this back ON so Katana downloads the access_token
                SaveTokens = true,

                AuthenticationMode = AuthenticationMode.Passive,
                SignInAsAuthenticationType = CookieAuthenticationDefaults.AuthenticationType,
                UseTokenLifetime = false,
                Backchannel = backchannelClient,
                CookieManager = new SystemWebCookieManager(),
                Notifications = new OpenIdConnectAuthenticationNotifications
                {
                    AuthenticationFailed = context =>
                    {
                        if (context.Exception.Message.Contains("Correlation failed"))
                        {
                            var cookieOptions = new CookieOptions { Expires = DateTime.Now.AddDays(-1) };
                            foreach (var cookie in context.Request.Cookies)
                            {
                                if (cookie.Key.StartsWith("OpenIdConnect.nonce.") || cookie.Key.StartsWith("OpenIdConnect.state."))
                                {
                                    context.Response.Cookies.Append(cookie.Key, string.Empty, cookieOptions);
                                }
                            }
                        }
                        context.Exception = new Exception("Authentication session has expired or is invalid.");
                        return Task.FromResult(0);
                    },

                    // Inject the id_token_hint into the logout request
                    RedirectToIdentityProvider = context =>
                    {
                        if (context.ProtocolMessage.RequestType == OpenIdConnectRequestType.Logout)
                        {
                            if (context.OwinContext.Authentication.AuthenticationResponseRevoke?.Properties?.Dictionary != null &&
                                context.OwinContext.Authentication.AuthenticationResponseRevoke.Properties.Dictionary.TryGetValue("id_token_hint", out string idTokenHint))
                            {
                                context.ProtocolMessage.IdTokenHint = idTokenHint;
                            }
                            context.ProtocolMessage.PostLogoutRedirectUri = context.Options.PostLogoutRedirectUri;
                        }
                        return Task.FromResult(0);
                    }
                }
            });
        }
        private void MockConfiguration(IAppBuilder app)
        {
            // ===================================================================
            // == DEVELOPMENT / MOCK AUTHENTICATION (Runs only in Development / UnitTest) ==
            // ===================================================================

            // When a user is not authenticated, redirect them to our fake login page.
            app.SetDefaultSignInAsAuthenticationType(CookieAuthenticationDefaults.AuthenticationType);
            app.UseCookieAuthentication(new CookieAuthenticationOptions
            {
                AuthenticationType = CookieAuthenticationDefaults.AuthenticationType,
                LoginPath = new PathString("/dev-login")
            });

            // This middleware creates our fake login page at "/dev-login"
            app.Use(async (context, next) =>
            {
                if (context.Request.Path.ToString() == "/dev-login")
                {
                    // --- Build a list of claims that mimics the real Keycloak token ---

                    var claims = new List<Claim>
                    {
                        // Standard OIDC Claims
                        new Claim(ClaimTypes.NameIdentifier, ConfigurationManager.AppSettings["InternalTester_NameIdentifier"]), // The "sub" (Subject) claim is the unique user ID
                        new Claim(ClaimTypes.Name, ConfigurationManager.AppSettings["InternalTester_Name"]),                        // The "name" claim
                        new Claim(ClaimTypes.GivenName, ConfigurationManager.AppSettings["InternalTester_GIVENNAME"]),                         // "given_name"
                        new Claim(ClaimTypes.Surname, ConfigurationManager.AppSettings["InternalTester_SN"]),                         // "family_name"
                        new Claim(ClaimTypes.Email, ConfigurationManager.AppSettings["InternalTester_Email"]),          // "email"
                        new Claim("preferred_username", ConfigurationManager.AppSettings["InternalTester_PreferredUserName"]),               // Custom claim for username

                        // Custom Claims from your token
                        new Claim("department", ConfigurationManager.AppSettings["InternalTester_Department"]),
                        new Claim("accountType", ConfigurationManager.AppSettings["InternalTester_ARMYACCOUNTTYPE"]),                       

                        // Add each role from the "realm_access.roles" array as a Role claim                        
                        new Claim(ClaimTypes.Role, ConfigurationManager.AppSettings["InternalTester_Role"])  
                    };

                    var identity = new ClaimsIdentity(claims, CookieAuthenticationDefaults.AuthenticationType);

                    var authManager = context.Authentication;
                    authManager.SignIn(new AuthenticationProperties { IsPersistent = true }, identity);

                    var redirectUrl = context.Request.Query["ReturnUrl"] ?? "/";
                    context.Response.Redirect(redirectUrl);
                }
                else
                {
                    await next.Invoke();
                }
            });
        }
        
    }
}
