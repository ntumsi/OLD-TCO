Imports System
Imports System.Web.Http
Public Module WebApiConfig
    Public Sub Register(ByVal config As HttpConfiguration)
        ' Web API configuration and services

        'Attribute Routing
        config.MapHttpAttributeRoutes()

        'Convention-based routing
        'config.Routes.MapHttpRoute(
        '    name:="Api",
        '    routeTemplate:="api/{controller}/{id}",
        '    defaults:=New With {.id = RouteParameter.Optional}
        ')

    End Sub
End Module
