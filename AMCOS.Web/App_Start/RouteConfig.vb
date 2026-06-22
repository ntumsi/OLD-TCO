Imports System.Web.Mvc
Imports System.Web.Routing

Public Module RouteConfig
    Public Sub RegisterRoutes(ByVal routes As RouteCollection)

        routes.IgnoreRoute("{resource}.axd/{*pathInfo}")
        routes.IgnoreRoute("{resource}.aspx/{*pathInfo}")
        routes.IgnoreRoute("signin-oidc")

        routes.MapMvcAttributeRoutes()
        routes.MapRoute(
            name:="Default",
            url:="{controller}/{action}/{id}",
            defaults:=New With {Key .controller = "Home", .action = "Index", .id = UrlParameter.Optional}
            )

    End Sub
End Module
