Imports System.Drawing
Imports AMCOS.Data
Imports AMCOS.Logic
Imports Aspose.Cells

Partial Class UserList
    Inherits BasePage
    Public _hidDownloadClientID As String

    Protected Sub UserList_Load(sender As Object, e As System.EventArgs) Handles Me.Load
        Helpers.AdminHelper.ThrowExceptionIfNotAdmin(currentUser.UserRole)
        If Not IsPostBack Then
            LoadMacomList()
        End If
        _hidDownloadClientID = hidDownload.ClientID
    End Sub

    Protected Sub GridView1_RowDataBound(sender As Object, e As System.Web.UI.WebControls.GridViewRowEventArgs) Handles GridView1.RowDataBound, GridView2.RowDataBound
        Dim oRow As GridViewRow = e.Row
        If oRow.RowType = DataControlRowType.DataRow Then
            Dim dt As DateTime
            For i As Integer = 8 To 10
                If DateTime.TryParse(oRow.Cells(i).Text, dt) Then
                    oRow.Cells(i).Text = dt.ToString("s")
                End If
            Next
            If CType(sender, GridView).ID = "GridView1" Then
                Dim btnChange As Button = CType(oRow.Cells(12).FindControl("btnChangeRole"), Button)
                btnChange.Visible = (btnChange.CommandArgument.Length > 0)
            End If
        End If
    End Sub

    Protected Sub GridView1_Sorting(sender As Object, e As GridViewSortEventArgs) Handles GridView1.Sorting
        Dim dt As DataTable = CType(ViewState("dt"), DataTable)
        dt.DefaultView.Sort = e.SortExpression + " " + GetSortDirection(e.SortExpression)
        GridView1.DataSource = dt.DefaultView
        GridView1.DataBind()
        GridView2.DataSource = dt.DefaultView
        GridView2.DataBind()
    End Sub

    Protected Sub GridView1_RowCommand(sender As Object, e As CommandEventArgs) Handles GridView1.RowCommand

        If e.CommandName <> "ChangeRole" Then
            Exit Sub
        End If

        Dim userId As String = CType(e.CommandArgument, String)

        Dim selectedUser = UserAdministration.GetUserById(userId)
        If selectedUser.UserRole = "Admin" Then
            selectedUser.UserRole = "User"
        Else
            selectedUser.UserRole = "Admin"
        End If
        userAdministration.UpdateAmcosUser(selectedUser)

        Dim dt As DataTable = CType(ViewState("dt"), DataTable)
        dt = dt.Copy
        dt.Columns("Role").ReadOnly = False
        dt.Select("UserId='" + userId + "'")(0)("Role") = selectedUser.UserRole
        dt.AcceptChanges()

        GridView1.DataSource = dt.DefaultView
        GridView1.DataBind()
        GridView2.DataSource = dt.DefaultView
        GridView2.DataBind()
        ViewState("dt") = dt

        '-- Not sure this is needed any more
        'pnlExportContent.Visible = True

    End Sub

    Private Function GetSortDirection(column As String) As String
        Dim sortDirection As String = "ASC"
        If ViewState("SortExpression").ToString = column And ViewState("SortDirection").ToString = "ASC" Then sortDirection = "DESC"
        ' Save new values in ViewState.
        ViewState("SortDirection") = sortDirection
        ViewState("SortExpression") = column
        Return sortDirection
    End Function

    Protected Sub btnSearch_Click(sender As Object, e As System.EventArgs) Handles btnSearch.Click

        Dim sbP As New StringBuilder()
        Dim sbV As New StringBuilder()
        Dim sb As New StringBuilder("SELECT u.UserId,LTRIM(u.LastName) + ', ' + u.FirstName AS Name,u.AkoID,u.Email,u.ArmyRank,u.Macom,u.CompanyName,LTRIM(OfficeName) AS OfficeName,dbo.udfFormatPhoneNo(ComPhone) AS ComPhone,u.ArmyAccountType,u.DateCreated,u.LastUpdate,u.LastLogin,u.UserRole AS [Role],COUNT(h.loginDateTime) AS LoginCount FROM webuser.AMCOSUser u LEFT JOIN webuser.User_Login_History h ON u.UserId = h.UserId WHERE 1 = 1")

        If tbFirstName.Text.Trim.Length > 0 Then
            sb.Append(" and lower(FirstName) like @firstName")
            sbP.Append(",@firstName")
            sbV.Append("," + tbFirstName.Text.Trim.Replace("'", "''").ToLower + "%")
        End If
        If tbLastName.Text.Trim.Length > 0 Then
            sb.Append(" and lower(LastName) like @lastName")
            sbP.Append(",@lastName")
            sbV.Append("," + tbLastName.Text.Trim.Replace("'", "''").ToLower + "%")
        End If
        If tbArmyRank.Text.Trim.Length > 0 Then
            sb.Append(" and lower(ArmyRank) like @armyRank")
            sbP.Append(",@armyRank")
            sbV.Append("," + tbArmyRank.Text.Trim.Replace("'", "''").ToLower + "%")
        End If

        If macomList.SelectedValue.Length > 0 Then
            sb.Append(" and Macom= @macom")
            sbP.Append(",@macom")
            sbV.Append("," + macomList.SelectedValue.Replace("'", "''"))
        End If

        If tbOfficeName.Text.Trim.Length > 0 Then
            sb.Append(" and lower(OfficeName) like @officeName")
            sbP.Append(",@officeName")
            sbV.Append("," + tbOfficeName.Text.Trim.Replace("'", "''").ToLower + "%")
        End If
        If tbCompanyName.Text.Trim.Length > 0 Then
            sb.Append(" and lower(CompanyName) like @companyeName")
            sbP.Append(",@companyeName")
            sbV.Append("," + tbCompanyName.Text.Trim.Replace("'", "''").ToLower + "%")
        End If

        If txtDateCreatedFrom.Text.Trim.Length > 0 Then
            sb.Append(" and DateCreated >= @dtCreatedFrom")
            sbP.Append(",@dtCreatedFrom")
            sbV.Append("," + txtDateCreatedFrom.Text)
        End If
        If txtDateCreatedTo.Text.Trim.Length > 0 Then
            sb.Append(" and DateCreated < DATEADD(day,1,@dtCreatedTo)")
            sbP.Append(",@dtCreatedTo")
            sbV.Append("," + txtDateCreatedTo.Text)
        End If

        If txtDateUpdatedFrom.Text.Trim.Length > 0 Then
            sb.Append(" and LastUpdate >= @dtUpdatedFrom")
            sbP.Append(",@dtUpdatedFrom")
            sbV.Append("," + txtDateUpdatedFrom.Text)
        End If
        If txtDateUpdatedTo.Text.Trim.Length > 0 Then
            sb.Append(" and LastUpdate < DATEADD(day,1,@dtUpdatedTo)")
            sbP.Append(",@dtUpdatedTo")
            sbV.Append("," + txtDateUpdatedTo.Text)
        End If

        If txtLastLoginFrom.Text.Trim.Length > 0 Then
            sb.Append(" and LastLogin >= @dtLastLoginFrom")
            sbP.Append(",@dtLastLoginFrom")
            sbV.Append("," + txtLastLoginFrom.Text)
        End If
        If txtLastLoginTo.Text.Trim.Length > 0 Then
            sb.Append(" and LastLogin < DATEADD(day,1,@dtLastLoginTo)")
            sbP.Append(",@dtLastLoginTo")
            sbV.Append("," + txtLastLoginTo.Text)
        End If

        If txtLoginFrom.Text.Trim.Length > 0 Then
            sb.Append(" and loginDateTime >= @dtLoginFrom")
            sbP.Append(",@dtLoginFrom")
            sbV.Append("," + txtLoginFrom.Text)
        End If
        If txtLoginTo.Text.Trim.Length > 0 Then
            sb.Append(" and loginDateTime < DATEADD(day,1,@dtLoginTo)")
            sbP.Append(",@dtLoginTo")
            sbV.Append("," + txtLoginTo.Text)
        End If

        If txtLastApprovedFrom.Text.Trim.Length > 0 Then
            sb.Append(" and LastApprovedDate >= @dtLastApprovedDateFrom")
            sbP.Append(",@dtLastApprovedDateFrom")
            sbV.Append("," + txtLastApprovedFrom.Text)
        End If
        If txtLastApprovedTo.Text.Trim.Length > 0 Then
            sb.Append(" and LastApprovedDate < DATEADD(day,1,@dtLastApprovedDateTo)")
            sbP.Append(",@dtLastApprovedDateTo")
            sbV.Append("," + txtLastApprovedTo.Text)
        End If

        If txtLastDeniedFrom.Text.Trim.Length > 0 Then
            sb.Append(" and LastDeniedDate >= @dtLastDeniedDateFrom")
            sbP.Append(",@dtLastDeniedDateFrom")
            sbV.Append("," + txtLastDeniedFrom.Text)
        End If
        If txtLastDeniedTo.Text.Trim.Length > 0 Then
            sb.Append(" and LastDeniedDate < DATEADD(day,1,@dtLastDeniedDateTo)")
            sbP.Append(",@dtLastDeniedDateTo")
            sbV.Append("," + txtLastDeniedTo.Text)
        End If

        sb.Append(" GROUP BY u.UserId,u.LastName,u.FirstName,u.AkoID,u.Email,u.ArmyRank,u.Macom,u.CompanyName,u.OfficeName,u.ComPhone,u.ArmyAccountType,u.DateCreated,u.LastUpdate,u.LastLogin,u.UserRole;")

        Dim dt As DataTable
        If sbP.Length = 0 Then
            dt = DataAccessUtility.GetDataTableByStaticSql(sb.ToString)
        Else
            dt = DataAccessUtility.GetDataTableByStaticSql(sb.ToString, sbP.ToString.Substring(1).Split(",".ToCharArray()), sbV.ToString.Substring(1).Split(",".ToCharArray()))
        End If

        ViewState("SortExpression") = "Name"
        ViewState("SortDirection") = "ASC"
        ViewState("dt") = dt
        GridView1.DataSource = dt.DefaultView
        GridView1.DataBind()
        GridView2.DataSource = dt.DefaultView
        GridView2.DataBind()

        Dim bCountApprovedOnly As Boolean = True
        Dim bCountDeniedOnly As Boolean = False

        If tbFirstName.Text.Trim.Length > 0 Then
            bCountApprovedOnly = False
        End If

        If tbLastName.Text.Trim.Length > 0 Then
            bCountApprovedOnly = False
        End If

        If tbArmyRank.Text.Trim.Length > 0 Then
            bCountApprovedOnly = False
        End If

        If macomList.SelectedValue.Length > 0 Then
            bCountApprovedOnly = False
        End If

        If tbOfficeName.Text.Trim.Length > 0 Then
            bCountApprovedOnly = False
        End If

        If tbCompanyName.Text.Trim.Length > 0 Then
            bCountApprovedOnly = False
        End If

        If txtDateCreatedFrom.Text.Trim.Length > 0 Or txtDateCreatedTo.Text.Trim.Length > 0 Then
            bCountApprovedOnly = False
        End If

        If txtDateUpdatedFrom.Text.Trim.Length > 0 Or txtDateUpdatedTo.Text.Trim.Length > 0 Then
            bCountApprovedOnly = False
        End If

        If txtLastLoginFrom.Text.Trim.Length > 0 Or txtLastLoginTo.Text.Trim.Length > 0 Then
            bCountApprovedOnly = False
        End If

        If bCountApprovedOnly = True Then ' No other criterior other than Approve/Deny dates selected
            If txtLastApprovedFrom.Text.Trim.Length > 0 Or txtLastApprovedTo.Text.Trim.Length > 0 Then
                If txtLastDeniedFrom.Text.Trim.Length > 0 Or txtLastDeniedFrom.Text.Trim.Length > 0 Then
                    bCountApprovedOnly = False
                    bCountDeniedOnly = False
                Else
                    bCountApprovedOnly = True
                    bCountDeniedOnly = False
                End If
            Else
                If txtLastDeniedFrom.Text.Trim.Length > 0 Or txtLastDeniedFrom.Text.Trim.Length > 0 Then
                    bCountApprovedOnly = False
                    bCountDeniedOnly = True
                Else
                    bCountApprovedOnly = False
                    bCountDeniedOnly = False
                End If
            End If
        End If

        If bCountApprovedOnly Then
            lblRecCount.Text = "Approved Count = " & dt.Rows.Count
        ElseIf bCountDeniedOnly Then
            lblRecCount.Text = "Denied Count = " & dt.Rows.Count
        Else
            If dt.Rows.Count = 0 Then
                lblRecCount.Text = "No user records found under the selected filter."
            Else
                lblRecCount.Text = dt.Rows.Count.ToString + " user records found:"
            End If
        End If

        Me.ibDownloadExcel.Visible = (dt.Rows.Count > 0)
        GetFilterForExport()
    End Sub

    Private Sub GetFilterForExport()
        tbFirstNameEx.Text = tbFirstName.Text
        tbLastNameEx.Text = tbLastName.Text
        tbArmyRankEx.Text = tbArmyRank.Text
        tbMacomEx.Text = macomList.SelectedItem.Text
        tbOfficeNameEx.Text = tbOfficeName.Text
        tbCompanyNameEx.Text = tbCompanyName.Text


        tbDateCreatedFromEx.Text = txtDateCreatedFrom.Text
        tbDateCreatedToEx.Text = txtDateCreatedTo.Text
        tbDateUpdatedFromEx.Text = txtDateUpdatedFrom.Text
        tbDateUpdatedToEx.Text = txtDateUpdatedTo.Text
        tbLastLoginFromEx.Text = txtLastLoginFrom.Text
        tbLastLoginToEx.Text = txtLastLoginTo.Text
        tbLoginFromEx.Text = txtLoginFrom.Text
        tbLoginToEx.Text = txtLoginTo.Text
    End Sub

    Protected Sub ibDownloadExcel_Click(ByVal sender As Object, ByVal e As System.Web.UI.ImageClickEventArgs) Handles ibDownloadExcel.Click
        Dim license As Aspose.Cells.License = New Aspose.Cells.License()
        license.SetLicense("Aspose.Cells.lic")

        Dim wb As New Aspose.Cells.Workbook()
        Dim ws As Aspose.Cells.Worksheet = wb.Worksheets(0)

        Dim style As Aspose.Cells.Style
        Dim styleFlag As Aspose.Cells.StyleFlag
        styleFlag = New Aspose.Cells.StyleFlag()
        styleFlag.Borders = True
        styleFlag.FontBold = True
        styleFlag.FontColor = True
        styleFlag.CellShading = True
        styleFlag.HorizontalAlignment = True

        style = wb.CreateStyle()
        style.Pattern = Aspose.Cells.BackgroundType.Solid
        style.ShrinkToFit = True

        style.Borders(Aspose.Cells.BorderType.TopBorder).LineStyle = Aspose.Cells.CellBorderType.Thin
        style.Borders(Aspose.Cells.BorderType.BottomBorder).LineStyle = Aspose.Cells.CellBorderType.Thin
        style.Borders(Aspose.Cells.BorderType.LeftBorder).LineStyle = Aspose.Cells.CellBorderType.Thin
        style.Borders(Aspose.Cells.BorderType.RightBorder).LineStyle = Aspose.Cells.CellBorderType.Thin

        ' Insert data
        style.ForegroundColor = Color.White
        style.Font.Color = Color.Black
        Dim importOptions As ImportTableOptions = New ImportTableOptions()
        importOptions.InsertRows = True
        importOptions.ConvertNumericData = False
        importOptions.ConvertGridStyle = False
        ws.Cells.ImportGridView(GridView2, 0, 0, importOptions)
        ws.Cells.CreateRange(0, 0, GridView2.Rows.Count, GridView2.Rows(0).Cells.Count).ApplyStyle(style, styleFlag)

        ' remove "&nbsp;" junk for blank cells
        For i As Integer = 0 To GridView2.Rows.Count - 1
            For j As Integer = 0 To GridView2.Rows(0).Cells.Count - 1
                If CType(ws.Cells(i, j).Value, String) = "&nbsp;" Then ws.Cells(i, j).Value = ""
            Next
        Next

        ' Apply style to header row
        style.Font.IsBold = True
        style.Font.Color = Color.White
        style.ForegroundColor = Color.Navy
        ws.Cells.CreateRange(0, 0, 1, GridView2.Rows(0).Cells.Count).ApplyStyle(style, styleFlag)


        ' Insert filter settings
        For i As Integer = 1 To 13
            ws.Cells.InsertRow(0)
        Next
        style.Font.Color = Color.Black
        style.ForegroundColor = Color.White
        style.Font.IsBold = False

        ws.Cells(2, 0).Value = "First Name: "
        ws.Cells(2, 1).Value = tbFirstNameEx.Text

        ws.Cells(3, 0).Value = "Last Name: "
        ws.Cells(3, 1).Value = tbLastNameEx.Text

        ws.Cells(4, 0).Value = "Rank/Grade: "
        ws.Cells(4, 1).Value = tbArmyRankEx.Text

        ws.Cells(5, 0).Value = "Organization: "
        ws.Cells(5, 1).Value = tbMacomEx.Text

        ws.Cells(6, 0).Value = "Office Name: "
        ws.Cells(6, 1).Value = tbOfficeNameEx.Text

        ws.Cells(7, 0).Value = "Company Name: "
        ws.Cells(7, 1).Value = tbCompanyNameEx.Text

        ws.Cells(8, 0).Value = "Date Created between: "
        ws.Cells(8, 1).Value = tbDateCreatedFromEx.Text + " and " + tbDateCreatedToEx.Text

        ws.Cells(9, 0).Value = "Last Updated between: "
        ws.Cells(9, 1).Value = tbDateUpdatedFromEx.Text + " and " + tbDateUpdatedToEx.Text

        ws.Cells(10, 0).Value = "Last Login between: "
        ws.Cells(10, 1).Value = tbLastLoginFromEx.Text + " and " + tbLastLoginToEx.Text

        ws.Cells(11, 0).Value = "Login History between: "
        ws.Cells(11, 1).Value = tbLoginFromEx.Text + " and " + tbLoginToEx.Text

        ws.Cells.CreateRange(2, 0, 10, 2).ApplyStyle(style, styleFlag)

        style.Font.IsBold = True
        style.Font.Size = 14
        style.ShrinkToFit = True
        ws.Cells.Merge(0, 0, 2, 9)
        ws.Cells(0, 0).Value = "User List"
        ws.Cells(0, 0).SetStyle(style)

        AddClassification(ws)
        ws.AutoFitColumns()
        wb.Save(Response, "AMCOSUserListData_" + Now().ToString("yyyyMMdd-HHmmss") + ".xlsx", Aspose.Cells.ContentDisposition.Attachment, New Aspose.Cells.OoxmlSaveOptions(Aspose.Cells.SaveFormat.Xlsx))
        Response.End()
    End Sub

    Private Sub LoadMacomList()
        macomList.Items.Clear()
        macomList.DataSource = UserAdministration.GetOrganizations.ToList()
        macomList.DataBind()
        macomList.Items.Insert(0, New ListItem("-ALL-", ""))

    End Sub
End Class
