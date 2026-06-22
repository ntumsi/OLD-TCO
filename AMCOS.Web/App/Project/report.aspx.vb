Imports System.ComponentModel
Imports System.Configuration.ConfigurationManager
Imports System.Drawing
Imports AMCOS.Data.Entities
Imports AMCOS.Logic
Imports AMCOS.Logic.Helpers
Imports Aspose.Cells

Partial Class ProjectReport
    Inherits Page

    Dim currentUser As AMCOSUser
    Dim currentProject As PMProject
    Dim gradeLevelColumnIndex As Integer
    Dim exceedsSalaryLimitColumnIndex As Integer
    Dim appropriationColumnIndex As Integer
    Dim costElementNameColumnIndex As Integer
    Dim showOrderColumnIndex As Integer

    Public ReadOnly amcosVersionId As Integer = CInt(AppSettings("AmcosVersionId"))
    Public ReadOnly cceMaxPayFootnote As Integer = CInt(SingleValue.Get("CCE", "MaxPayFootnote", amcosVersionId))
    Public _discountFactor(5) As Decimal
    Public _discountFactorTable As DataTable
    Public _projectStartYear As Decimal
    Public _ccePayLimit As Decimal
    Public _cceBenefitRatio As Decimal
    Public _cceOverheadPercent As Decimal
    Public ReadOnly Property ProjectId() As Integer = Convert.ToInt32(Context.Request.QueryString("ProjectId"))
    Private Sub GetDiscountRate()
        Dim discountYears() As Integer = {3, 5, 7, 10, 20, 30}
        _discountFactorTable = New DataTable
        _discountFactorTable.Columns.Add(New DataColumn("Project Year: ", GetType(String)))
        For projectYear As Integer = 0 To currentProject.YearDuration - 1
            _discountFactorTable.Columns.Add(New System.Data.DataColumn((currentProject.YearStart + projectYear).ToString, GetType(String)))
        Next

        ' Find the proper Years / discount factor to use, set default to the last 30 Year rate
        Dim dblRate As Double = _discountFactor(_discountFactor.Length - 1)
        lblYearForTheDiscount.Text = "30"
        For i As Integer = 0 To discountYears.Length - 1
            If currentProject.YearDuration <= discountYears(i) Then
                dblRate = _discountFactor(i)
                lblYearForTheDiscount.Text = discountYears(i).ToString
                Exit For
            End If
        Next
        ' Get the present value factors
        Dim drRow As System.Data.DataRow = _discountFactorTable.NewRow
        drRow(0) = "PVF: "
        For iYear As Integer = 1 To currentProject.YearDuration
            Dim dVal As Double = 1.0 / (1 + dblRate / 100) ^ (iYear - 0.5)
            drRow(iYear) = "0" + dVal.ToString("#.#####")
        Next
        _discountFactorTable.Rows.Add(drRow)

        Session("discountFactorTable") = _discountFactorTable
    End Sub
    Protected Sub Page_Load(ByVal sender As Object, ByVal e As System.EventArgs) Handles Me.Load
        If Not HttpContext.Current.User.Identity.IsAuthenticated Then
            ' Set the response status to 401 Unauthorized.
            HttpContext.Current.Response.StatusCode = 401
            HttpContext.Current.Response.StatusDescription = "Unauthorized"

            ' End the request. The middleware will catch the 401 and handle the redirect.
            HttpContext.Current.ApplicationInstance.CompleteRequest()
            Return ' Stop further execution in this subroutine
        Else
            currentUser = UserAdministration.GetCurrentUser(CType(HttpContext.Current.User.Identity, Security.Claims.ClaimsIdentity))
            If currentUser Is Nothing Then
                ' The user IS authenticated, but not found in our system.
                ' 403 Forbidden is more appropriate than 401 Unauthorized here.
                HttpContext.Current.Response.StatusCode = 403
                HttpContext.Current.Response.StatusDescription = "Forbidden: User not found in application"

                ' End the request.
                HttpContext.Current.ApplicationInstance.CompleteRequest()
                Return ' Stop further execution
            End If
        End If

        Dim selectedPayPlans As String = ""
        If Not (Session("PayPlansInReport") Is Nothing) Then
            selectedPayPlans = Session("PayPlansInReport").ToString.Replace("'", "")
        End If
        Dim dtRate As DataTable = DataAccessUtility.GetDataTableByStaticSql("SELECT * FROM web.GetPMReportInflationRateHeader(@ProjectId, @AmcosVersionId);", {"@ProjectId", "@AmcosVersionId"}, {ProjectId, amcosVersionId})
        InflationGridView.DataSource = dtRate.DefaultView
        InflationGridView.DataBind()
        Session("dvForExportPart0") = dtRate

        Dim project As New Project
        currentProject = project.GetProject(ProjectId)
        Dim projectManagerDiscountFactors As DiscountFactor = project.GetDiscountFactors(amcosVersionId)
        _discountFactor(0) = projectManagerDiscountFactors.DiscountFactorYear3
        _discountFactor(1) = projectManagerDiscountFactors.DiscountFactorYear5
        _discountFactor(2) = projectManagerDiscountFactors.DiscountFactorYear7
        _discountFactor(3) = projectManagerDiscountFactors.DiscountFactorYear10
        _discountFactor(4) = projectManagerDiscountFactors.DiscountFactorYear20
        _discountFactor(5) = projectManagerDiscountFactors.DiscountFactorYear30
        _projectStartYear = SingleValue.Get("ALL", "ProjectManager_StartYear", amcosVersionId)

        If IsPostBack Then
            Exit Sub
        End If

        Dim sPayPlans As String = CType(Session("PayPlansInReport"), String)

        ' Discount rates
        GetDiscountRate()
        gvDiscountRates.DataSource = _discountFactorTable
        gvDiscountRates.DataBind()

        ' Inventory
        Dim dtInv As DataTable = DataAccessUtility.ExecuteStoredProcDataSet("web.PMProjectInventory", {"@ProjectId"}, {SqlDbType.Int}, {ProjectId}).Tables(0)
        Dim sortOrder As String = "PMCategoryName, [UIC], PayPlan, CategoryGroupCode, CategorySubgroupCode, Grade"
        gvProjectInventory.DataSource = New DataView(dtInv, "", sortOrder, DataViewRowState.CurrentRows)
        gvProjectInventory.DataBind()

        Dim projectManagerReportDataSet As DataSet = DataAccessUtility.ExecuteStoredProcDataSet("web.PMReport", {"@ProjectId", "@AmcosVersionId"}, {SqlDbType.Int, SqlDbType.Int}, {ProjectId, amcosVersionId})

        Dim dtD As DataTable = projectManagerReportDataSet.Tables(0).Copy
        dtD = project.UpdateLocationDisplay(dtD)
        'dtD = project.UpdateActiveDutyDaysDisplay(dtD)

        Dim HasMultipleSubprojects As Boolean = False
        For i As Integer = 1 To dtD.Rows.Count - 1
            If dtD.Rows(i)(0).ToString <> dtD.Rows(0)(0).ToString Then
                HasMultipleSubprojects = True
                Exit For
            End If
        Next

        SetColumnIndexes(dtD)

        Dim sSort As String = "[Sub-Project Name],UIC,PayPlan,[Category Group],[Category Subgroup],Location,GradeLevel,ShowOrder"

        ' Update ShowOrder values based on the entire sorting sequence by a temp table
        Dim dtD2 As DataTable = dtD.Clone
        Dim dv As DataView = New DataView(dtD, "", sSort, DataViewRowState.CurrentRows)
        For i As Integer = 0 To dv.Count - 1
            dtD2.ImportRow(dv.Item(i).Row)
            dtD2.Rows(i)("ShowOrder") = i * 10
        Next
        dtD = dtD2

        Dim pmCategoryNames As DataTable = DataAccessUtility.GetDataTableByStaticSql("select CategoryName from webuser.PMCategory where ProjectID=@pid", {"@pid"}, {ProjectId})
        Dim categoryCount As Integer = 0

        Dim sqlWhereClause As String
        For Each pmCategory As DataRow In pmCategoryNames.Rows
            Dim categoryName As String = Replace(pmCategory(0).ToString, "'", "''")
            If dtD.Select("[Sub-Project Name]='" & categoryName & "'").Length > 0 Then
                categoryCount += 1
                Dim iMaxSeq As Integer = CType(dtD.Compute("max(ShowOrder)", "[Sub-Project Name]='" & categoryName & "'"), Integer)

                sqlWhereClause = "[Sub-Project Name]='" + categoryName + "' and ( (PayPlan in ('AE','AO','AWO') and APPN in ('MPA', 'MPA Non-Pay', 'OMA', 'OMA_1')) " +
                                                          "or (PayPlan in ('DB','DE','DJ','DK','GG','GL','GS','GP','NH','NJ','NK','SES','WG','WL','WS') and (APPN like 'ARMY%' or APPN like 'Army%' or APPN='OMA')) )"
                If dtD.Select(sqlWhereClause).Length > 0 Then
                    AddSubTotalRow(dtD, sqlWhereClause, "ARMY APPN Total: ", iMaxSeq + 1)
                End If

                sqlWhereClause = String.Format("[Sub-Project Name]='{0}' and APPN like 'OMDW%'", categoryName)
                If dtD.Select(sqlWhereClause).Length > 0 Then
                    AddSubTotalRow(dtD, sqlWhereClause, "DoD APPN Total: ", iMaxSeq + 2)
                End If

                sqlWhereClause = String.Format("[Sub-Project Name]='{0}' and (APPN LIKE 'Federal%')", categoryName)
                If dtD.Select(sqlWhereClause).Length > 0 Then
                    AddSubTotalRow(dtD, sqlWhereClause, "FEDERAL APPN Total: ", iMaxSeq + 3)
                End If

                sqlWhereClause = String.Format("[Sub-Project Name]='{0}' and PayPlan in ('NE','NO','NWO', 'RE','RO','RWO') and APPN like '%PA%'", categoryName)
                If dtD.Select(sqlWhereClause).Length > 0 Then
                    AddSubTotalRow(dtD, sqlWhereClause, "PA APPN Total: ", iMaxSeq + 4)
                End If

                sqlWhereClause = String.Format("[Sub-Project Name]='{0}' and PayPlan in ('NE','NO','NWO', 'RE','RO','RWO') and APPN like '%OM%'", categoryName)
                If dtD.Select(sqlWhereClause).Length > 0 Then
                    AddSubTotalRow(dtD, sqlWhereClause, "OM APPN Total: ", iMaxSeq + 5)
                End If

                sqlWhereClause = String.Format("[Sub-Project Name]='{0}' and APPN like 'Contractor%'", categoryName)
                If dtD.Select(sqlWhereClause).Length > 0 Then
                    AddSubTotalRow(dtD, sqlWhereClause, "Contractor APPN Total: ", iMaxSeq + 6)
                End If

                sqlWhereClause = String.Format("[Sub-Project Name]='{0}' and APPN<>''", categoryName)
                AddSubTotalRow(dtD, sqlWhereClause, "Sub-Project Total: ", iMaxSeq + 8)
                If HasMultipleSubprojects = True Then
                    AddSubTotalRow(dtD, "", "Divider Line", iMaxSeq + 9)
                End If
            End If
        Next

        Dim MaxShowOrder As Integer = 0
        Dim maxObject As Object
        maxObject = dtD.Compute("MAX(ShowOrder)", "")

        If Not DBNull.Value.Equals(maxObject) Then
            MaxShowOrder = Convert.ToInt32(maxObject)
        End If

        Dim rows() As DataRow = dtD.Select("ShowOrder=" & MaxShowOrder)

        If rows.Count > 0 Then
            If HasMultipleSubprojects = True Then
                rows(0)(0) = "LastDividerLine"
            End If
        End If

        If categoryCount = 1 Then
            ' Show the grand total line the same as project total
            For columnIndex As Integer = 0 To dtD.Columns.Count - 2
                If IsNumeric(dtD.Columns(columnIndex).ColumnName) Then
                    If rows.Count > 0 Then
                        rows(0)(columnIndex) = dtD.Compute("sum([" + dtD.Columns(columnIndex).ColumnName + "])", "APPN<>''")
                    End If
                End If
            Next
        Else ' if there are multiple subprojects (categories), add the Totals of all projects at the end:
            MaxShowOrder = MaxShowOrder * 10
            sqlWhereClause = "[Cost Element]='ARMY APPN Total: '"
            If dtD.Select(sqlWhereClause).Length > 0 Then
                AddSubTotalRow(dtD, sqlWhereClause, "Total of all ARMY APPNs : ", MaxShowOrder + 1)
            End If

            sqlWhereClause = "[Cost Element]='DoD APPN Total: '"
            If dtD.Select(sqlWhereClause).Length > 0 Then
                AddSubTotalRow(dtD, sqlWhereClause, "Total of all DoD APPNs : ", MaxShowOrder + 2)
            End If

            sqlWhereClause = "[Cost Element]='FEDERAL APPN Total: '"
            If dtD.Select(sqlWhereClause).Length > 0 Then
                AddSubTotalRow(dtD, sqlWhereClause, "Total of all FEDERAL APPNs: ", MaxShowOrder + 3)
            End If

            sqlWhereClause = "[Cost Element]='PA APPN Total: '"
            If dtD.Select(sqlWhereClause).Length > 0 Then
                AddSubTotalRow(dtD, sqlWhereClause, "Total of all PA APPNs: ", MaxShowOrder + 4)
            End If

            sqlWhereClause = "[Cost Element]='OM APPN Total: '"
            If dtD.Select(sqlWhereClause).Length > 0 Then
                AddSubTotalRow(dtD, sqlWhereClause, "Total of all OM APPNs: ", MaxShowOrder + 5)
            End If

            sqlWhereClause = "[Cost Element]='Contractor APPN Total: '"
            If dtD.Select(sqlWhereClause).Length > 0 Then
                AddSubTotalRow(dtD, sqlWhereClause, "Total of all Contractor APPNs: ", MaxShowOrder + 6)
            End If

            AddSubTotalRow(dtD, "[Cost Element] like 'Total of all %'", "Total of All APPNs: ", MaxShowOrder + 8)
        End If

        _ccePayLimit = CType(projectManagerReportDataSet.Tables(2).Rows(0)(0), Decimal)
        _cceBenefitRatio = CType(projectManagerReportDataSet.Tables(2).Rows(0)(1), Decimal)
        _cceOverheadPercent = CType(projectManagerReportDataSet.Tables(2).Rows(0)(2), Decimal)

        If dtD.Rows.Count = 0 Then
            lblUndiscounted_Default.Visible = False
            lblDiscounted_Default.Visible = False
            gvUndiscounted_Default.Visible = False
            gvDiscounted_Default.Visible = False
        Else
            For Each row As DataRow In dtD.Rows
                If row("Grade").ToString = "SES1" Then
                    row("Grade") = "MIN"
                End If

                If row("Grade").ToString = "SES2" Then
                    row("Grade") = "AVG"
                End If

                If row("Grade").ToString = "SES3" Then
                    row("Grade") = "MAX"
                End If
            Next

            lblUndiscounted_Default.Visible = True
            gvUndiscounted_Default.Visible = True
            gvUndiscounted_Default.DataSource = New DataView(dtD, "", "ShowOrder", DataViewRowState.CurrentRows)
            gvUndiscounted_Default.DataBind()

            lblDiscounted_Default.Visible = True
            gvDiscounted_Default.Visible = True
            gvDiscounted_Default.DataSource = New DataView(dtD, "", "ShowOrder", DataViewRowState.CurrentRows)
            gvDiscounted_Default.DataBind()
        End If

        litNoteSpecialPay.Visible = (sPayPlans.IndexOf("AE") > 0 Or sPayPlans.IndexOf("AO") > 0 Or sPayPlans.IndexOf("AWO") > 0)

        If litNoteSpecialPay.Visible Then
            litNoteSpecialPay.Text = "<h3 style=""color:Navy"">**NOTE - Cost Values are not inflated for the ""Average Cost of Special Pays"".</h3>"
        End If

        Session("dvForExportPart1") = dtD
    End Sub
    Private Sub AddSubTotalRow(ByRef dtD As DataTable, WhereClause As String, sTotalName As String, ShowOrder As Integer)
        Dim drNew As DataRow = dtD.NewRow
        For columnIndex As Integer = 0 To dtD.Columns.Count - 1
            If IsNumeric(dtD.Columns(columnIndex).ColumnName) Then
                If sTotalName = "Divider Line" Then
                    drNew(columnIndex) = 0
                Else
                    drNew(columnIndex) = dtD.Compute("SUM([" + dtD.Columns(columnIndex).ColumnName + "])", WhereClause)
                End If
            ElseIf dtD.Columns(columnIndex).ColumnName = "Cost Element" Then
                drNew(columnIndex) = sTotalName
            ElseIf dtD.Columns(columnIndex).ColumnName = "ExceedsSalaryLimit" Then
                'Do nothing
            Else
                'drNew(columnIndex) = ""
            End If
        Next
        drNew(showOrderColumnIndex) = ShowOrder
        dtD.Rows.Add(drNew)
    End Sub
    Protected Sub SqlDataReportSelection_Selecting(ByVal sender As Object, ByVal e As SqlDataSourceCommandEventArgs) Handles SqlDataReportSelection.Selecting
        e.Command.Parameters("@ProjectId").Value = ProjectId
    End Sub
    Protected Sub odsRepProjectDetails_Selecting(ByVal sender As Object, ByVal e As ObjectDataSourceMethodEventArgs) Handles odsRepProjectDetails.Selecting
        e.InputParameters.Item("ProjectID") = ProjectId
    End Sub
    Protected Sub gvProjectInventory_RowDataBound(ByVal sender As Object, ByVal e As System.Web.UI.WebControls.GridViewRowEventArgs) Handles gvProjectInventory.RowDataBound
        Dim oRow As GridViewRow = e.Row
        If oRow.RowType = DataControlRowType.Header Then
            For Each oCell As TableCell In oRow.Cells
                If IsNumeric(oCell.Text) Then
                    oCell.Text = CType(CInt(oCell.Text) + currentProject.YearStart, String)
                End If

                If oCell.Text = "PMCategoryName" Then
                    oCell.Text = "Sub-Project Name"
                End If

                If oCell.Text = "Uic" Then
                    oCell.Text = "UIC"
                End If

                If oCell.Text = "activeDays" Then
                    oCell.Text = "NG/Res ADT"
                End If

                If oCell.Text = "overheadPct" Then
                    oCell.Text = "Overhead %"
                End If
            Next
        ElseIf oRow.RowType = DataControlRowType.DataRow Then
            For Each oCell As TableCell In oRow.Cells
                If oCell.Text = "SES1" Then oCell.Text = "MIN"
                If oCell.Text = "SES2" Then oCell.Text = "AVG"
                If oCell.Text = "SES3" Then oCell.Text = "MAX"
            Next
        End If
    End Sub
    Protected Sub gvUndiscounted_Default_RowCreated(sender As Object, e As System.Web.UI.WebControls.GridViewRowEventArgs) Handles gvUndiscounted_Default.RowCreated, gvDiscounted_Default.RowCreated
        e.Row.Cells(gradeLevelColumnIndex).Visible = False
        e.Row.Cells(showOrderColumnIndex).Visible = False
    End Sub
    Protected Sub gvUndiscounted_Default_RowDataBound(sender As Object, e As System.Web.UI.WebControls.GridViewRowEventArgs) Handles gvUndiscounted_Default.RowDataBound, gvDiscounted_Default.RowDataBound ', gvUndiscounted_OsdCapeDodi.RowDataBound, gvDiscounted_OsdCapeDodi.RowDataBound

        Dim appropriation As Appropriation = New Appropriation()
        Dim gvID As String = CType(sender, GridView).ID

        'Hide the CCEExceedsSalaryLimit column
        If exceedsSalaryLimitColumnIndex <> -1 Then
            e.Row.Cells(exceedsSalaryLimitColumnIndex).Visible = False
        End If

        If e.Row.RowType = DataControlRowType.DataRow Then
            Dim discountFactorYearIndex As Integer = 1
            Dim isCCERow As Boolean = False
            Dim isCCESalaryRow As Boolean = False
            Dim isCCEBenefitsRow As Boolean = False
            Dim isCCEOverheadRow As Boolean = False
            Dim isCCEOverSalaryLimit As Boolean = False

            For currentColumnIndex As Integer = 0 To e.Row.Cells.Count - 1
                Dim oCell As TableCell = e.Row.Cells(currentColumnIndex)
                If oCell.Text.IndexOf(" MMPA") > 0 Then
                    oCell.Text = oCell.Text.Replace(" MMPA", " PA")
                End If

                If oCell.Text = "CCE" Then isCCERow = True
                If isCCERow And oCell.Text.IndexOf("Salary") > 0 Then
                    isCCESalaryRow = True
                End If

                If isCCERow And oCell.Text.IndexOf("Benefit") > 0 Then
                    isCCEBenefitsRow = True
                End If

                If isCCERow And oCell.Text.IndexOf("Overhead") > 0 Then
                    isCCEOverheadRow = True
                End If

                If isCCERow And oCell.Text.IndexOf("CCE_") >= 0 Then
                    oCell.Text = oCell.Text.Substring(5) ' for proper sorting
                End If

                If isCCERow And oCell.Text.IndexOf("CCEA_") >= 0 Then
                    oCell.Text = oCell.Text.Substring(3) ' for proper sorting
                End If

                If oCell.Text = "Avg Cost of Special Pays" Then
                    oCell.ToolTip = "Note: the cost value of this element is NOT inflated"
                    oCell.Text = "**" + oCell.Text
                End If

                If currentColumnIndex = exceedsSalaryLimitColumnIndex And oCell.Text = "1" Then
                    isCCEOverSalaryLimit = True
                    cceSalaryOverLimitNoteUndiscounted.Visible = True
                    cceSalaryOverLimitNoteDiscounted.Visible = True
                End If

                'Format the cost columns
                If currentColumnIndex > showOrderColumnIndex Then
                    Dim costElementAmount As Decimal = CType(oCell.Text, Decimal)
                    If gvID.StartsWith("gvD") Then
                        If isCCERow And isCCEOverSalaryLimit Then
                            If isCCESalaryRow Then
                                oCell.Text = String.Format("{0}", FormatCurrency(_ccePayLimit * CType(_discountFactorTable.Rows(0)(1), Decimal)))
                                oCell.BackColor = Color.Yellow
                            End If
                            If isCCEBenefitsRow Then
                                oCell.Text = String.Format("{0}", FormatCurrency(_ccePayLimit * CType(_discountFactorTable.Rows(0)(1), Decimal) * _cceBenefitRatio))
                                oCell.BackColor = Color.Yellow
                            End If
                            If isCCEOverheadRow Then
                                oCell.Text = String.Format("{0}", FormatCurrency(_ccePayLimit * CType(_discountFactorTable.Rows(0)(1), Decimal) * _cceOverheadPercent / 100))
                                oCell.BackColor = Color.Yellow
                            End If
                        Else
                            oCell.Text = FormatCurrency(costElementAmount * CType(_discountFactorTable.Rows(0)(discountFactorYearIndex), Decimal))
                        End If
                    Else
                        If isCCERow And isCCEOverSalaryLimit Then
                            If isCCESalaryRow Then
                                oCell.Text = String.Format("{0}", FormatCurrency(_ccePayLimit))
                                oCell.BackColor = Color.Yellow
                            End If
                            If isCCEBenefitsRow Then
                                oCell.Text = String.Format("{0}", FormatCurrency(_ccePayLimit * _cceBenefitRatio))
                                oCell.BackColor = Color.Yellow
                            End If
                            If isCCEOverheadRow Then
                                oCell.Text = String.Format("{0}", FormatCurrency(_ccePayLimit * _cceOverheadPercent / 100))
                                oCell.BackColor = Color.Yellow
                            End If
                        Else
                            oCell.Text = FormatCurrency(costElementAmount)
                        End If
                    End If

                    oCell.Style.Add(HtmlTextWriterStyle.TextAlign, "Right")
                    discountFactorYearIndex = discountFactorYearIndex + 1
                End If

                If currentColumnIndex = appropriationColumnIndex Then
                    Select Case oCell.Text.Trim
                        Case "ARMY CivPay", "Army CivPay", "MPA", "MPA Non-Pay", "OMA", "OMA_1"
                            oCell.BackColor = appropriation.ColorSumArmy
                            oCell.ForeColor = Color.White
                        Case "DoD OMA", "OMDW"
                            oCell.BackColor = appropriation.ColorSumDOD
                            oCell.ForeColor = Color.White
                        Case "FEDERAL OMA", "Federal OM"
                            oCell.BackColor = appropriation.ColorSumFed
                            oCell.ForeColor = Color.White
                        Case "NG OM", "NG OM_1", "NG PA", "NGPA", "OMNG", "OMNG_1"
                            oCell.BackColor = appropriation.ColorARNGOM
                            oCell.ForeColor = Color.White
                        Case "RES OM", "RES OM_1", "RES PA", "RPA", "OMAR", "OMAR_1"
                            oCell.BackColor = appropriation.ColorUSAROM
                            oCell.ForeColor = Color.White
                        Case "Contractor"
                            oCell.BackColor = appropriation.ColorCCE
                            oCell.ForeColor = Color.White
                    End Select
                End If
            Next

            'Process total lines
            Dim lastDigitOfShowOrder As String = Right(Trim(e.Row.Cells(showOrderColumnIndex).Text), 1)

            If lastDigitOfShowOrder <> "0" Then
                'Columns to the left of the cost columns
                For i As Integer = 0 To costElementNameColumnIndex - 1
                    e.Row.Cells(i).ForeColor = Color.White
                    e.Row.Cells(i).BackColor = Color.White
                Next

                'The cost columns
                For i As Integer = costElementNameColumnIndex To e.Row.Cells.Count - 1
                    e.Row.Cells(i).Font.Bold = True
                    e.Row.Cells(i).ForeColor = Color.White
                    Select Case lastDigitOfShowOrder
                        Case "1"
                            e.Row.Cells(i).BackColor = appropriation.ColorSumArmy
                        Case "2"
                            e.Row.Cells(i).BackColor = appropriation.ColorSumDOD
                        Case "3"
                            e.Row.Cells(i).BackColor = appropriation.ColorSumFed
                        Case "4"
                            e.Row.Cells(i).BackColor = appropriation.ColorARNGOM
                        Case "5"
                            e.Row.Cells(i).BackColor = appropriation.ColorUSAROM
                        Case "6"
                            e.Row.Cells(i).BackColor = appropriation.ColorCCE
                        Case "8"
                            e.Row.Cells(i).BackColor = Color.LightGray
                            e.Row.Cells(i).ForeColor = Color.Black
                        Case "9"
                            e.Row.Cells(i).BackColor = Color.Black
                            If IsNumeric(e.Row.Cells(i).Text) AndAlso e.Row.Cells(i).Text <> "$0.00" Then
                                e.Row.Cells(i).ForeColor = Color.White
                            Else
                                e.Row.Cells(i).ForeColor = Color.Black
                                e.Row.Cells(i).Text = ""
                            End If
                    End Select
                Next

                'Description should be aligned right
                e.Row.Cells(costElementNameColumnIndex).HorizontalAlign = HorizontalAlign.Right

                If lastDigitOfShowOrder = "9" Then
                    If e.Row.Cells(0).Text = "LastDividerLine" Then
                        e.Row.Cells(0).Text = ""
                        e.Row.Cells(costElementNameColumnIndex).Text = "TOTAL APPN COST SUMMARY: "

                        e.Row.Cells(costElementNameColumnIndex).HorizontalAlign = HorizontalAlign.Left
                        e.Row.Cells(costElementNameColumnIndex).ForeColor = Color.White
                        e.Row.Cells(costElementNameColumnIndex).Font.Bold = True
                        e.Row.Cells(costElementNameColumnIndex).Style.Add("font-size", "larger")
                    Else
                        e.Row.Cells(0).Text = "BEGINNING OF SUB-PROJECT: "
                        e.Row.Cells(0).Font.Bold = True
                        e.Row.Cells(0).Style.Add("font-size", "larger")
                        e.Row.Cells(0).ForeColor = Color.White
                        e.Row.Cells(0).BackColor = Color.Black

                        e.Row.Cells(0).ColumnSpan = e.Row.Cells.Count
                        For i As Integer = e.Row.Cells.Count - 1 To 1 Step -1
                            e.Row.Cells.RemoveAt(i)
                        Next
                    End If
                End If
            End If
        End If

    End Sub
    Private Function GetProperCostDataTable(ByRef dtD As DataTable) As DataTable

        For Each dr As DataRow In dtD.Rows
            For i As Integer = 0 To dtD.Columns.Count - 2
                If dr(i).ToString.IndexOf(" MMPA") > 0 Then
                    dr(i) = dr(i).ToString.Replace(" MMPA", " PA")
                End If

                If dr(i).ToString = "Avg Cost of Special Pays" Then
                    dr(i) = "**" & dr(i).ToString
                End If
            Next

            Dim lastDigitOfSeqNo As String = dr(showOrderColumnIndex).ToString
            If lastDigitOfSeqNo = "9" Then
                If dr(0).ToString = "LastDividerLine" Then
                    dr(0) = ""
                    dr(costElementNameColumnIndex) = "TOTAL APPN COST SUMMARY: "
                Else
                    dr(0) = "BEGINNING OF SUB-PROJECT: "
                End If
            End If
        Next
        Return dtD
    End Function
    Private Sub SetColumnIndexes(ByRef dtD As DataTable)
        gradeLevelColumnIndex = dtD.Columns.IndexOf("GradeLevel")
        exceedsSalaryLimitColumnIndex = dtD.Columns.IndexOf("ExceedsSalaryLimit")
        appropriationColumnIndex = dtD.Columns.IndexOf("APPN")
        costElementNameColumnIndex = dtD.Columns.IndexOf("Cost Element")
        showOrderColumnIndex = dtD.Columns.IndexOf("ShowOrder")
    End Sub
    Protected Sub ibDownloadExcel_Click(ByVal sender As Object, ByVal e As System.Web.UI.ImageClickEventArgs) Handles ibDownloadExcel.Click

        Dim appropriation As Appropriation = New Appropriation()
        Dim dtD As DataTable = GetProperCostDataTable(CType(Session("dvForExportPart1"), DataTable))
        SetColumnIndexes(dtD)

        For Each dr As DataRow In dtD.Rows
            If dr("Grade").ToString.IndexOf("CCEA_") >= 0 Then
                dr("Grade") = dr("Grade").ToString.Substring(3)
            End If

            If dr("Cost Element").ToString.IndexOf("CCE_") >= 0 Then
                dr("Cost Element") = dr("Cost Element").ToString.Substring(5)
            End If

        Next

        Dim license As Aspose.Cells.License = New Aspose.Cells.License()
        license.SetLicense("Aspose.Cells.lic")

        Dim wb As New Workbook()
        Dim ws As Worksheet = wb.Worksheets(0)
        Dim dv As DataView
        Dim style As Style
        Dim styleFlag As StyleFlag

        'Export the discounted Cost grid 
        dv = New DataView(dtD, "", "ShowOrder", DataViewRowState.CurrentRows)
        Dim columnCountDataTable As Integer = dv.Table.Columns.Count
        Dim columnCountWorksheet As Integer = columnCountDataTable

        ws.Cells.ImportDataView(dv, True, 0, 0, True)

        'set header row style
        style = wb.CreateStyle()
        style.Borders(BorderType.TopBorder).LineStyle = CellBorderType.Thin
        style.Borders(BorderType.BottomBorder).LineStyle = CellBorderType.Thin
        style.Borders(BorderType.LeftBorder).LineStyle = CellBorderType.Thin
        style.Borders(BorderType.RightBorder).LineStyle = CellBorderType.Thin
        style.Number = 0
        style.Font.IsBold = True
        style.Font.Color = Color.White
        style.ForegroundColor = Color.Black
        style.Pattern = BackgroundType.Solid
        style.ShrinkToFit = True
        style.HorizontalAlignment = TextAlignmentType.Center

        styleFlag = New StyleFlag With {
            .Borders = True,
            .FontBold = True,
            .FontColor = True,
            .CellShading = True,
            .HorizontalAlignment = True,
            .NumberFormat = True
        }

        'set header row style
        ws.Cells.CreateRange(0, 0, 1, columnCountWorksheet).ApplyStyle(style, styleFlag)

        'set all grid lines
        style.Font.IsBold = False
        style.Font.Color = Color.Black
        style.ForegroundColor = Color.White
        style.HorizontalAlignment = TextAlignmentType.Left
        ws.Cells.CreateRange(1, 0, dv.Count, showOrderColumnIndex + 1).ApplyStyle(style, styleFlag)

        'the number columns right alignment
        style.HorizontalAlignment = TextAlignmentType.Right
        style.Number = 7
        ws.Cells.CreateRange(1, showOrderColumnIndex + 1, dv.Count, dtD.Columns.Count - showOrderColumnIndex - 1).ApplyStyle(style, styleFlag)

        'set the APPN column colors
        style.Font.IsBold = True
        style.Font.Color = Color.White
        style.ForegroundColor = Color.Black
        style.HorizontalAlignment = TextAlignmentType.Left
        For i As Integer = 1 To dv.Count
            'If ws.Cells(i, appropriationColumnIndex).Value.ToString IsNot Nothing Then
            If ws.Cells.Rows(i).GetCellOrNull(appropriationColumnIndex).Value IsNot Nothing Then
                Dim appropriationColor As Color = appropriation.GetAppropriationColor(ws.Cells(i, appropriationColumnIndex).Value.ToString)
                style.ForegroundColor = appropriationColor
                ws.Cells(i, appropriationColumnIndex).SetStyle(style)
            End If


        Next

        'set the _CostElementCol column  color for Total lines
        For rowIndex As Integer = 1 To dv.Count
            Dim sLastDigitOfSeqNo As String = ws.Cells(rowIndex, showOrderColumnIndex).Value.ToString
            sLastDigitOfSeqNo = sLastDigitOfSeqNo.Substring(sLastDigitOfSeqNo.Length - 1)

            If sLastDigitOfSeqNo <> "0" Then
                style.Font.IsBold = True
                style.Font.Color = Color.White
                style.HorizontalAlignment = TextAlignmentType.Right
                Select Case sLastDigitOfSeqNo
                    Case "1"
                        style.ForegroundColor = appropriation.ColorSumArmy
                    Case "2"
                        style.ForegroundColor = appropriation.ColorSumDOD
                    Case "3"
                        style.ForegroundColor = appropriation.ColorSumFed
                    Case "4"
                        style.ForegroundColor = appropriation.ColorARNGOM
                    Case "5"
                        style.ForegroundColor = appropriation.ColorUSAROM
                    Case "6"
                        style.ForegroundColor = appropriation.ColorCCE
                    Case "8"
                        style.ForegroundColor = Color.LightGray
                        style.Font.Color = Color.Black
                    Case "9"
                        style.ForegroundColor = Color.Black
                        style.Font.Color = Color.White
                        style.HorizontalAlignment = TextAlignmentType.Left

                        If ws.Cells(rowIndex, 0).Value.ToString = "LastDividerLine" Then
                            ws.Cells(rowIndex, 0).Value = ""
                            ws.Cells(rowIndex, costElementNameColumnIndex).Value = "TOTAL APPN COST SUMMARY: "
                            ws.Cells.CreateRange(rowIndex, costElementNameColumnIndex, 1, dtD.Columns.Count - costElementNameColumnIndex - 1).ApplyStyle(style, styleFlag)
                            For j As Integer = costElementNameColumnIndex + 1 To dtD.Columns.Count - 1
                                ws.Cells(rowIndex, j).Value = ""
                            Next
                        Else
                            ws.Cells(rowIndex, 0).Value = "BEGINNING OF SUB-PROJECT: "
                            ws.Cells.CreateRange(rowIndex, 0, 1, dtD.Columns.Count - 1).ApplyStyle(style, styleFlag)
                            For j As Integer = costElementNameColumnIndex To dtD.Columns.Count - 1
                                ws.Cells(rowIndex, j).Value = ""
                            Next
                        End If
                        ' for CCE
                        '    If IsNumeric(e.Row.Cells(i).Text) AndAlso e.Row.Cells(i).Text <> "$0.00" Then
                        '        e.Row.Cells(i).ForeColor = Drawing.Color.White
                        '    Else
                        '        e.Row.Cells(i).ForeColor = Drawing.Color.Black
                        '        e.Row.Cells(i).Text = ""
                        '    End If
                End Select
                ws.Cells(rowIndex, costElementNameColumnIndex).SetStyle(style)
                ' format the cost numbers
                For j As Integer = showOrderColumnIndex + 1 To dtD.Columns.Count - 1
                    If IsNumeric(ws.Cells(rowIndex, j).Value) Then ws.Cells(rowIndex, j).SetStyle(style)
                Next
            End If
            'format the cost numbers
            For j As Integer = showOrderColumnIndex + 1 To dtD.Columns.Count - 1
                If IsNumeric(ws.Cells(rowIndex, j).Value) Then
                    If CInt(ws.Cells(rowIndex, exceedsSalaryLimitColumnIndex).Value) = 1 Then
                        style.Font.Color = Color.Black
                        style.ForegroundColor = Color.Yellow
                        style.HorizontalAlignment = TextAlignmentType.Right
                        ws.Cells(rowIndex, j).SetStyle(style)
                    End If
                    ws.Cells(rowIndex, j).Value = CType(ws.Cells(rowIndex, j).Value, Double)
                End If

            Next

        Next

        'Remove the grade level column
        ws.Cells.DeleteRange(0, gradeLevelColumnIndex, dv.Count, gradeLevelColumnIndex, Aspose.Cells.ShiftType.Left)
        exceedsSalaryLimitColumnIndex = exceedsSalaryLimitColumnIndex - 1
        appropriationColumnIndex = appropriationColumnIndex - 1
        costElementNameColumnIndex = costElementNameColumnIndex - 1
        showOrderColumnIndex = showOrderColumnIndex - 1
        columnCountWorksheet = columnCountWorksheet - 1

        'Remove the ExceedsSalaryLimit column
        ws.Cells.DeleteRange(0, exceedsSalaryLimitColumnIndex, dv.Count, exceedsSalaryLimitColumnIndex, Aspose.Cells.ShiftType.Left)
        appropriationColumnIndex = appropriationColumnIndex - 1
        costElementNameColumnIndex = costElementNameColumnIndex - 1
        showOrderColumnIndex = showOrderColumnIndex - 1
        columnCountWorksheet = columnCountWorksheet - 1

        'Remove the show order column
        ws.Cells.DeleteRange(0, showOrderColumnIndex, dv.Count, showOrderColumnIndex, Aspose.Cells.ShiftType.Left)
        columnCountWorksheet = columnCountWorksheet - 1

        ws.Cells.InsertRow(0)
        ws.Cells.InsertRow(0)
        ws.Cells.InsertRow(0)

        ws.Cells.CopyRows(ws.Cells, 0, dv.Count + 4, dv.Count + 4)

        ws.Cells(1, 0).Value = "Default Summary"
        ws.Cells(dv.Count + 5, 0).Value = "Discounted Default Summary"
        style.ForegroundColor = Color.White
        style.Font.Color = Color.Black
        style.Font.IsBold = True
        style.Font.IsItalic = True
        style.Font.Underline = Aspose.Cells.FontUnderlineType.Single
        style.Font.Size = 14
        style.Borders(BorderType.TopBorder).LineStyle = CellBorderType.None
        style.Borders(BorderType.BottomBorder).LineStyle = CellBorderType.None
        style.Borders(BorderType.LeftBorder).LineStyle = CellBorderType.None
        style.Borders(BorderType.RightBorder).LineStyle = CellBorderType.None

        style.HorizontalAlignment = TextAlignmentType.Left
        ws.Cells(1, 0).SetStyle(style)
        ws.Cells(dv.Count + 5, 0).SetStyle(style)

        'Discount the values
        _discountFactorTable = CType(Session("discountFactorTable"), DataTable)

        For rowIndexWorksheet As Integer = dv.Count + 8 To 2 * dv.Count + 7
            For columnIndexWorksheet As Integer = costElementNameColumnIndex + 1 To columnCountWorksheet - 1
                Dim discountFactor As Decimal = CType(_discountFactorTable.Rows(0)(columnIndexWorksheet - costElementNameColumnIndex), Decimal)
                Try
                    ws.Cells(rowIndexWorksheet, columnIndexWorksheet).Value = discountFactor * CDbl(ws.Cells(rowIndexWorksheet, columnIndexWorksheet).Value)
                Catch ex As Exception
                    ' do nothing, just for skipping the row of "Beginining Subproject"
                End Try
            Next
        Next

        ' ** NOTE line
        ws.Cells.InsertRow(0)
        ws.Cells.Merge(0, 0, 1, 9)
        ws.Cells(0, 0).Value = "**NOTE - Cost Values are not inflated for ""Average Cost of Special Pays""."
        style.ForegroundColor = Color.White
        style.Font.Color = Color.Black
        style.Font.IsBold = True
        style.Font.IsItalic = False
        style.Font.Underline = Aspose.Cells.FontUnderlineType.None
        style.Font.Size = 12
        style.Borders(BorderType.TopBorder).LineStyle = CellBorderType.None
        style.Borders(BorderType.BottomBorder).LineStyle = CellBorderType.None
        style.Borders(BorderType.LeftBorder).LineStyle = CellBorderType.None
        style.Borders(BorderType.RightBorder).LineStyle = CellBorderType.None

        style.HorizontalAlignment = TextAlignmentType.Left
        style.IsTextWrapped = True
        style.Number = 0 ' set to normal number format without $ any more
        ws.Cells(0, 0).SetStyle(style)

        ' NOTE: section
        ws.Cells.InsertRow(0)
        ws.Cells.InsertRow(0)
        ws.Cells.InsertRow(0)
        ws.Cells.InsertRow(0)
        ws.Cells.InsertRow(0)
        ws.Cells.InsertRow(0)
        ws.Cells.Merge(0, 0, 5, 19)
        ws.Cells(0, 0).SetStyle(style)
        Dim s As String = "NOTE: For analysts costing overseas positions, consider adding Civilian ""Discount Groceries (OCONUS Only)"" costs, if required, apply the following:" + vbCrLf
        s += "   " & Chr(149) + "  For the AMCOS base year, add Discount Groceries (OCONUS Only) costs found on the Full Cost of Manpower (FCoM) web site http://fcom.cape.osd.mil/." + vbCrLf
        s += "   " & Chr(149) + "  For future year ""Default Summary"" cost element projections, multiply the Discount Groceries Factor by the ""Civilian DoD OMA"" inflation factor for the desired year." + vbCrLf
        s += "   " & Chr(149) + "  For future year ""Discounted Default Summary"" cost element projections, multiply the Default Summary ""Discount Groceries (OCONUS Only)"" costs for the desired year by the corresponding year's Discounting and Present Value Factor (PVF). " + vbCrLf
        ws.Cells(0, 0).Value = s
        style.VerticalAlignment = TextAlignmentType.Top
        style.ShrinkToFit = True
        ws.Cells(0, 0).SetStyle(style)
        ws.Cells.InsertRow(0)

        ws.Cells.InsertRow(0)
        ws.Cells.Merge(0, 0, 1, 9)
        style.Font.IsBold = False
        ws.Cells(0, 0).Value = "NOTE: The highlighted field(s) indicate a value based on CCE salary greater than " & FormatCurrency(cceMaxPayFootnote, 2) & " per year.  The Contractor APPN Total sums the displayed CCE values but may be greater if your report includes highlighted cells."
        ws.Cells(0, 0).SetStyle(style)

        ' Cost Lines 2
        ws.Cells.InsertRow(0)
        ws.Cells.Merge(0, 0, 1, 9)
        style.Font.IsBold = False
        ws.Cells(0, 0).Value = "The Costing Reports are produced both with and without the discount rate the analyst inputs to the cost estimate."
        ws.Cells(0, 0).SetStyle(style)

        ws.Cells.InsertRow(0)
        ws.Cells.InsertRow(0)
        style.Font.IsBold = True
        style.Font.Size = 14
        ws.Cells(0, 0).SetStyle(style)
        ws.Cells(0, 0).Value = "Cost"

        ws.Cells.InsertRow(0)

        ' Inventory grid
        Dim importTableOptions As ImportTableOptions = New ImportTableOptions With {
            .InsertRows = True,
            .ConvertNumericData = False,
            .ConvertGridStyle = False
        }
        ws.Cells.ImportGridView(gvProjectInventory, 0, 0, importTableOptions)
        For i As Integer = 0 To gvProjectInventory.Rows.Count - 1
            For j As Integer = 0 To gvProjectInventory.HeaderRow.Cells.Count - 1
                If ws.Cells(i, j).Value Is Nothing Then ws.Cells(i, j).Value = ""
                If (IsNumeric(gvProjectInventory.HeaderRow.Cells(j).Text) Or gvProjectInventory.HeaderRow.Cells(j).Text = "Overhead %") AndAlso IsNumeric(ws.Cells(i, j).Value) Then ws.Cells(i, j).Value = CType(ws.Cells(i, j).Value, Integer)
            Next
        Next
        ws.Cells.InsertRow(0)
        For j As Integer = 0 To gvProjectInventory.HeaderRow.Cells.Count - 1
            ws.Cells(0, j).Value = gvProjectInventory.HeaderRow.Cells(j).Text
        Next
        style.Font.IsBold = False
        style.Font.Size = 10
        style.Borders(BorderType.TopBorder).LineStyle = CellBorderType.Thin
        style.Borders(BorderType.BottomBorder).LineStyle = CellBorderType.Thin
        style.Borders(BorderType.LeftBorder).LineStyle = CellBorderType.Thin
        style.Borders(BorderType.RightBorder).LineStyle = CellBorderType.Thin
        ws.Cells.CreateRange(1, 0, gvProjectInventory.Rows.Count, gvProjectInventory.HeaderRow.Cells.Count).ApplyStyle(style, styleFlag)
        style.Font.IsBold = True
        style.Font.Color = Color.White
        style.ForegroundColor = Color.Navy
        ws.Cells.CreateRange(0, 0, 1, gvProjectInventory.HeaderRow.Cells.Count).ApplyStyle(style, styleFlag)

        ws.Cells.InsertRow(0)
        ws.Cells.InsertRow(0)
        ws.Cells(0, 0).Value = "Inventory"
        style.Font.IsBold = True
        style.Font.Size = 14
        style.Borders(BorderType.TopBorder).LineStyle = CellBorderType.None
        style.Borders(BorderType.BottomBorder).LineStyle = CellBorderType.None
        style.Borders(BorderType.LeftBorder).LineStyle = CellBorderType.None
        style.Borders(BorderType.RightBorder).LineStyle = CellBorderType.None
        style.Font.Color = Color.Black
        style.ForegroundColor = Color.White
        ws.Cells(0, 0).SetStyle(style)

        ws.Cells.InsertRow(0)

        ' Discounting and Present Value Factor (PVF) section
        ws.Cells.ImportDataTable(_discountFactorTable, True, 0, 0, True)
        style.Font.Size = 10
        style.Borders(BorderType.TopBorder).LineStyle = CellBorderType.Thin
        style.Borders(BorderType.BottomBorder).LineStyle = CellBorderType.Thin
        style.Borders(BorderType.LeftBorder).LineStyle = CellBorderType.Thin
        style.Borders(BorderType.RightBorder).LineStyle = CellBorderType.Thin
        ws.Cells.CreateRange(0, 0, 1, _discountFactorTable.Columns.Count).ApplyStyle(style, styleFlag)
        For j As Integer = 1 To _discountFactorTable.Columns.Count - 1
            ws.Cells(1, j).Value = CType(ws.Cells(1, j).Value, Double)
        Next

        style.Font.IsBold = False
        ws.Cells.CreateRange(1, 0, 1, _discountFactorTable.Columns.Count).ApplyStyle(style, styleFlag)

        ws.Cells.InsertRow(0)
        ws.Cells(0, 0).Value = "Discount Rates Based on " & lblYearForTheDiscount.Text & " Years Securities:"
        style.Font.IsBold = True
        style.Borders(BorderType.TopBorder).LineStyle = CellBorderType.None
        style.Borders(BorderType.BottomBorder).LineStyle = CellBorderType.None
        style.Borders(BorderType.LeftBorder).LineStyle = CellBorderType.None
        style.Borders(BorderType.RightBorder).LineStyle = CellBorderType.None
        ws.Cells.Merge(0, 0, 1, 9)
        ws.Cells(0, 0).SetStyle(style)

        ws.Cells.InsertRow(0)
        ws.Cells.InsertRow(0)
        ws.Cells.Merge(0, 0, 1, 19)
        ws.Cells(0, 0).Value = "Most cost comparison techniques take into consideration the time value of money, that is, a dollar today is worth some amount less in the future. Discount rates are prepared annually by the Office of Management and Budget (OMB).  OMB Circular A-94 and Department of Defense Instruction (DoDI) 7041.3 require the use of a discount rate based on the Treasury Department cost of borrowing funds, and reflect the expected cost of borrowing for 3, 5, 7, 10, 20, and 30 years securities."

        ws.Cells.InsertRow(0)
        ws.Cells.InsertRow(0)
        ws.Cells(0, 0).Value = "Discounting and Present Value Factor (PVF)"
        style.Font.IsBold = True
        style.Font.Size = 14
        style.ShrinkToFit = True
        ws.Cells(0, 0).SetStyle(style)
        ws.Cells.InsertRow(0)

        ws.Cells.InsertRow(0)
        ws.Cells.InsertRow(0)
        ws.Cells.InsertRow(0)
        ws.Cells.InsertRow(0)
        ws.Cells.InsertRow(0)
        ws.Cells.Merge(0, 0, 5, 12)
        s = "The Project Start Year (YearStart) is set to " + _projectStartYear.ToString("#") + " and the number of years (YearDuration) is set to 5 years for costing an Active Duty position with the focus on ""SALARY"" cost element:" + vbCrLf
        s += "   " & Chr(149) + "  " + _projectStartYear.ToString("#") + " Active Duty Salary = (AMCOS LITE ""Avg Cost Base Pay (Military)"" BASE YEAR SALARY) * (" + _projectStartYear.ToString("#") + " Active Duty MPA Inflation Factor)" + vbCrLf
        s += "   " & Chr(149) + "  " + (_projectStartYear + 1).ToString("#") + " Active Duty Salary = (AMCOS LITE ""Avg Cost Base Pay (Military)"" BASE YEAR SALARY) * (" + (_projectStartYear + 1).ToString("#") + " Active Duty MPA Inflation Factor)" + vbCrLf
        s += "   " & Chr(149) + "  " + (_projectStartYear + 2).ToString("#") + " Active Duty Salary = (AMCOS LITE ""Avg Cost Base Pay (Military)"" BASE YEAR SALARY) * (" + (_projectStartYear + 2).ToString("#") + " Active Duty MPA Inflation Factor)" + vbCrLf
        ws.Cells(0, 0).Value = s
        style.Font.Size = 10
        style.Font.IsBold = False
        style.ShrinkToFit = True
        ws.Cells(0, 0).SetStyle(style)

        ws.Cells.InsertRow(0)
        ws.Cells.Merge(0, 0, 1, 12)
        ws.Cells(0, 0).Value = "For Example"
        style.Font.IsBold = True
        style.Font.Underline = Aspose.Cells.FontUnderlineType.Single
        style.Borders(BorderType.BottomBorder).LineStyle = CellBorderType.None
        ws.Cells(0, 0).SetStyle(style)

        ws.Cells.InsertRow(0)
        ws.Cells.Merge(0, 0, 1, 12)
        ws.Cells(0, 0).Value = "In Project Manager (PM), the Fiscal Year (FY) costs generated in AMCOS LITE will be referred to as ""BASE YEAR"" costs. PM multiplies BASE YEAR costs by the appropriate target year INFLATION FACTOR generating Future Start Year and/or Future Year Cost Element costs across the entire duration."
        style.Font.IsBold = False
        style.Font.Underline = Aspose.Cells.FontUnderlineType.None
        ws.Cells(0, 0).SetStyle(style)

        ws.Cells.InsertRow(0)
        ws.Cells.Merge(0, 0, 1, 12)
        ws.Cells(0, 0).Value = "Inflation Calculation Note:"
        style.Font.IsBold = True
        style.Font.Underline = Aspose.Cells.FontUnderlineType.Single
        ws.Cells(0, 0).SetStyle(style)

        ' Inflation Factors
        ws.Cells.InsertRow(0)
        Dim dtRate As DataTable = CType(Session("dvForExportPart0"), DataTable)
        ws.Cells.ImportDataTable(dtRate, True, 0, 0, True)
        For rowNumber As Integer = 1 To dtRate.Rows.Count
            For columnNumber As Integer = 1 To dtRate.Columns.Count - 1
                Dim val As Decimal = CType(ws.Cells(rowNumber, columnNumber).Value, Decimal)
                ws.Cells(rowNumber, columnNumber).Value = val.ToString("0.0000")
                ws.Cells(rowNumber, columnNumber).Value = CType(ws.Cells(rowNumber, columnNumber).Value, Double)
            Next
        Next
        style.Borders(BorderType.TopBorder).LineStyle = CellBorderType.Thin
        style.Borders(BorderType.BottomBorder).LineStyle = CellBorderType.Thin
        style.Borders(BorderType.LeftBorder).LineStyle = CellBorderType.Thin
        style.Borders(BorderType.RightBorder).LineStyle = CellBorderType.Thin
        ws.Cells.CreateRange(1, 0, dtRate.Rows.Count, dtRate.Columns.Count).ApplyStyle(style, styleFlag)

        style.VerticalAlignment = TextAlignmentType.General
        style.HorizontalAlignment = TextAlignmentType.General
        style.Font.IsBold = True
        style.Font.Color = Color.White
        style.ForegroundColor = Color.Navy
        ws.Cells.CreateRange(0, 0, 1, dtRate.Columns.Count).ApplyStyle(style, styleFlag)

        ws.Cells.InsertRow(0)
        ws.Cells.InsertRow(0)
        ws.Cells.InsertRow(0)
        ws.Cells.InsertRow(0)
        ws.Cells.Merge(0, 0, 3, 15)
        ws.Cells(0, 0).Value = "The current Joint Inflation Calculator (JIC) found on the OASA (FM&C) website, http://asafm.army.mil/offices/CE/Rates.aspx?OfficeCode=1400, is the source for the fourteen (14) inflation factors built into Project Manager (PM).  Each component (Active, NG, & Reserves) has their own separate set of ""MPA"", ""MPA Non Pay"", & ""OMA"" inflation factors and Civilian (GS, WG, WL, WS, & SES) positions are only inflated by two inflation factors, ""CivPay"" or ""OMA"".  The ""MPA"" inflation factor is applied to all MPA Appropriation (APPN) cost elements except Permanent Change of Station (PCS) related cost elements.  In this case, the ""MPA Non Pay"" inflation factor is applied to a PCS cost element.  When AMCOS LITE displays APPN = ""OMA"" or ""Other"", the ""OMA"" inflation factor is applied to any cost element with either APPN."
        style.Font.IsBold = False
        style.Font.Color = Color.Black
        style.ForegroundColor = Color.White
        style.Font.Underline = Aspose.Cells.FontUnderlineType.None
        style.Borders(BorderType.TopBorder).LineStyle = CellBorderType.None
        style.Borders(BorderType.BottomBorder).LineStyle = CellBorderType.None
        style.Borders(BorderType.LeftBorder).LineStyle = CellBorderType.None
        style.Borders(BorderType.RightBorder).LineStyle = CellBorderType.None
        ws.Cells(0, 0).SetStyle(style)
        ws.Cells.InsertRow(0)
        ws.Cells.InsertRow(0)

        ws.Cells(0, 0).Value = "Inflation Factors"
        style.Font.IsBold = True
        style.Font.Size = 14
        ws.Cells(0, 0).SetStyle(style)

        ' Report Properties on top
        Dim sql As String = "SELECT DISTINCT PMCategory.CategoryName AS [Sub-Project Name], PMReport.PayPlan FROM webuser.PMReport PMReport INNER JOIN webuser.PMCategory PMCategory ON PMReport.CategoryId = PMCategory.CategoryId INNER JOIN webuser.PMProject PMProject ON PMProject.ProjectId = PMCategory.ProjectId WHERE (PMProject.UserID = @uid) AND (PMProject.ProjectId = @pid);"
        Dim dtSubProj As DataTable = DataAccessUtility.GetDataTableByStaticSql(sql, {"@uid", "@pid"}, {currentUser.UserId, ProjectId})
        Dim nRows As Integer = 7
        If dtSubProj.Rows.Count > 6 Then nRows = dtSubProj.Rows.Count + 1
        For i As Integer = 0 To nRows
            ws.Cells.InsertRow(0)
        Next
        ws.Cells.ImportDataTable(dtSubProj, True, 0, 3, False)

        ws.Cells(0, 0).Value = "Project Creator"
        ws.Cells(1, 0).Value = "Create Date"
        ws.Cells(2, 0).Value = "Last Update"
        ws.Cells(3, 0).Value = "Project Name"
        ws.Cells(4, 0).Value = "Description"
        ws.Cells(5, 0).Value = "Start Year"
        ws.Cells(6, 0).Value = "Project Duration"
        dtD = DataAccessUtility.GetDataTableByStaticSql("SELECT isnull(ProjectCreator,UserID), convert(varchar,CreateDate), convert(varchar,LastUpdate), ProjectName, Description, YearStart, YearDuration FROM webuser.PMProject WHERE ProjectID = @pid", {"@pid"}, {ProjectId})
        For i As Integer = 0 To 6
            ws.Cells(i, 1).Value = dtD.Rows(0)(i)
        Next
        style.Font.Size = 10
        style.Font.Color = Color.White
        style.ForegroundColor = Color.Navy
        style.Borders(BorderType.TopBorder).LineStyle = CellBorderType.Thin
        style.Borders(BorderType.BottomBorder).LineStyle = CellBorderType.Thin
        style.Borders(BorderType.LeftBorder).LineStyle = CellBorderType.Thin
        style.Borders(BorderType.RightBorder).LineStyle = CellBorderType.Thin
        ws.Cells.CreateRange(0, 0, 7, 1).ApplyStyle(style, styleFlag)
        ws.Cells.CreateRange(0, 3, 1, 2).ApplyStyle(style, styleFlag)

        style.Font.IsBold = False
        style.Font.Color = Color.Black
        style.ForegroundColor = Color.White
        ws.Cells.CreateRange(0, 1, 7, 1).ApplyStyle(style, styleFlag)
        ws.Cells.CreateRange(1, 3, dtSubProj.Rows.Count, 2).ApplyStyle(style, styleFlag)

        ws.Cells.InsertRow(0)
        ws.Cells.InsertRow(0)
        style.Font.Color = Color.Black
        style.ForegroundColor = Color.White
        style.Font.IsBold = True
        style.Font.Size = 14
        style.Borders(BorderType.TopBorder).LineStyle = CellBorderType.None
        style.Borders(BorderType.BottomBorder).LineStyle = CellBorderType.None
        style.Borders(BorderType.LeftBorder).LineStyle = CellBorderType.None
        style.Borders(BorderType.RightBorder).LineStyle = CellBorderType.None
        ws.Cells(0, 0).Value = "Report Properties"
        ws.Cells(0, 0).SetStyle(style)

        AddClassification(ws)
        ws.AutoFitColumns()
        wb.Save(Response, "AMCOSReportData_" + Now().ToString("yyyyMMdd-HHmmss") + ".xlsx", Aspose.Cells.ContentDisposition.Attachment, New Aspose.Cells.OoxmlSaveOptions(Aspose.Cells.SaveFormat.Xlsx))
        Response.End()
    End Sub
End Class
