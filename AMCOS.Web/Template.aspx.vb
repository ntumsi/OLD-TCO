Imports System.Web.Management

Public Class Template
    Inherits System.Web.UI.Page

    Protected Sub Page_Load(ByVal sender As Object, ByVal e As System.EventArgs) Handles Me.Load
        Label0.Text = "AMCOS Administrator (" + ConfigurationManager.AppSettings("Environment") + ")," + vbCrLf

        Dim info As MailEventNotificationInfo = TemplatedMailWebEventProvider.CurrentNotification
        EventList.DataSource = info.Events
        EventList.DataBind()
    End Sub

End Class