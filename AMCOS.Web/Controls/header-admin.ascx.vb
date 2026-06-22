Imports AMCOS.Logic
Imports AMCOS.Data.Entities
Imports AMCOS.Logic.Helpers

Public Class header_admin
    Inherits System.Web.UI.UserControl

    Protected Sub Page_Load(ByVal sender As Object, ByVal e As System.EventArgs) Handles Me.Load
        Dim email As String = ""
        Dim amcosUser = UserAdministration.GetCurrentUser(CType(HttpContext.Current.User.Identity, Security.Claims.ClaimsIdentity))

        If amcosUser.UserRole = "Admin" Then
            Dim nPendingUsers As Integer = CType(DataAccessUtility.GetScalarByStaticSql("select web.GetPendingUserCount()"), Integer)
            Select Case nPendingUsers
                Case 0
                    lnkPendingAdmin.Visible = False
                Case 1
                    lnkPendingAdmin.Text = "There is one AMCOS user account pending!"
                Case Else
                    lnkPendingAdmin.Text = String.Format("There are {0} AMCOS user accounts pending!", nPendingUsers)
            End Select
        Else
            lnkPendingAdmin.Visible = False
        End If

    End Sub

    Private Sub lnkPendingAdmin_Click(sender As Object, e As EventArgs) Handles lnkPendingAdmin.Click
        Response.Redirect(ResolveClientUrl("~/App/Admin/AdminApproval.aspx"))
    End Sub
End Class