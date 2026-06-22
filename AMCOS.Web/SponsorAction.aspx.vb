Imports System.Configuration.ConfigurationManager
Imports AMCOS.Data
Imports AMCOS.Data.Entities
Imports AMCOS.Logic

Partial Class SponsorAction
    Inherits BasePage

    Protected Sub App_SponsorAction_Load(sender As Object, e As System.EventArgs) Handles Me.Load
        If Not IsPostBack Then LoadPendingUsers()
    End Sub

    Protected Sub userList_RowCommand(sender As Object, e As CommandEventArgs) Handles UserList.RowCommand
        Dim saUserInfo As String() = e.CommandArgument.ToString.Split(",".ToCharArray)

        'TODO test this
        Dim oSponsor As AMCOSUser = currentUser
        Dim emailFrom As String = oSponsor.Email

        If e.CommandName = "Approve" Then
            DataAccessUtility.GetScalarByStaticSql("update webuser.AMCOSUser set UserStatus='PendingAdmin' where UserID=@uid", {"@uid"}, {saUserInfo(0)})

            ' Send Approval Email to admin
            Dim emailTo As String() = {AmcosAdminEmail}
            Dim emailSubject As String = "AMCOS Access Request - Sponsor Approved"
            Dim emailBody As String = "<p>Dear DASA-CE Representative,</p> <p>{0}'s application for access to the AMCOS was approved by sponsor and is now pending your action.</p> " &
                                    "<p>{1} <br />" &
                                    "<p>{2} <br />" &
                                    "<p>{3} <br />" &
                                    "<p>{4} <br />" &
                                    "<p>{5} </p>"
            emailBody = String.Format(emailBody, saUserInfo(1), oSponsor.FullName, oSponsor.Email, oSponsor.ComPhone, oSponsor.ArmyAccountType, oSponsor.Macom)
            ProcessEmail(emailFrom, emailTo, emailSubject, emailBody)

        ElseIf e.CommandName = "Deny" Then
            DataAccessUtility.GetScalarByStaticSql("update webuser.AMCOSUser set UserStatus='Denied' where UserID=@uid", {"@uid"}, {saUserInfo(0)})

            ' Email user for denial
            Dim emailTo As String() = {saUserInfo(2)}
            Dim emailSubject As String = "AMCOS Access Request - Sponsor Disapproved"
            Dim emailBody As String = "<p>Dear {0}, </p> <p>Your application for access to the AMCOS was disapproved by your sponsor.  Please contact your sponsor for further information.</p> " &
                                    "<p>{1} <br />" &
                                    "<p>{2} <br />" &
                                    "<p>{3} <br />" &
                                    "<p>{4} <br />" &
                                    "<p>{5} </p>"
            emailBody = String.Format(emailBody, saUserInfo(1), oSponsor.FullName, oSponsor.Email, oSponsor.ComPhone, oSponsor.ArmyAccountType, oSponsor.Macom)
            ProcessEmail(emailFrom, emailTo, emailSubject, emailBody)
        End If
        LoadPendingUsers()
    End Sub

    Private Sub ProcessEmail(ByVal emailFrom As String, ByVal emailTo As String(), ByVal emailSubject As String, ByVal emailBody As String)
        If AppSettings("Environment") = "Development" Then
            EmailFrom1Literal.Text = emailFrom
            EmailTo1Literal.Text = emailTo(0)
            EmailSubject1Literal.Text = emailSubject
            EmailBody1Literal.Text = emailBody

            EmailSentPanel.Visible = True
        Else
            SendEmail(emailFrom, emailTo, emailSubject, emailBody)
            EmailSentPanel.Visible = False
        End If
    End Sub

    Private Sub LoadPendingUsers()
        Dim dtUsers As DataTable = DataAccessUtility.GetDataTableByStaticSql("SELECT UserID + ',' + FirstName + ' ' + isnull(MiddleName + '', '') + LastName + ',' + Email as UserInfo, FirstName + ' ' + isnull(MiddleName + '', '') + LastName as fullName, Email, ComPhone, OfficeName, Macom, SelfAccountType, ArmyRank, CompanyName, LastLogin FROM  webuser.AMCOSUser where UserStatus='PendingSponsor' and SponsorUserID=@sid", {"@sid"}, {currentUser.UserId})
        UserList.DataSource = dtUsers
        UserList.DataBind()
    End Sub

End Class
