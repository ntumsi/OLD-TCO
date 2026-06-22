
Partial Class SessionOver
    Inherits System.Web.UI.Page
    Protected Sub Page_Load(ByVal sender As Object, ByVal e As System.EventArgs) Handles Me.Load
        Session.Abandon()
        FormsAuthentication.SignOut()
        Response.Redirect(ResolveClientUrl(ConfigurationManager.AppSettings("CaveUrl")))
    End Sub

End Class
