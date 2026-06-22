using System;
using System.Configuration;
using System.Net;
using System.Web.Helpers;
using System.Web.Mvc;
using System.Web.Routing;
using AMCOS.Data.Entities;
using AMCOS.Logic.Attributes;
using AMCOS.Logic.Helpers;
using AMCOS.Logic.ViewModels;
using Newtonsoft.Json;
using System.Security.Claims;
using System.Linq;
using System.Web;
using Microsoft.Owin.Security.Cookies;

namespace AMCOS.Logic.Controllers
{
    [ValidateAntiForgeryTokenOnAllPosts]
    [Authorize]
    public class BaseController : Controller
    {
        public AMCOSUser CurrentUser { get; set; }
        private class JsonNetResult : JsonResult
        {
            /// <summary>
            /// Use this class convert C# objects to a Json string and to escape HTML and format DateTime correctly
            /// </summary>
            /// <param name="data"></param>
            public JsonNetResult(object data)
            {
                Data = data;
            }

            public override void ExecuteResult(ControllerContext context)
            {
                if (Data != null)
                {
                    var settings = new JsonSerializerSettings() { StringEscapeHandling = StringEscapeHandling.EscapeHtml, DateFormatString = "yyyy'-'MM'-'dd' 'HH':'mm':'ss" };
                    context.HttpContext.Response.Write(JsonConvert.SerializeObject(Data, settings));
                }
            }
        }
        protected JsonResult JsonNet(object data)
        {
            var baseJson = data as BaseJson;

            if (baseJson != null)
            {
                var owinContext = HttpContext.GetOwinContext();

                // 1. Read the current authentication ticket
                var result = owinContext.Authentication
                    .AuthenticateAsync(CookieAuthenticationDefaults.AuthenticationType)
                    .GetAwaiter()
                    .GetResult();

                // Ensure we have a valid identity and properties
                if (result != null && result.Identity != null && result.Properties?.ExpiresUtc != null && result.Properties?.IssuedUtc != null)
                {
                    DateTimeOffset currentUtc = DateTimeOffset.UtcNow;
                    DateTimeOffset expiresUtc = result.Properties.ExpiresUtc.Value;
                    DateTimeOffset issuedUtc = result.Properties.IssuedUtc.Value;

                    // Calculate the session's total intended lifespan (e.g., 10 or 15 mins based on your admin logic)
                    TimeSpan totalDuration = expiresUtc - issuedUtc;

                    TimeSpan timeElapsed = currentUtc - issuedUtc;
                    TimeSpan timeRemaining = expiresUtc - currentUtc;

                    // 2. Are we past the halfway mark? (Standard sliding logic)
                    if (timeRemaining < timeElapsed)
                    {
                        // FORCE RE-ISSUE: Update properties to start from "right now"
                        result.Properties.IssuedUtc = currentUtc;
                        result.Properties.ExpiresUtc = currentUtc.Add(totalDuration);

                        // EXPLICITLY sign the user in again. 
                        // This bypasses the OWIN pipeline bug and forces the Set-Cookie header!
                        owinContext.Authentication.SignIn(result.Properties, result.Identity);

                        // Give the front-end the fully replenished timeout
                        baseJson.AuthenticationTimeout = (int)totalDuration.TotalSeconds;
                    }
                    else
                    {
                        // We haven't reached the halfway mark, so don't rewrite the cookie.
                        // Just return the current ticking remaining time.
                        if (timeRemaining.TotalSeconds < 0) timeRemaining = TimeSpan.Zero;
                        baseJson.AuthenticationTimeout = (int)Math.Floor(timeRemaining.TotalSeconds);
                    }
                }

                baseJson.AntiForgeryToken = SecurityHelper.GetAntiForgeryToken();
            }

            return new JsonNetResult(data);
        }


        /// <summary>
        /// Executes on every action to check if user session is active
        /// </summary>
        /// <param name="context"></param>        
        protected override void OnActionExecuting(ActionExecutingContext context)
        {
            base.OnActionExecuting(context);

            var identity = context.HttpContext.User.Identity as ClaimsIdentity;
            CurrentUser = UserAdministration.GetCurrentUser(identity);

            // This authorization logic for AdminOnly is still perfectly valid and necessary.
            if ((context.ActionDescriptor.GetCustomAttributes(typeof(AdminOnly), false).Length > 0 ||
                context.ActionDescriptor.ControllerDescriptor.GetCustomAttributes(typeof(AdminOnly), false).Length > 0)
                && CurrentUser.UserRole != "Admin")
            {
                context.Result = new HttpUnauthorizedResult("User attempted access to restricted area.");
            }
           
            if (context.HttpContext.Request.HttpMethod == WebRequestMethods.Http.Get)
            {
               
                ViewBag.AntiForgeryToken = SecurityHelper.GetAntiForgeryToken();
            }

        }

    }
}
