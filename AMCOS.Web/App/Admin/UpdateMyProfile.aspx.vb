Imports AMCOS.Data
Imports AMCOS.Logic

Partial Class UpdateMyProfile
    Inherits BasePage

    Protected Sub UpdateMyProfile_Load(sender As Object, e As System.EventArgs) Handles Me.Load

        If IsPostBack Then
            lblUpdatedMsg.Visible = False
            lblPhoneMsg.Visible = False
            Exit Sub
        End If

        lblFirstName.Text = currentUser.FirstName
        lblFirstName.Text = currentUser.FirstName
        lblLastName.Text = currentUser.LastName
        txtEmail.Text = currentUser.Email
        lblArmyAcctType.Text = currentUser.ArmyAccountType
        PopulateArmyRankGrade(currentUser.ArmyRank)

        'Me.btnDelete.Visible = (AkoId = "gary.j.wu" Or AkoId = "david.dengler")

        LoadMacomList()

        Dim lItem As ListItem = macomList.Items.FindByValue(currentUser.MACOM)
        If Not lItem Is Nothing Then lItem.Selected = True

        Me.OfficeName.Text = currentUser.OfficeName

        If ddlRankGrade.SelectedValue.EndsWith("CTR") Then
            pnlCompanyName.Visible = True
            CompanyName.Text = currentUser.CompanyName
        Else
            pnlCompanyName.Visible = False
        End If

        CommercialPhoneNumber.Text = currentUser.ComPhone
        InternationalPhoneNumber.Text = currentUser.InternationalNo

        lItem = ddlPrefix.Items.FindByValue(currentUser.Prefix)
        If Not lItem Is Nothing Then lItem.Selected = True
    End Sub

    Protected Sub btnUpdate_Click(sender As Object, e As System.EventArgs) Handles btnUpdate.Click
        If CommercialPhoneNumber.Text.Trim() = "" And InternationalPhoneNumber.Text.Trim() = "" Then
            lblPhoneMsg.Visible = True
            Exit Sub
        End If

        currentUser.MACOM = macomList.SelectedValue

        If OfficeName.Text.Trim() <> "" Then
            currentUser.OfficeName = OfficeName.Text.Trim()
        Else
            currentUser.OfficeName = Nothing
        End If

        If pnlCompanyName.Visible = True Then
            If 1 = 1 Then
                currentUser.CompanyName = CompanyName.Text.Trim()
            Else
                currentUser.CompanyName = Nothing
            End If
        Else
            currentUser.CompanyName = Nothing
        End If


        If CommercialPhoneNumber.Text.Trim() <> "" Then
            currentUser.ComPhone = CommercialPhoneNumber.Text.Trim()
        Else
            currentUser.ComPhone = Nothing
        End If

        If InternationalPhoneNumber.Text.Trim() <> "" Then
            currentUser.InternationalNo = InternationalPhoneNumber.Text.Trim()
        Else
            currentUser.InternationalNo = Nothing
        End If


        currentUser.Email = txtEmail.Text.Trim()
        currentUser.Prefix = ddlPrefix.SelectedValue
        currentUser.LastUpdate = DateTime.Now

        If ddlRankGrade.SelectedValue = "Other (Specify)" Then
            currentUser.ArmyRank = txtRankGrade.Text.Trim
        Else
            currentUser.ArmyRank = ddlRankGrade.SelectedValue
        End If

        UserAdministration.UpdateAmcosUser(currentUser)
        lblUpdatedMsg.Visible = True
    End Sub

    Protected Sub btnDelete_Click(sender As Object, e As System.EventArgs) Handles btnDelete.Click
        'TODO:  refactor
        Dim sql As String = "delete from webuser.PMReport where UserId=@uid;" _
+ "delete from webuser.PMCategorySkillInventory where UserId=@uid;" _
+ "delete from webuser.PMCategorySkill where UserId=@uid;" _
+ "delete from webuser.PMCategory where UserId=@uid;" _
+ "delete from webuser.PMUserSummaryElement where UserId=@uid;" _
+ "delete from webuser.PMUserSummary where UserId=@uid;" _
+ "delete from webuser.PMProject where UserId=@uid;" _
+ "delete from webuser.User_Login_History where UserId=@uid;" _
+ "delete from webuser.AMCOSUser where UserId=@uid"
        DataAccessUtility.GetScalarByStaticSql(sql, {"@uid"}, {currentUser.UserId})
        Me.litCloseWindow.Text = "<script type='text/javascript'> window.close(); </script>"
    End Sub

    Protected Sub PopulateArmyRankGrade(sRank As String)

        Dim saRankGrade As String()
        If lblArmyAcctType.Text = "MILITARY" Then
            saRankGrade = ",E1,E2,E3,E4,E5,E6,E7,E8,E9,O1,O2,O3,O4,O5,O6,O7,O8,O9,O10,W1,W2,W3,W4,W5,Other (Specify)".Split(",".ToCharArray)
        Else ' CIVILIAN
            saRankGrade = ",GS1,GS2,GS3,GS4,GS5,GS6,GS7,GS8,GS9,GS10,GS11,GS12,GS13,GS14,GS15,WG1,WG2,WG3,WG4,WG5,WG6,WG7,WG8,WG9,WG10,WG11,WG12,WG13,WG14,WG15,WL1,WL2,WL3,WL4,WL5,WL6,WL7,WL8,WL9,WL10,WL11,WL12,WL13,WL14,WL15,WS1,WS2,WS3,WS4,WS5,WS6,WS7,WS8,WS9,WS10,WS11,WS12,WS13,WS14,WS15,WS16,WS17,WS18,WS19,SES,Other (Specify)".Split(",".ToCharArray)
        End If

        ddlRankGrade.Items.Clear()
        WebControlUtil.PopulateDropDownList(ddlRankGrade, saRankGrade, sRank)

        If ddlRankGrade.SelectedValue = "" Then
            ddlRankGrade.SelectedValue = "Other (Specify)"
        End If

        If ddlRankGrade.SelectedValue = "Other (Specify)" Then
            txtRankGrade.Text = sRank
            txtRankGrade.Visible = True
        Else
            txtRankGrade.Visible = False
        End If
    End Sub

    Protected Sub ddlSponsorRankGrade_SelectedIndexChanged(sender As Object, e As System.EventArgs) Handles ddlRankGrade.SelectedIndexChanged
        txtRankGrade.Visible = (ddlRankGrade.SelectedValue = "Other (Specify)")
    End Sub

    Private Sub LoadMacomList()

        macomList.Items.Clear()
        macomList.DataSource = UserAdministration.GetOrganizations.ToList()
        macomList.DataBind()
        macomList.Items.Insert(0, New ListItem("(Select)", ""))

    End Sub
End Class
