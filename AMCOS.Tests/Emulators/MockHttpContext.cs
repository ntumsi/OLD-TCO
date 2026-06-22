using System;
using System.Collections;
using System.Collections.Generic;
using System.Collections.Specialized;
using System.Security.Principal;
using System.Web;
using System.Web.Routing;
using System.Security.Claims;
using System.Security.Principal;
using System.Web;
using System.Web.Routing;

namespace AMCOS.Tests
{
    /// <summary>
    /// emulates a controllers HttpContextBase
    /// </summary>
    public class MockHttpContext : HttpContextBase
    {
        public override HttpRequestBase Request { get; }
        public override IPrincipal User { get; set; }
        public override HttpSessionStateBase Session { get; } = new MockSession();
        public override HttpResponseBase Response { get; } = new MockHttpResponse();
        public override HttpServerUtilityBase Server { get; } = new MockServerUtility();
        public override IDictionary Items { get; } = new Hashtable();
        /// <summary>
        /// emulates a controllers HttpContextBase with as a contractor
        /// </summary>
        public MockHttpContext() : this("CONTRACTOR", "CTR", "test.dummy.ctr@mail.mil", "Testuser")
        {

        }
        /// <summary>
        /// emulates a controllers HttpContextBase
        /// </summary>
        public MockHttpContext(string accountType, string rank, string email, string userName, string userRole = null) : this(accountType, rank, email, userName, userRole, new RouteData())
        {
             
        }
        public MockHttpContext(string accountType, string rank, string email, string userName, string userRole, RouteData routeData)
        {
            var owinEnvironment = new Dictionary<string, object>
            {
                // You can add Owin/Authentication elements here if your AuthenticateAsync mock needs specific values.
            };
            Items["owin.Environment"] = owinEnvironment;
            // 1. Create a list of claims from the input parameters.
            var claims = new List<Claim>
            {
                new Claim(ClaimTypes.Name, userName),
                new Claim(ClaimTypes.NameIdentifier, Guid.NewGuid().ToString()), // Often used for User ID
                new Claim(ClaimTypes.Email, email),
                new Claim(ClaimTypes.GivenName, "Test"),
                new Claim(ClaimTypes.Surname, "User"),                
                new Claim("accountType", accountType ?? ""),
                new Claim(ClaimTypes.Role, userRole == "Admin" ? "Admin" : "")
            };

            // 2. Create a ClaimsIdentity with a non-null authentication type.
            //    This is required for 'IsAuthenticated' to be true.
            var identity = new ClaimsIdentity(claims, "TestAuth");

            // 3. Create a ClaimsPrincipal and assign it to the User property.
            User = new ClaimsPrincipal(identity);
            Request = new MockHttpRequest(accountType, rank, email, userName, this, routeData);
        }
        
        private class MockSession : HttpSessionStateBase
        {
            private Dictionary<string, object> _values = new Dictionary<string, object>();
            public override object this[string name]
            {
                get
                {
                    return _values[name];
                }
                set
                {
                    _values[name] = value;
                }
            }
            public override void Add(string name, object value)
            {
                _values.Add(name, value);
            }
            public override void Clear()
            {
                _values.Clear();
            }
            public override void Abandon()
            {
                //Do nothing.
            }
        }
        public class MockHttpResponse : HttpResponseBase
        {
            public MockHttpResponse() : base()
            {

            }
            public override void Write(string str)
            {
                //do nothing
            }
            public override HttpCookieCollection Cookies => new HttpCookieCollection();
        }
        public class MockServerUtility : HttpServerUtilityBase
        {
            public override string MapPath(string path)
            {
                return $"{Environment.CurrentDirectory.Replace("AMCOS.Tests\\bin\\Debug","").Replace("AMCOS.Tests\\bin\\Release","")}AMCOS.Web{path.Replace("~","").Replace("/", "\\")}";
            }
           
        }
        public class MockHttpRequest : HttpRequestBase
        {
            private RequestContext _request;
            private NameValueCollection _serverVariables;

            public MockHttpRequest(string accountType, string rank, string email, string userName, HttpContextBase context, RouteData routeData)
            {
                _serverVariables = new NameValueCollection()
                {
                    { "HTTP_CN", userName },
                    { "HTTP_ARMYEDIPI", userName },
                    { "HTTP_ARMYEEMAIL", email },
                    { "HTTP_GIVENNAME", "Test" },
                    { "HTTP_SN", "User" },
                    { "HTTP_ARMYRANK", rank },
                    { "HTTP_ARMYACCOUNTTYPE", accountType },
                    { "ReturnURL", "~/home" }
                };
                RequestContext = new RequestContext(context, routeData);
                RequestType = "Get";
            }
            public override HttpBrowserCapabilitiesBase Browser { get; } = new MockBrowser();
            public override NameValueCollection ServerVariables => _serverVariables;
            public override string Path => "~/home";
            public override NameValueCollection QueryString => _serverVariables;
            public override System.Uri Url { get; } = new System.Uri("http://test.calibresys.com");
            private class MockBrowser : HttpBrowserCapabilitiesBase
            {
                public override string Version => "1.0";
                public override string Type => "Explorer";
            }
            public void CreateRequest(HttpContextBase context, RouteData routeData)
            {
                RequestContext = new RequestContext(context, routeData);
            }
            public override RequestContext RequestContext { get; set; } = new RequestContext();
            public override string RequestType { get; set; } = "GET";
            public override string HttpMethod => "GET";
            public override void ValidateInput()
            {
                //TODO: Create a mock method for validating input during unit tests
            }
            public override HttpCookieCollection Cookies => new HttpCookieCollection();
            public override string UserAgent => "";

        }

        private class PrincipleUser : IPrincipal
        {
            public IIdentity Identity { get; }
            private string _role;
            public PrincipleUser(string name, string role)
            {
                Identity = new User(name, "");
                _role = role;
            }

            public bool IsInRole(string role)
            {
                return role == _role;
            }
            private class User : IIdentity
            {
                public User(string name, string authenticationType)
                {
                    Name = name;
                    AuthenticationType = authenticationType;
                }
                public string Name { get; }

                public string AuthenticationType { get; }

                public bool IsAuthenticated => true;
            }
        }

    }
}
