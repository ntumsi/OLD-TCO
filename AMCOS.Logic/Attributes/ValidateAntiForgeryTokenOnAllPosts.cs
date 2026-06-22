using System;
using System.Collections.Generic;
using System.Linq;
using System.Net;
using System.Text;
using System.Threading.Tasks;
using System.Web.Helpers;
using System.Web.Mvc;

namespace AMCOS.Logic.Attributes
{
    [AttributeUsage(AttributeTargets.Class)]
    public class ValidateAntiForgeryTokenOnAllPosts : AuthorizeAttribute
    {
        public override void OnAuthorization(AuthorizationContext filterContext)
        {
            var request = filterContext.HttpContext.Request;

            if (request.HttpMethod == WebRequestMethods.Http.Post)
            {
                if(request.IsAjaxRequest())
                {
                    var tokens = request.Headers["AntiForgeryToken"]?.Split(':');
                    if (tokens != null && tokens.Length == 2)
                        AntiForgery.Validate(tokens[0].Trim(), tokens[1].Trim());                    
                    else
                        AntiForgery.Validate("", "");
                }
                else
                {
                    base.OnAuthorization(filterContext);
                }
            }
            
        }
    }
}
