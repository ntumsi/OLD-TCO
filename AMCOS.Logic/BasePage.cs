using AMCOS.Data.Entities;
using System;
using System.Web;
using System.Web.Mvc;
using AMCOS.Logic.Helpers;

namespace AMCOS.Logic
{
    public class BasePage : System.Web.UI.Page
    {
        public AMCOSUser currentUser;
        protected override void OnPreInit(EventArgs e)
        {
            if (!HttpContext.Current.User.Identity.IsAuthenticated)
            {

                // Set the HTTP status code to 401 Unauthorized
                HttpContext.Current.Response.StatusCode = 401;
                HttpContext.Current.Response.StatusDescription = "Unauthorized";

                // End the request. The middleware will now intercept the 401 status 
                // and handle the redirect to the login provider.
                HttpContext.Current.ApplicationInstance.CompleteRequest();
                return; // Stop processing further
            }
            else
            {
                currentUser = UserAdministration.GetCurrentUser((System.Security.Claims.ClaimsIdentity)HttpContext.Current.User.Identity);

                if (currentUser != null)
                {
                    if (currentUser.UserRole == "Admin")
                    {
                        this.MasterPageFile = "~/SiteAdmin.master";
                    }
                    else
                    {
                        this.MasterPageFile = "~/SiteUser.master";
                    }
                }
                else
                {
                    // This case indicates the user is authenticated (e.g., has a cookie)
                    // but their record is not found in your application's database.
                    // A 403 Forbidden is often more appropriate here than a 401.
                    HttpContext.Current.Response.StatusCode = 403;
                    HttpContext.Current.Response.StatusDescription = "Forbidden: User not found in application";
                    HttpContext.Current.ApplicationInstance.CompleteRequest();
                    return; // Stop processing further
                }

            }
            base.OnPreInit(e);
        }
        protected void Page_PreLoad(object sender, EventArgs e)
        {
            if (!HttpContext.Current.User.Identity.IsAuthenticated)
            {
                // Set the HTTP status code to 401 Unauthorized
                HttpContext.Current.Response.StatusCode = 401;
                HttpContext.Current.Response.StatusDescription = "Unauthorized";

                // End the request. The middleware will now intercept the 401 status 
                // and handle the redirect to the login provider.
                HttpContext.Current.ApplicationInstance.CompleteRequest();
                return; // Stop processing further
            }
            currentUser = UserAdministration.GetCurrentUser((System.Security.Claims.ClaimsIdentity)HttpContext.Current.User.Identity);
        }
        public void SendAlertScript(string scriptName, string message)
        {
            string strScript = "<script language=JavaScript> alert('" + message + "'); </script>";
            if (!ClientScript.IsClientScriptBlockRegistered(GetType(), scriptName))
            {
                ClientScript.RegisterStartupScript(GetType(), scriptName, strScript);
            }
        }

        public void InsertScript(string scriptName, string script)
        {
            if (!ClientScript.IsClientScriptBlockRegistered(GetType(), scriptName))
            {
                ClientScript.RegisterStartupScript(GetType(), scriptName, script);
            }
        }
    }
}
