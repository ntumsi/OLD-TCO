using System;
using System.Threading.Tasks;
using System.Web;
using System.Web.Mvc;
using Microsoft.Owin.Security.OpenIdConnect;
namespace AMCOS.Logic.Controllers
{
    // This controller does NOT inherit from BaseController and does NOT have [Authorize]
    public class AuthenticationController : Controller
    {
        /// <summary>
        /// This does not actually get used but is needed to prompt owin to load the correct libraries at runtime
        /// </summary>
        [AllowAnonymous] // Explicitly allow anonymous access
        [HttpPost]
        [Route("oidc-callback")]
        public async Task<ActionResult> OidcCallback()
        {
            var authContext = HttpContext.GetOwinContext().Authentication;
            var authResult = await authContext.AuthenticateAsync(OpenIdConnectAuthenticationDefaults.AuthenticationType);
            if (authResult == null || authResult.Identity == null)
            {
                throw new InvalidOperationException("Authentication failed.");
            }
            // --- SUCCESS PATH ---
            // This is the user's identity from the token.
            var identity = authResult.Identity;
            var properties = authResult.Properties;
            var redirectUri = properties.RedirectUri;
            // --- DYNAMIC EXPIRATION LOGIC ---
            // 1. Determine if the user is an admin. 
            // Check your specific role claim (adjust the claim type/value based on how Keycloak sends it)
            bool isAdmin = identity.HasClaim(System.Security.Claims.ClaimTypes.Role, "amcos-admin");
            // 2. Set the desired timeout based on the role
            int expirationMinutes = isAdmin ? 10 : 15; // Admins = 10 mins, Users = 15 mins
            // 3. Override the cookie properties
            var now = DateTimeOffset.UtcNow;
            properties.IssuedUtc = now;
            properties.ExpiresUtc = now.AddMinutes(expirationMinutes);
            properties.IsPersistent = false; // Usually false for strict session timeouts
            // --------------------------------
            // Now, sign the user in.
            // We pass the properties along so that features like "IsPersistent" are respected.
            authContext.SignIn(authResult.Properties, identity);
            // If the redirectUri is still null or empty, have a safe fallback to the home page.
            if (string.IsNullOrEmpty(redirectUri))
            {
                return RedirectToAction("Index", "Home");
            }
            // Redirect the user to their originally requested URL!
            return Redirect(redirectUri);
        }
    }
}

