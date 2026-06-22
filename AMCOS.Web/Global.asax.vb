Imports System.Data.Entity.SqlServer
Imports System.Net
Imports System.Security.Claims
Imports System.Web.Helpers
Imports System.Web.Http
Imports System.Web.Mvc
Imports System.Web.Optimization
Imports System.Web.Routing
Imports System.Web.SessionState
Imports System.Web.WebPages
Imports Microsoft.SqlServer.Types


Public Class Global_asax
    Inherits System.Web.HttpApplication


    Sub Application_Start(ByVal sender As Object, ByVal e As EventArgs)
        ' Fires when the application is started
        ServicePointManager.SecurityProtocol = SecurityProtocolType.Tls12
        ' Tell the Anti-Forgery system to use the "sub" claim from the OIDC token
        ' as the user's unique identifier.
        AntiForgeryConfig.UniqueClaimTypeIdentifier = ClaimTypes.NameIdentifier
        GlobalConfiguration.Configure(AddressOf WebApiConfig.Register)
        RegisterRoutes(RouteTable.Routes)
        BundleConfig.RegisterBundles(BundleTable.Bundles)
        MvcHandler.DisableMvcResponseHeader = True
        WebPageHttpHandler.DisableWebPagesResponseHeader = True
        AddHandler PreSendRequestHeaders, AddressOf Application_PreSendRequestHeaders
        SqlProviderServices.SqlServerTypesAssemblyName = GetType(SqlGeography).Assembly.FullName
        SqlServerTypes.Utilities.LoadNativeAssemblies(Server.MapPath("~/bin"))
    End Sub

    Sub Session_Start(ByVal sender As Object, ByVal e As EventArgs)
        ' Fires when the session is started
    End Sub

    Sub Application_BeginRequest(ByVal sender As Object, ByVal e As EventArgs)
        ' Fires at the beginning of each request
    End Sub

    Sub Application_AuthenticateRequest(ByVal sender As Object, ByVal e As EventArgs)
        ' Fires upon attempting to authenticate the use
    End Sub

    Sub Application_Error(ByVal sender As Object, ByVal e As EventArgs)
        ' Fires when an error occurs
    End Sub

    Sub Session_End(ByVal sender As Object, ByVal e As EventArgs)
        ' Fires when the session ends
    End Sub

    Sub Application_End(ByVal sender As Object, ByVal e As EventArgs)
        ' Fires when the application ends
    End Sub
    Sub Application_PreSendRequestHeaders(ByVal sender As Object, ByVal e As EventArgs)
        HttpContext.Current.Response.Headers.Remove("Server")
        HttpContext.Current.Response.Headers.Remove("X-AspNetWebPages-Version")
        HttpContext.Current.Response.Headers.Remove("X-AspNet-Version")
        HttpContext.Current.Response.Headers.Remove("X-AspNetMvc-Version")
    End Sub

End Class