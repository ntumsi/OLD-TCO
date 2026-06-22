using Microsoft.Owin.Security;
using Microsoft.Owin.Security.Cookies;
using Microsoft.Owin.Security.OpenIdConnect;
using System;
using System.Collections.Generic;
using System.Configuration;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using System.Web;
using System.Web.Mvc;

namespace AMCOS.Logic.Controllers
{
    [Route("Account/{action}")]
    public class AccountController : Controller
    {

        public void Login(string returnUrl) // MVC model binding captures the "?ReturnUrl=..." parameter
        {
            // If the returnUrl is empty for any reason, default to the home page.
            var redirectUri = string.IsNullOrEmpty(returnUrl) ? "/" : returnUrl;

            // THIS IS THE KEY: We store the user's desired final destination
            // in the AuthenticationProperties. This gets passed through the OIDC flow.
            HttpContext.GetOwinContext().Authentication.Challenge(
                new AuthenticationProperties { RedirectUri = redirectUri },
                OpenIdConnectAuthenticationDefaults.AuthenticationType);
        }

        [Route("Logout")]
        public async Task<ActionResult> Logout()
        {
            var owinContext = HttpContext.GetOwinContext();

            // 1. Attempt to read the user's session
            var authResult = await owinContext.Authentication.AuthenticateAsync(CookieAuthenticationDefaults.AuthenticationType);

            // 2. Extract the id_token
            string idToken = authResult?.Identity?.FindFirst("id_token")?.Value;

            // 3. Force-expire the main application cookies via System.Web (Zombie fix)
            if (System.Web.HttpContext.Current != null)
            {
                var response = System.Web.HttpContext.Current.Response;
                foreach (string cookieName in System.Web.HttpContext.Current.Request.Cookies.AllKeys)
                {
                    if (cookieName.StartsWith(".AspNet.Cookies"))
                    {
                        response.Cookies.Add(new System.Web.HttpCookie(cookieName)
                        {
                            Expires = DateTime.Now.AddDays(-1)
                        });
                    }
                }
            }

            // 4. Conditional Logout Logic
            if (!string.IsNullOrEmpty(idToken))
            {
                // SCENARIO A: The session is alive.
                // We have the token. Perform a full OIDC logout to Keycloak.
                var signoutProperties = new AuthenticationProperties();
                signoutProperties.Dictionary.Add("id_token_hint", idToken);

                owinContext.Authentication.SignOut(signoutProperties,
                    CookieAuthenticationDefaults.AuthenticationType,
                    OpenIdConnectAuthenticationDefaults.AuthenticationType);

                // Return empty result; OWIN will intercept this and do the Keycloak redirect.
                return new EmptyResult();
            }
            else
            {
                // SCENARIO B: The session is already expired.
                // We do NOT have the token. If we send this to Keycloak, it will crash.
                // Instead, just clear the local cookie and redirect them manually.
                owinContext.Authentication.SignOut(CookieAuthenticationDefaults.AuthenticationType);

                // Redirect them to your PostLogout URL defined in your config (or fallback to Home)
                string postLogoutUrl = ConfigurationManager.AppSettings["CaveUrl"] ?? "~/";
                return Redirect(postLogoutUrl);
            }
        }
    }


}
