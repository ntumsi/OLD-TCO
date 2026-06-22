using System;
using System.Configuration;
using System.Web.Helpers;
using System.Collections.Specialized;
namespace AMCOS.Logic.Helpers
{
    public static class SecurityHelper
    {
        
        /// <summary>
        /// Returns a new cookietoken and formtoken as an antiforgy token string for CSRF protection
        /// </summary>
        /// <returns></returns>
        public static string GetAntiForgeryToken()
        {
            var newCookieToken = string.Empty;
            var formToken = string.Empty;
            if (ConfigurationManager.AppSettings["Environment"] != "UnitTest")
            {
                AntiForgery.GetTokens(null, out newCookieToken, out formToken);                
            }
            else
            {
                //This is a unit test
                newCookieToken = Guid.NewGuid().ToString();
                formToken = Guid.NewGuid().ToString();
            }
            return string.Format("{0}:{1}", newCookieToken, formToken);
        }

        public static string GetKeyCloakPassword()
        {
            // Get the custom configuration section.
            var secureSettings = ConfigurationManager.GetSection("secureAppSettings") as NameValueCollection;

            if (secureSettings != null)
            {
                // Retrieve the value by its key.
                return secureSettings["KeyCloakClientSecret"];
            }

            return null; // Or throw an exception if the key is required.
        }

        //        public static ICredentials GetCredentials(out string email, HttpRequestBase Request, string userId)
        //        {
        //            switch (ConfigurationManager.AppSettings["Environment"])
        //            {
        //                case "Development":
        //                case "InternalTest":
        //                    email = ConfigurationManager.AppSettings["InternalTester_Email"];                    
        //#if DevUseCAC

        //                    //Break the clientCertificate subject string into list of strings and find the value associated with CN
        //                    Request.ClientCertificate?.Subject?.Split(',').ToList().ForEach(s =>
        //                    {
        //                        var val = s.Split('=');
        //                        if (val.Count() > 1 && val[0].Trim().ToUpper() == "CN")
        //                            userId = val[1].Trim();
        //                    });
        //#endif
        //                    return new LoginCredentials(
        //                            userId,
        //                            userId,
        //                            ConfigurationManager.AppSettings["InternalTester_GIVENNAME"],
        //                            ConfigurationManager.AppSettings["InternalTester_SN"],
        //                            ConfigurationManager.AppSettings["InternalTester_Department"],
        //                            ConfigurationManager.AppSettings["InternalTester_ARMYACCOUNTTYPE"],
        //                            ConfigurationManager.AppSettings["InternalTester_Email"]
        //                            );
        //                default:
        //                    email = Request.ServerVariables["HTTP_ARMYEEMAIL"];
        //                    return new LoginCredentials(
        //                             Request.ServerVariables["HTTP_CN"],
        //                             Request.ServerVariables["HTTP_ARMYEDIPI"],
        //                             Request.ServerVariables["HTTP_GIVENNAME"],
        //                             Request.ServerVariables["HTTP_SN"],
        //                             Request.ServerVariables["HTTP_ARMYRANK"],
        //                             Request.ServerVariables["HTTP_ARMYACCOUNTTYPE"],
        //                             Request.ServerVariables["HTTP_ARMYEEMAIL"]
        //                             );
        //            }
        //        }        
    }
}
