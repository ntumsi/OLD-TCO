
Imports AMCOS.Logic

Partial Class AdminLog
    Inherits BasePage

    Protected Sub AdminLog_Load(sender As Object, e As System.EventArgs) Handles Me.Load
        Helpers.AdminHelper.ThrowExceptionIfNotAdmin(currentUser.UserRole)
    End Sub
End Class
