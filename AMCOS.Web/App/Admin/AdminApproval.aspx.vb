Imports System.Configuration.ConfigurationManager
Imports AMCOS.Logic

Partial Class AdminApproval
    Inherits BasePage

    Protected Sub App_AdminApproval_Load(sender As Object, e As System.EventArgs) Handles Me.Load
        Helpers.AdminHelper.ThrowExceptionIfNotAdmin(currentUser.UserRole)

        If Not IsPostBack Then
            LoadPendingUsers()
        End If
    End Sub

    Protected Sub UserList_RowCommand(sender As Object, e As System.Web.UI.WebControls.CommandEventArgs) Handles UserList.RowCommand
        Dim saUserInfo As String() = e.CommandArgument.ToString.Split(",".ToCharArray)
        Dim emailFrom As String = AmcosAdminEmail
        Dim emailTo As String() = {saUserInfo(2)}
        Dim sponsorEmail As String = Nothing

        Dim pendingUser = UserAdministration.GetUserById(saUserInfo(0))

        'If the pending user has a sponsor, and the sponsor has a valid email address, include it in the TO: field
        If Not (pendingUser.SponsorUserId Is Nothing) Then
            sponsorEmail = userAdministration.GetUserEmail(pendingUser.SponsorUserId)
            If Not (sponsorEmail Is Nothing) Then
                If sponsorEmail.IndexOf("@") > 0 Then
                    emailTo = {saUserInfo(2), sponsorEmail}
                End If
            End If
        End If

        If e.CommandName = "Approve" Then
            userAdministration.ApproveUser(saUserInfo(0))
            ' Email admin for approval:
            Dim emailSubject As String = "AMCOS Access Request Approved"
            Dim emailBody As String = "<p>Dear {0}, </p><p>Congratulations.  Your application for access to the AMCOS is approved.  You can now access the website, {1}.</p>" +
                        "<p>For your reference a User Access AMCOS Login Process document has been attached to this email.</p>" +
                        "<p>Thank you for using AMCOS.</p>" +
                        "<p>DASA-CE <br/> {2}</p>"
            emailBody = String.Format(emailBody, saUserInfo(1), AmcosUrl, AmcosAdminEmail)
            ProcessEmail(emailFrom, emailTo, emailSubject, emailBody, {Server.MapPath("~/Public/" + AmcosUserLoginGuideFile)})

        ElseIf e.CommandName = "Deny" Then
            userAdministration.DenyUser(saUserInfo(0))
            ' Email admin for denial:
            Dim emailSubject As String = "AMCOS Access Request Denied"
            Dim emailBody As String = "<p>Dear {0}, </p><p>Your application for access to the AMCOS has been denied.  For further information, please contact DASA-CE, at {1}. You may reapply for access when your issue has been resolved.</p>" +
                        "<p>Respectfully, <br/> DASA-CE</p>"
            emailBody = String.Format(emailBody, saUserInfo(1), AmcosAdminEmail)
            ProcessEmail(emailFrom, emailTo, emailSubject, emailBody)

        End If
        ' LoadPendingUsers()
        Response.Redirect(Request.RawUrl) ' this will reload the head user control to update pending users
    End Sub

    Private Sub ProcessEmail(ByVal emailFrom As String, ByVal emailTo As String(), ByVal emailSubject As String, ByVal emailBody As String, Optional emailAttachment As String() = Nothing)
        If AppSettings("Environment") = "Development" Then
            EmailFrom1Literal.Text = emailFrom
            EmailTo1Literal.Text = emailTo(0)
            EmailSubject1Literal.Text = emailSubject
            EmailBody1Literal.Text = emailBody

            EmailSentPanel.Visible = True
        Else
            SendEmail(emailFrom, emailTo, emailSubject, emailBody, emailAttachment)

            EmailSentPanel.Visible = False
        End If
    End Sub

    Private Sub LoadPendingUsers()
        UserList.DataSource = UserAdministration.GetPendingUsers()
        UserList.DataBind()
    End Sub

End Class
