Imports Microsoft.Owin
Imports Owin
Imports AMCOS.Logic.Helpers ' <-- Reference your C# project

' This attribute is now in your main project, so it will always be found.
<Assembly: OwinStartup(GetType(Startup))>
Public Class Startup
    Public Sub Configuration(app As IAppBuilder)
        ' Explicitly create an instance of your C# helper
        ' and call its configuration method.
        Dim keycloakHelper = New KeyCloakHelper()
        keycloakHelper.Configuration(app)
    End Sub
End Class

