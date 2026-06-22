using Microsoft.Owin;
using Microsoft.Owin.Infrastructure;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace AMCOS.Logic.Helpers
{
    public class SameSiteCookieHelper : ICookieManager
    {
        private readonly ICookieManager _innerManager;

        public SameSiteCookieHelper(ICookieManager innerManager)
        {
            _innerManager = innerManager;
        }

        public SameSiteMode SameSite { get; set; } = SameSiteMode.Lax;

        public string GetRequestCookie(IOwinContext context, string key)
        {
            return _innerManager.GetRequestCookie(context, key);
        }

        public void AppendResponseCookie(IOwinContext context, string key, string value, CookieOptions options)
        {
            CheckSameSite(context, options);
            _innerManager.AppendResponseCookie(context, key, value, options);
        }

        public void DeleteCookie(IOwinContext context, string key, CookieOptions options)
        {
            CheckSameSite(context, options);
            _innerManager.DeleteCookie(context, key, options);
        }

        private void CheckSameSite(IOwinContext context, CookieOptions options)
        {
            if (options.SameSite == null)
            {
                options.SameSite = SameSite;
            }

            if (options.SameSite == SameSiteMode.None && context.Request.IsSecure)
            {
                options.Secure = true;
            }
        }
    }
}
