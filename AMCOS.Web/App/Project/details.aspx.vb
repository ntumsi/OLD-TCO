Imports System.Configuration.ConfigurationManager
Imports AMCOS.Data.DataTransferObjects
Imports AMCOS.Data.Entities
Imports AMCOS.Logic

Partial Class ProjectDetails
    Inherits BasePage

    ReadOnly updateInventoryProjectYearStartColumn As Integer = 12
    Dim insertInventoryStartRow As Integer = 8
    ReadOnly amcosVersionId As Integer = CInt(AppSettings("AmcosVersionId"))
    Public CurrentProject As PMProject
    Public minimumStartYear As Integer
    Public maximumStartYear As Integer
    Public ReadOnly Property ProjectId() As Integer = Convert.ToInt32(Context.Request.QueryString("ProjectId"))
    Public ReadOnly Property CategoryId() As Integer
        Get
            Dim CatID As Integer = 0
            For Each oItem As DataListItem In PMCategoryDataList.Items
                Dim oButton As Button = CType(oItem.Controls(1), Button)
                If oButton.BackColor = Drawing.Color.Yellow Then
                    CatID = CType(oButton.CommandArgument, Integer)
                End If
            Next
            If CatID = 0 Then
                CatID = CType(DirectCast(PMCategoryDataList.Items(0).Controls(1), Button).CommandArgument, Integer)
            End If
            Return CatID
        End Get
    End Property
    Protected Sub Page_Load(ByVal sender As Object, ByVal e As EventArgs) Handles Me.Load
        RefreshProjectSettings()

        minimumStartYear = CInt(SingleValue.Get("ALL", "ProjectManager_StartYear", CInt(AppSettings("AmcosVersionId"))))
        maximumStartYear = minimumStartYear + 29

        If IsPostBack Then  ' 10/16/2012 
            lblInsertMsg.Text = ""
            lbCopyCatMsg.Text = ""
        Else
            'MyBase.ViewState("ProjectName") = currentProject.ProjectName
            'MyBase.ViewState("ProjectYearStart") = currentProject.YearStart
            'MyBase.ViewState("ProjectYearDuration") = currentProject.YearDuration
        End If

        Dim button As Button = CType(wizProject.FindControl("StepNavigationTemplateContainerID").FindControl("StepNextButton"), Button)
        If Not (IsDBNull(button)) Then
            button.OnClientClick = "return validateAddUnit();"
        End If
    End Sub
    Protected Sub OnActiveStepChanged(ByVal sender As Object, ByVal e As WizardNavigationEventArgs)
        ' 11/15/2012 - Set "Use Default" Summary selection
        'If e.NextStepIndex = 2 Then rblSumCopyNew_SelectedIndexChanged(Nothing, Nothing)
    End Sub
    Sub OnNextButtonClick(ByVal sender As Object, ByVal e As WizardNavigationEventArgs) Handles wizProject.NextButtonClick, wizProject.SideBarButtonClick
        Dim project As New Project

        Select Case e.CurrentStepIndex
            Case 0
                Dim wizardProjectName As String = CType(Me.ProjectPropertiesDetail.Rows(2).Cells(1).Controls(1), TextBox).Text
                Dim wizardProjectDescription As String = CType(Me.ProjectPropertiesDetail.Rows(3).Cells(1).Controls(1), TextBox).Text
                Dim wizardProjectStartYear As String = CType(Me.ProjectPropertiesDetail.Rows(4).Cells(1).Controls(1), TextBox).Text
                Dim wizardProjectDuration As String = CType(Me.ProjectPropertiesDetail.Rows(5).Cells(1).Controls(1), TextBox).Text

                If wizardProjectName <> CurrentProject.ProjectName Then ' 3/5/2013 update "Project Name" in case of change
                    project.UpdateCategoryName(ProjectId, CurrentProject.ProjectName, wizardProjectName)
                    ProjectPropertiesDetail.UpdateItem(True)
                End If

                If (wizardProjectStartYear <> CurrentProject.YearStart.ToString) Or (wizardProjectDuration <> CurrentProject.YearDuration.ToString) Or (wizardProjectDescription <> CurrentProject.Description) Then
                    ProjectPropertiesDetail.UpdateItem(True)
                End If
            Case 1
                If e.NextStepIndex > 1 Then
                    If selectedUnit.Value <> "" Then
                        Select Case selectedOperation.Value
                            Case "Subproject"
                                Dim subprojectId As Integer
                                Dim subprojectName As String = inputNewSubprojectName.Value
                                subprojectId = project.CreateProjectCategory(ProjectId, subprojectName)
                                If subprojectId <> 0 Then
                                    project.AddUnit(subprojectId, selectedUnit.Value, excludedPayPlans.Value, unitLocation.Value, selectedMtoeProjectInventoryYear.Value, selectedProjectExtendsSacsYears.Value, Decimal.Parse(inputUnitContractorOverheadPercent.Value), amcosVersionId)
                                    'update this line
                                End If
                            Case "Replace"
                                project.ReplaceProject(ProjectId, selectedUnit.Value, excludedPayPlans.Value, unitLocation.Value, selectedMtoeProjectInventoryYear.Value, selectedProjectExtendsSacsYears.Value, Decimal.Parse(inputUnitContractorOverheadPercent.Value), amcosVersionId)
                            Case "Append"
                                project.AddUnit(CategoryId, selectedUnit.Value, excludedPayPlans.Value, unitLocation.Value, selectedMtoeProjectInventoryYear.Value, selectedProjectExtendsSacsYears.Value, Decimal.Parse(inputUnitContractorOverheadPercent.Value), amcosVersionId)
                        End Select
                    End If
                End If
        End Select

        Select Case e.NextStepIndex
            Case 2
                PMCategoryDataList.DataBind()
                LoadPMCategoryList()
                InventoryGridView.DataBind()
                SetUpdateInventoryGridYearVisibility()
            Case 3
                gvOutput.DataBind()
        End Select
    End Sub

    Private Sub RefreshProjectSettings()
        Dim project As New Project
        CurrentProject = project.GetProject(ProjectId)
        projectStartYear.Value = CurrentProject.YearStart.ToString
        projectDuration.Value = CurrentProject.YearDuration.ToString
    End Sub

    Sub OnPreviousButtonClick(ByVal sender As Object, ByVal e As WizardNavigationEventArgs)

    End Sub
    Sub OnSideBarButtonClick(ByVal sender As Object, ByVal e As WizardNavigationEventArgs)

    End Sub
    Private Sub LoadPMCategoryList()
        Dim project As Project = New Project()
        Dim projectManagerCategoryList As IEnumerable(Of ListItemDto)
        projectManagerCategoryList = project.GetCategoryList(ProjectId, CategoryId)
        If projectManagerCategoryList.Count = 0 Then
            pnlCopyCat.Visible = False
        Else
            pnlCopyCat.Visible = True
            PMCategoryList.Items.Clear()
            PMCategoryList.DataSource = projectManagerCategoryList
            PMCategoryList.DataBind()
        End If
    End Sub
    Private Function HasPayPlanChecked(strPayPlan As String) As Boolean
        For Each oRow As GridViewRow In gvOutput.Rows
            If oRow.Cells(1).Text = strPayPlan Then
                Dim chkBox = CType(oRow.Cells(3).Controls(0).FindControl("chkOuputInReport"), CheckBox)
                If chkBox.Checked Then
                    Return True
                End If
            End If
        Next
        Return False
    End Function
    Protected Sub SetUpdateInventoryGridYearVisibility()        ' added 10/16/2012
        'Set the column header text
        For projectYearIndex As Integer = 0 To CurrentProject.YearDuration - 1
            InventoryGridView.Columns.Item(updateInventoryProjectYearStartColumn + projectYearIndex).Visible = True
            InventoryGridView.Columns.Item(updateInventoryProjectYearStartColumn + projectYearIndex).HeaderText = "Year " + (CurrentProject.YearStart + projectYearIndex).ToString
        Next

        'Only show columns for project duration
        For projectYearIndex As Integer = CurrentProject.YearDuration To 30
            InventoryGridView.Columns.Item(projectYearIndex + updateInventoryProjectYearStartColumn).Visible = False
        Next
    End Sub
    Protected Sub InventoryGridView_Load(ByVal sender As Object, ByVal e As System.EventArgs) Handles InventoryGridView.Load
        SetUpdateInventoryGridYearVisibility()
    End Sub
    Protected Sub InventoryGridView_RowCommand(ByVal sender As Object, ByVal e As CommandEventArgs) Handles InventoryGridView.RowCommand
        Dim skillId As Integer = 0
        Select Case e.CommandName
            Case "btnUpdate"
                ' do nothing
            Case "btnDelete"
                For Each oRow As GridViewRow In InventoryGridView.Rows
                    If oRow.RowType = DataControlRowType.DataRow Then
                        If DirectCast(oRow.FindControl("chkDelete"), CheckBox).Checked Then
                            skillId = Integer.Parse(DirectCast(oRow.FindControl("skillId"), HiddenField).Value)
                            Dim projectRequirement As New ProjectRequirement()
                            projectRequirement.DeletePMCategorySkill(skillId)
                        End If
                    End If
                Next
                InventoryGridView.DataBind()
                ddlDelCategoryList.DataBind()
        End Select
    End Sub
    Protected Sub InventoryGridView_RowDataBound(ByVal sender As Object, ByVal e As GridViewRowEventArgs) Handles InventoryGridView.RowDataBound
        Dim projectRequirement As ProjectRequirement = New ProjectRequirement()
        If e.Row.RowType = DataControlRowType.DataRow Then
            Dim skillId As Integer = CInt(DataBinder.Eval(e.Row.DataItem, "SkillId"))
            Dim categorySkillInventories As List(Of PMCategorySkillInventory) = projectRequirement.GetCategorySkillInventory(skillId)
            For Each inventoryId As PMCategorySkillInventory In categorySkillInventories
                DirectCast(e.Row.Cells(updateInventoryProjectYearStartColumn + inventoryId.Year).Controls(1), TextBox).Text = inventoryId.Amount.ToString
            Next
        End If
    End Sub
    Protected Sub PMCategoryDataList_ItemCommand(ByVal source As Object, ByVal e As DataListCommandEventArgs) Handles PMCategoryDataList.ItemCommand
        Dim oSource As DataList = CType(source, DataList)
        For Each oItem As DataListItem In oSource.Items
            DirectCast(oItem.Controls(1), Button).BackColor = Nothing
        Next
        DirectCast(e.CommandSource, Button).BackColor = Drawing.Color.Yellow
        InventoryGridView.DataBind()
        LoadPMCategoryList()
    End Sub
    Protected Sub PMCategoryDataList_Load(ByVal sender As Object, ByVal e As EventArgs) Handles PMCategoryDataList.Load
        If PMCategoryDataList.Items.Count = 0 Then
            CreateDefaultCategory()
        End If
        If Not IsPostBack Then
            DirectCast(PMCategoryDataList.Items(0).Controls(1), Button).BackColor = Drawing.Color.Yellow
        End If
    End Sub
    Protected Sub OdsCategories_Selecting(ByVal sender As Object, ByVal e As ObjectDataSourceMethodEventArgs) Handles odsCategories.Selecting
        e.InputParameters.Item("ProjectId") = ProjectId
    End Sub
    Protected Sub OdsSkillInventories_Selecting(ByVal sender As Object, ByVal e As ObjectDataSourceMethodEventArgs) Handles odsSkillInventories.Selecting
        e.InputParameters.Item("CategoryId") = CategoryId
    End Sub
    'TODO: Show correct inventory insert columns based On project duration
    'Protected Sub ProjectInventoryInsertTable_Load(ByVal sender As Object, ByVal e As System.EventArgs) Handles ProjectInventoryInsertTable.Load
    '    If Not IsPostBack Then
    '        For iCell As Integer = 0 To oProject.YearDuration - 1
    '            DirectCast(ProjectInventoryInsertTable.Rows(insertInventoryStartRow).Cells(1).Controls(0), Table).Rows(0).Cells(iCell).Text = "Year " + (oProject.YearStart + iCell).ToString
    '            DirectCast(ProjectInventoryInsertTable.Rows(insertInventoryStartRow).Cells(1).Controls(0), Table).Rows(0).Cells(iCell).Visible = True
    '            DirectCast(ProjectInventoryInsertTable.Rows(insertInventoryStartRow).Cells(1).Controls(0), Table).Rows(1).Cells(iCell).Visible = True
    '        Next

    '        'TODO: LoadPayPlanList()
    '        SetVisibleElements(selectedPayPlan.Value)
    '    End If
    'End Sub
    Protected Sub BtnAddRequirement_Click(ByVal sender As Object, ByVal e As EventArgs) Handles btnAddRequirement.Click
        ' 5/22/2013 Dis-allow inserting duplicates

        If Page.IsValid Then
            Dim projectRequirement = New ProjectRequirement With {.CategoryId = CategoryId,
                .PayPlan = selectedPayPlan.Value,
                .CategoryGroupCode = selectedCategoryGroupCode.Value,
                .CategorySubgroupCode = selectedCategorySubgroupCode.Value,
                .CareerProgramNumber = selectedCareerProgramNumber.Value,
                .LocationId = Convert.ToInt32(selectedLocationId.Value),
                .LocationText = selectedLocationText.Value,
                .STRL = selectedScienceTechnologyReinventionLaboratory.Value,
                .GradeLevel = Convert.ToByte(selectedGradeLevel.Value),
                .DependentStatus = selectedDependentStatus.Value,
                .NumberOfDependents = Convert.ToInt32(selectedNumberOfDependents.Value),
                .ActiveDutyDays = Convert.ToInt16(inputActiveDutyDays.Value),
                .OverheadPercent = Convert.ToDouble(inputOverheadPercent.Value),
                .Inventory = inputProjectInventory.Value.Split({","c}).Select(Function(n) Integer.Parse(n)).ToArray}

            If projectRequirement.CreatePMCategorySkill() <> 0 Then
                InventoryGridView.DataBind()
            Else
                lblInsertMsg.Text = "This record is already in your project. Please delete the record before adding another or adjust the inventory in the matrix above."
            End If
        End If
    End Sub
    Protected Sub ListOfCategoriesToDelete_Selecting(ByVal sender As Object, ByVal e As ObjectDataSourceMethodEventArgs) Handles ListOfCategoriesToDelete.Selecting
        e.InputParameters.Item("ProjectId") = ProjectId
    End Sub
    Protected Sub BtnDelCategoryList_Click(ByVal sender As Object, ByVal e As System.EventArgs) Handles btnDelCategoryList.Click
        Dim project As New Project()
        project.DeleteSubProject(Convert.ToInt32(ddlDelCategoryList.SelectedValue))
        ddlDelCategoryList.DataBind()
        PMCategoryDataList.DataBind()

        SetSelectedCategory("")
        InventoryGridView.DataBind()

        ' Check to remove relevant Summaries if a PayPlan has no Category userCategorySkill record any more
        'Dim dtPayPlansToCheck As DataTable = DataAccessUtility.GetDataTableByStaticSql("SELECT DISTINCT PMCategorySkill.PayPlan FROM webuser.PMCategory PMCategory JOIN webuser.PMCategorySkill PMCategorySkill ON PMCategory.CategoryId=PMCategorySkill.CategoryId WHERE PMCategory.ProjectId=@ProjectId;", {"@ProjectId"}, {ProjectId})
        'Dim dtPayPlans As DataTable = DataAccessUtility.GetDataTableByStaticSql("select PayPlan from lookup.PayPlan")
        LoadPMCategoryList()
    End Sub
    Sub CreateDefaultCategory()
        Dim project As New Project
        project.CreateProjectCategory(ProjectId, CurrentProject.ProjectName)
        ddlDelCategoryList.DataBind()
        PMCategoryDataList.DataBind()
        InventoryGridView.DataBind()
    End Sub
    Protected Sub BtnAddSubproject_Click(ByVal sender As Object, ByVal e As EventArgs) Handles btnAddSubproject.Click
        Dim newCategoryName As String = Me.newCategoryName.Text.Trim
        Dim project As New Project()

        project.CreateProjectCategory(ProjectId, newCategoryName)
        PMCategoryDataList.DataBind()
        ddlDelCategoryList.DataBind()
        Me.newCategoryName.Text = ""

        SetSelectedCategory(newCategoryName)
        InventoryGridView.DataBind()

        LoadPMCategoryList()
    End Sub
    Private Sub SetSelectedCategory(sCat As String)
        Dim bFount As Boolean = False
        For Each oItem As DataListItem In PMCategoryDataList.Items
            DirectCast(oItem.Controls(1), Button).BackColor = Nothing
            If DirectCast(oItem.Controls(1), Button).Text = sCat Then
                DirectCast(oItem.Controls(1), Button).BackColor = Drawing.Color.Yellow
                bFount = True
            End If
        Next
        If Not bFount Then DirectCast(PMCategoryDataList.Items(0).Controls(1), Button).BackColor = Drawing.Color.Yellow
    End Sub
    Protected Sub BuildReport_Click(ByVal sender As Object, ByVal e As System.EventArgs) Handles buildReport.Click
        Dim sbPayPlans As New StringBuilder()
        Dim project As New Project()

        project.DeleteReportByProject(ProjectId)
        For Each oRow As GridViewRow In gvOutput.Rows
            If DirectCast(oRow.Cells(3).Controls(1), CheckBox).Checked Then
                project.InsertReport(CType(CType(oRow.Cells(0).Controls(1), HiddenField).Value, Integer), oRow.Cells(1).Text)
                If sbPayPlans.ToString.IndexOf("'" + oRow.Cells(1).Text + "'") < 0 Then
                    sbPayPlans.Append(",'" + oRow.Cells(1).Text + "'")
                End If
            End If
        Next

        If sbPayPlans.Length = 0 Then
            Exit Sub
        End If

        Dim PMReportOutputColumns As String = String.Empty
        For Each oListItem As ListItem In cblSumOutputFields.Items
            If oListItem.Enabled Then
                PMReportOutputColumns = PMReportOutputColumns & "," & oListItem.Value
            End If
        Next

        Session("CheckedFields") = PMReportOutputColumns.Substring(1)

        Dim sPopupScript As String = "<script language='javascript'> " &
        " window.open('waitreport.aspx?ProjectId=" & ProjectId.ToString & "', 'CustomPopUp'," &
        " 'top=0,left=0,width=500,height=500,scrollbars=yes,menubar=no,toolbar=no,status=1,resizable=yes'); " &
        "</script>"
        Me.InsertScript("ProjectReport", sPopupScript)

        Session("PayPlansInReport") = sbPayPlans.ToString.Substring(1) ' replace the first and last comma with parenceses
    End Sub
    Protected Sub CvOutFields_ServerValidate(ByVal source As Object, ByVal args As System.Web.UI.WebControls.ServerValidateEventArgs) Handles cvOutFields.ServerValidate
        args.IsValid = False
        For Each oChk As ListItem In cblSumOutputFields.Items
            If oChk.Selected Then
                args.IsValid = True
            End If
        Next

    End Sub
    Protected Sub CvOutputReport_ServerValidate(ByVal source As Object, ByVal args As System.Web.UI.WebControls.ServerValidateEventArgs) Handles cvOutputReport.ServerValidate
        args.IsValid = False
        For Each oRow As GridViewRow In gvOutput.Rows
            For Each oCell As TableCell In oRow.Cells
                If DirectCast(oCell.FindControl("chkOuputInReport"), CheckBox).Checked Then
                    args.IsValid = True
                End If
            Next
        Next
        If Not args.IsValid Then
            SendAlertScript("OutputReports", "Please select a Summary / Category combination")
        End If
    End Sub
    Protected Sub GvOutput_RowCreated(ByVal sender As Object, ByVal e As System.Web.UI.WebControls.GridViewRowEventArgs) Handles gvOutput.RowCreated
        e.Row.Cells(0).Visible = False
    End Sub
    Protected Sub LnkCheckAllPayPlan_Click(sender As Object, e As System.EventArgs) Handles lnkCheckAllPayPlan.Click, lnkRemoveAllPayPlan.Click
        Select Case CType(sender, Control).ID
            Case "lnkCheckAllPayPlan"
                For Each oRow As GridViewRow In gvOutput.Rows
                    DirectCast(oRow.Cells(3).Controls(1), CheckBox).Checked = True
                Next
            Case "lnkRemoveAllPayPlan"
                For Each oRow As GridViewRow In gvOutput.Rows
                    DirectCast(oRow.Cells(3).Controls(1), CheckBox).Checked = False
                Next

        End Select
    End Sub
    Protected Sub BtnCloseProject_Click(ByVal sender As Object, ByVal e As System.EventArgs) Handles btnCloseProject.Click
        Response.Redirect("default.aspx")
    End Sub
    Protected Sub WizProject_FinishButtonClick(ByVal sender As Object, ByVal e As System.Web.UI.WebControls.WizardNavigationEventArgs) Handles wizProject.FinishButtonClick
        Response.Redirect("default.aspx")
    End Sub
    Protected Sub LnkCheckAllFields_Click(sender As Object, e As System.EventArgs) Handles lnkCheckAllFileds.Click, lnkRemoveAllFileds.Click
        Dim bChecked As Boolean = (CType(sender, Control).ID = "lnkCheckAllFileds")
        For Each cItem As ListItem In cblSumOutputFields.Items
            If cItem.Enabled Then cItem.Selected = bChecked
        Next
    End Sub
    Protected Sub BtnUpdate_Click(sender As Object, e As System.EventArgs) Handles btnUpdate.Click

        For Each oRow As GridViewRow In InventoryGridView.Rows
            If oRow.RowType = DataControlRowType.DataRow Then

                'Delete all records from ProjectCategorySkillInventory for the SkillId and insert the values from the text boxes
                Dim skillId As Integer
                Try
                    skillId = Integer.Parse(DirectCast(oRow.FindControl("skillId"), HiddenField).Value)
                Catch ex As Exception
                    Dim strErr As String = String.Format("iSkillID='{0}'", DirectCast(oRow.FindControl("skillId"), HiddenField).Value)
                    DataAccessUtility.GetScalarByStaticSql("insert into web.ApplicationErrorLog (ErrorTime, UserId, ErrorPage, ErrorDetail) values (getdate(), @uID, 'Project/details.aspx.vb', @errDetail)", {"@uID", "@errDetail"}, {currentUser.UserId, strErr})
                    Throw
                End Try

                Dim projectRequirement As New ProjectRequirement()
                projectRequirement.DeletePMCategorySkillInventoryAll(skillId)

                For projectYear As Integer = 0 To CurrentProject.YearDuration - 1
                    Dim inventory As Integer
                    Try
                        inventory = Integer.Parse(DirectCast(oRow.FindControl("UpdateYear" + projectYear.ToString), TextBox).Text)
                    Catch ex As Exception
                        DataAccessUtility.GetScalarByStaticSql("insert into web.ApplicationErrorLog (ErrorTime, UserId, ErrorPage, ErrorDetail) values (getdate(), @uID, 'Project/details.aspx.vb', @errDetail)", {"@uID", "@errDetail"}, {currentUser.UserId, "iValue=" + DirectCast(oRow.FindControl("Year" + (projectYear).ToString), TextBox).Text})
                        Throw
                    End Try

                    If inventory > 0 Then
                        projectRequirement.CreatePMCategorySkillInventory(skillId, projectYear, inventory)
                    End If
                Next
            End If
        Next
        ddlDelCategoryList.DataBind()
    End Sub
    Protected Sub BtnRename_Click(sender As Object, e As System.EventArgs) Handles btnRename.Click

        If CurrentProject.ProjectName = ddlDelCategoryList.SelectedItem.Text Then ' disallow renaming the default project
            btnRename.Visible = False
            Exit Sub
        End If

        txtNewName.Text = ddlDelCategoryList.SelectedItem.Text
        pnlRename.Visible = True
        btnDelCategoryList.Visible = False
        btnRename.Visible = False
        ddlDelCategoryList.Enabled = False
        LoadPMCategoryList()
    End Sub
    Protected Sub BtnCancel_Click(sender As Object, e As System.EventArgs) Handles btnCancel.Click
        pnlRename.Visible = False
        btnDelCategoryList.Visible = True
        btnRename.Visible = True
        ddlDelCategoryList.Enabled = True
    End Sub
    Protected Sub BtnSave_Click(sender As Object, e As System.EventArgs) Handles btnSave.Click

        Dim sNewCatName As String = txtNewName.Text.Trim
        If sNewCatName = ddlDelCategoryList.SelectedItem.Text Then
            Exit Sub
        End If

        If CType(DataAccessUtility.GetScalarByStaticSql("SELECT count(*) FROM webuser.PMCategory WHERE  ProjectId = @ProjectId and CategoryName = @name", {"@ProjectId", "@name"}, {ProjectId, sNewCatName}), Integer) > 0 Then
            Exit Sub ' Category already exists
        End If

        DataAccessUtility.GetScalarByStaticSql("UPDATE webuser.PMCategory set CategoryName = @nameNew WHERE ProjectId = @ProjectId and CategoryName = @nameOld", {"@nameNew", "@ProjectId", "@nameOld"}, {sNewCatName, ProjectId, ddlDelCategoryList.SelectedItem.Text})

        ddlDelCategoryList.DataBind()
        PMCategoryDataList.DataBind()

        SetSelectedCategory(sNewCatName)

        BtnCancel_Click(Nothing, Nothing)
    End Sub
    Protected Sub DdlDelCategoryList_DataBound(sender As Object, e As System.EventArgs) Handles ddlDelCategoryList.DataBound
        pnlRenameOrDelete.Visible = (ddlDelCategoryList.Items.Count > 0)
    End Sub
    Protected Sub BtnCopyCat_Click(sender As Object, e As System.EventArgs) Handles btnCopyCat.Click
        Dim sql As String = "SELECT web.ProjectCategoryCount(@ProjectId,@FromCategoryId,@ToCategoryId);"
        If CType(DataAccessUtility.GetScalarByStaticSql(sql, {"@ProjectId", "@FromCategoryId", "@ToCategoryId"}, {ProjectId, CType(PMCategoryList.SelectedValue, Integer), CategoryId}), Integer) = 0 Then
            lbCopyCatMsg.Text = "Your copy attempt could not be executed because it would duplicate data.  If you need to change inventory values please do so using the inventory table above."
            Exit Sub
        End If

        Try
            DataAccessUtility.ExecuteStoredProc("web.PMCopyProjectCategory", {"@FromCategoryId", "@ToCategoryId"}, {SqlDbType.Int, SqlDbType.Int}, {CType(PMCategoryList.SelectedValue, Integer), CategoryId})
        Catch ex As Exception
            lbCopyCatMsg.Text = "Sorry, can't copy the project this time.  If the problem persists, please contact the system administrator"
            DataAccessUtility.GetScalarByStaticSql("insert into web.ApplicationErrorLog (ErrorTime, UserId, ErrorPage, ErrorDetail) values (getdate(), @uid, 'Lite/default.aspx.vb', @errDetail)", {"@uid", "@errDetail"}, {currentUser.UserId, sql})
            Throw
        End Try

        InventoryGridView.DataBind()
    End Sub
    Protected Sub ValidateInsertInventory(source As Object, args As ServerValidateEventArgs)

        'TODO Validate all rows
        Try
            Dim inventoryYear1 As Integer = CInt(InsertYear1.Text)
            Dim inventoryYear2 As Integer = CInt(InsertYear2.Text)
            Dim inventoryYear3 As Integer = CInt(InsertYear3.Text)
            Dim inventoryYear4 As Integer = CInt(InsertYear4.Text)
            Dim inventoryYear5 As Integer = CInt(InsertYear5.Text)
            Dim inventoryYear6 As Integer = CInt(InsertYear6.Text)
            Dim inventoryYear7 As Integer = CInt(InsertYear7.Text)
            Dim inventoryYear8 As Integer = CInt(InsertYear8.Text)
            Dim inventoryYear9 As Integer = CInt(InsertYear9.Text)
            Dim inventoryYear10 As Integer = CInt(InsertYear10.Text)
            Dim inventoryYear11 As Integer = CInt(InsertYear11.Text)
            Dim inventoryYear12 As Integer = CInt(InsertYear12.Text)
            Dim inventoryYear13 As Integer = CInt(InsertYear13.Text)
            Dim inventoryYear14 As Integer = CInt(InsertYear14.Text)
            Dim inventoryYear15 As Integer = CInt(InsertYear15.Text)
            Dim inventoryYear16 As Integer = CInt(InsertYear16.Text)
            Dim inventoryYear17 As Integer = CInt(InsertYear17.Text)
            Dim inventoryYear18 As Integer = CInt(InsertYear18.Text)
            Dim inventoryYear19 As Integer = CInt(InsertYear19.Text)
            Dim inventoryYear20 As Integer = CInt(InsertYear20.Text)
            Dim inventoryYear21 As Integer = CInt(InsertYear21.Text)
            Dim inventoryYear22 As Integer = CInt(InsertYear22.Text)
            Dim inventoryYear23 As Integer = CInt(InsertYear23.Text)
            Dim inventoryYear24 As Integer = CInt(InsertYear24.Text)
            Dim inventoryYear25 As Integer = CInt(InsertYear25.Text)
            Dim inventoryYear26 As Integer = CInt(InsertYear26.Text)
            Dim inventoryYear27 As Integer = CInt(InsertYear27.Text)
            Dim inventoryYear28 As Integer = CInt(InsertYear28.Text)
            Dim inventoryYear29 As Integer = CInt(InsertYear29.Text)
            Dim inventoryYear30 As Integer = CInt(InsertYear30.Text)

            Dim inventorySum As Integer = inventoryYear1 + inventoryYear2 + inventoryYear3 + inventoryYear4 + inventoryYear5 _
                + inventoryYear6 + inventoryYear7 + inventoryYear8 + inventoryYear9 + inventoryYear10 + inventoryYear11 + inventoryYear12 _
                + inventoryYear13 + inventoryYear14 + inventoryYear15 + inventoryYear16 + inventoryYear17 + inventoryYear18 + inventoryYear19 _
                + inventoryYear20 + inventoryYear21 + inventoryYear22 + inventoryYear23 + inventoryYear24 + inventoryYear25 + inventoryYear26 _
                + inventoryYear27 + inventoryYear28 + inventoryYear29 + inventoryYear30

            If inventorySum > 0 Then
                args.IsValid = True
            Else
                args.IsValid = False
            End If

        Catch ex As Exception
            args.IsValid = False

        End Try

    End Sub
    Private Sub ProjectOutputs_Selecting(sender As Object, e As ObjectDataSourceSelectingEventArgs) Handles ProjectOutputs.Selecting
        e.InputParameters("ProjectId") = ProjectId
    End Sub
    Private Sub ProjectProperties_Selecting(sender As Object, e As ObjectDataSourceSelectingEventArgs) Handles ProjectProperties.Selecting
        e.InputParameters("ProjectId") = ProjectId
    End Sub

    Private Sub ProjectPropertiesDetail_ItemUpdated(sender As Object, e As DetailsViewUpdatedEventArgs) Handles ProjectPropertiesDetail.ItemUpdated
        'Dim i As Integer
        'For i = 0 To e.OldValues.Count - 1
        '    If e.OldValues(i).ToString() <> e.NewValues(i).ToString Then
        '        Dim x As Integer
        '        x = i
        '    End If

        'Next

        'If wizardProjectName <> CurrentProject.ProjectName Then ' 3/5/2013 update "Project Name" in case of change
        '    Project.UpdateCategoryName(ProjectId, CurrentProject.ProjectName, wizardProjectName)
        '    PMCategoryDataList.DataBind()
        'End If

        'If (wizardProjectStartYear <> CurrentProject.YearStart.ToString) Or (wizardProjectDuration <> CurrentProject.YearDuration.ToString) Then
        '    odsSkillInventories.DataBind()
        '    InventoryGridView.DataBind()
        '    SetUpdateInventoryGridYearVisibility()
        'End If

        LoadPMCategoryList()

        RefreshProjectSettings()
        ProjectPropertiesDetail.DataBind()
    End Sub

    Private Sub ProjectPropertiesDetail_ItemUpdating(sender As Object, e As DetailsViewUpdateEventArgs) Handles ProjectPropertiesDetail.ItemUpdating
        For i As Integer = 0 To e.NewValues.Count - 1
            If Not IsDBNull(e.NewValues(i)) Then
                e.NewValues(i) = Server.HtmlEncode(e.NewValues(i).ToString())
            End If
        Next
    End Sub
End Class
