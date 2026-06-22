Imports AMCOS.Logic.Helpers

Public Class SiteUser
    Inherits System.Web.UI.MasterPage
    Public Property ExportDataEmailBody As String = My.Resources.CustomDataExportEmail
    Public Property AntiforgeryToken As String = SecurityHelper.GetAntiForgeryToken()
    Protected Sub Page_Load(ByVal sender As Object, ByVal e As System.EventArgs) Handles Me.Load

    End Sub

End Class