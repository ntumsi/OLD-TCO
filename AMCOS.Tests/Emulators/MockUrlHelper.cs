using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using System.Web.Mvc;
using System.Web.Routing;

namespace AMCOS.Tests.Emulators
{
    /// <summary>
    /// Add overrides as needed
    /// </summary>
    public class MockUrlHelper : UrlHelper
    {
        public MockUrlHelper() : base()
        {

        }
        public MockUrlHelper(RequestContext requestContext) : base(requestContext)
        {

        }
        public MockUrlHelper(RequestContext requestContext, RouteCollection routeCollection) : base(requestContext, routeCollection)
        {

        }        
        public override string Content(string contentPath)
        {
            return $"http://localhost/amcos{contentPath.Replace("~", "")}";
        }
    }
}
