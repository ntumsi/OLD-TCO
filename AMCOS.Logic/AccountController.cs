using Microsoft.Owin.Security;
using Microsoft.Owin.Security.Cookies;
using Microsoft.Owin.Security.OpenIdConnect;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using System.Web;
using System.Web.Mvc;

namespace AMCOS.Logic.Controllers
{
    public class AccountController : Controller
    {
        // This action will be our new login entry point.
        public void Login()
        {
            // This is the code you were missing.
            // It tells the OWIN pipeline to start the OpenID Connect authentication flow.
            // It will build the correct redirect to Keycloak using the settings
            // from your Startup.cs.
            HttpContext.GetOwinContext().Authentication.Challenge(
                new AuthenticationProperties { RedirectUri = "/" }, // Redirect to home page after successful login
                OpenIdConnectAuthenticationDefaults.AuthenticationType);
        }

        //TODO: make this the official logout.
        public void Logout()
        {
            HttpContext.GetOwinContext().Authentication.SignOut(
                CookieAuthenticationDefaults.AuthenticationType,
                OpenIdConnectAuthenticationDefaults.AuthenticationType);
        }
    }
}
