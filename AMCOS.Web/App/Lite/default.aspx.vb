Imports System.ComponentModel
Imports System.Configuration.ConfigurationManager
Imports System.Data.SqlClient
Imports AMCOS.Logic
Imports System.Drawing
Imports Aspose.Cells
Imports AMCOS.Data.ViewModels

Partial Class LiteDefault
    Inherits BasePage

    Dim aCostsTotals(25) As Double
    Dim aAPPNTotals(25) As Double
    Dim appropriationGridCostColumnStartIndex As Integer = -1
    Dim appropriationGridShowOrderColumnIndex As Integer = -1
    Dim costsGridCostColumnStartIndex As Integer = -1
    Dim costsGridCostElementNameColumnIndex As Integer = -1
    Dim costsGridShowOrderColumnIndex As Integer = -1
    Dim costsGridAppnGroupColumnIndex As Integer = -1
    Dim cceColumnsOverSalaryLimit As New List(Of Integer)

    Public ReadOnly amcosVersionId As Integer = CInt(AppSettings("AmcosVersionId"))
    Public ReadOnly cceMaxPayFootnote As Integer = CInt(SingleValue.Get("CCE", "MaxPayFootnote", amcosVersionId))
    Public _blinkSwitch As String = ""
    Public _cceWagesAndSalaries As String = ""
    Public _cceBenefitsAll As String = ""
    Public _cceBenefitsPaidLeave As String = ""
    Public _cceBenefitsSupplementalPay As String = ""
    Public _cceBenefitsInsurance As String = ""
    Public _cceBenefitsRetirementAndSavingsAll As String = ""
    Public _cceBenefitsLegallyRequired As String = ""
    Protected Sub Page_Load(ByVal sender As Object, ByVal e As EventArgs) Handles Me.Load

        Response.BufferOutput = True
        Response.Clear()

        hidUserId.Value = currentUser.UserId

        If Not IsPostBack Then
            _blinkSwitch = "stopBlink();"
        End If

        Dim costs As New Costs()
        Dim cceCosts As ContractorCostEstimateCostsViewModel
        cceCosts = costs.GetCceCosts(amcosVersionId)
        _cceWagesAndSalaries = cceCosts.WagesAndSalaries
        _cceBenefitsAll = cceCosts.BenefitsAll
        _cceBenefitsPaidLeave = cceCosts.BenefitsPaidLeave
        _cceBenefitsSupplementalPay = cceCosts.BenefitsSupplementalPay
        _cceBenefitsInsurance = cceCosts.BenefitsInsurance
        _cceBenefitsRetirementAndSavingsAll = cceCosts.BenefitsRetirementAndSavingsAll
        _cceBenefitsLegallyRequired = cceCosts.BenefitsLegallyRequired

    End Sub
    Protected Sub AppropriationGroupGridView_RowCreated(sender As Object, e As GridViewRowEventArgs) Handles AppropriationGroupGridView.RowCreated

        Select Case e.Row.RowType
            Case DataControlRowType.Header
                For Each tableCell As TableCell In e.Row.Cells
                    If tableCell.Text = "ShowOrder" Then
                        appropriationGridShowOrderColumnIndex = e.Row.Cells.GetCellIndex(tableCell)
                    End If
                Next
        End Select

        'Hide the ShowOrder column if it exists
        If appropriationGridShowOrderColumnIndex <> -1 And e.Row IsNot Nothing Then
            e.Row.Cells(appropriationGridShowOrderColumnIndex).Visible = False
        End If

    End Sub
    Protected Sub CostsGridView_RowCreated(ByVal sender As Object, ByVal e As GridViewRowEventArgs) Handles CostsGridView.RowCreated

        Select Case e.Row.RowType
            Case DataControlRowType.Header
                For Each tableCell As TableCell In e.Row.Cells
                    If tableCell.Text = "Cost Element Name" Then
                        costsGridCostElementNameColumnIndex = e.Row.Cells.GetCellIndex(tableCell)
                    End If
                    If tableCell.Text = "ShowOrder" Then
                        costsGridShowOrderColumnIndex = e.Row.Cells.GetCellIndex(tableCell)
                    End If
                    If tableCell.Text = "appnGroup" Then
                        costsGridAppnGroupColumnIndex = e.Row.Cells.GetCellIndex(tableCell)
                    End If
                Next
        End Select

        'Hide the ShowOrder column if it exists
        If costsGridShowOrderColumnIndex <> -1 Then
                e.Row.Cells(costsGridShowOrderColumnIndex).Visible = False
            End If

        'Hide the Appropriation Group column if it exists
        If costsGridAppnGroupColumnIndex <> -1 Then
            e.Row.Cells(costsGridAppnGroupColumnIndex).Visible = False
        End If

    End Sub
    Protected Sub CostsGridView_RowDataBound(ByVal sender As Object, ByVal e As GridViewRowEventArgs) Handles CostsGridView.RowDataBound

        Dim businessRules As New Logic.PayPlan(selectedPayPlan.Value)
        Dim appropriation() As String = {"Army CivPay", "Contractor", "Federal OM", "MPA", "MPA Non-Pay", "NGPA", "OMA", "OMA_1", "OMAR", "OMAR_1", "OMDW", "OMNG", "OMNG_1", "RPA"}
        Dim hideRow As Boolean = True

        If e.Row.Cells.Count > 1 Then
            If Not costsGridCostElementNameColumnIndex = -1 Then
                e.Row.Cells(costsGridCostElementNameColumnIndex + 1).Visible = False
                e.Row.Cells(costsGridCostElementNameColumnIndex).ToolTip = e.Row.Cells(costsGridCostElementNameColumnIndex + 1).Text
            End If

            If e.Row.RowType = DataControlRowType.DataRow Then

                If e.Row.Cells(costsGridCostElementNameColumnIndex).Text = "Avg Cost of Weapon Specific Training" Or
                        e.Row.Cells(costsGridCostElementNameColumnIndex).Text = "Avg Cost of Weapon Specific Training (Amortized)" Or
                        e.Row.Cells(costsGridCostElementNameColumnIndex).Text = "Avg Fixed Cost of Weapon Specific Training" Or
                        e.Row.Cells(costsGridCostElementNameColumnIndex).Text = "Avg Fixed Cost of Weapon Specific Training (Amortized)" Then
                    'Only hide the row if all amounts equal zero
                    For weaponSystemAmountColumn As Integer = costsGridCostElementNameColumnIndex + 3 To e.Row.Cells.Count - 1
                        If e.Row.Cells(weaponSystemAmountColumn).Text <> "0" Then
                            hideRow = False
                        End If
                    Next
                    If hideRow Then
                        e.Row.Visible = False
                    End If
                End If

                For Each tableCell As TableCell In e.Row.Cells
                    If (tableCell.Text = "MIN") Or (tableCell.Text = "AVG") Or (tableCell.Text = "MAX") Or IsNumeric(tableCell.Text) Then
                        Dim columnIndex As Integer = e.Row.Cells.GetCellIndex(tableCell)
                        If costsGridCostColumnStartIndex = -1 Then
                            costsGridCostColumnStartIndex = columnIndex
                        End If

                        If (CInt(tableCell.Text) = cceMaxPayFootnote) And (selectedPayPlan.Value = "CCE") Then
                            cceColumnsOverSalaryLimit.Add(columnIndex)
                            liHighlightNote.Visible = True
                        End If

                        If cceColumnsOverSalaryLimit.Contains(columnIndex) Then
                            tableCell.BackColor = Color.Yellow
                        End If

                        aCostsTotals(columnIndex) = aCostsTotals(columnIndex) + CDbl(tableCell.Text)
                        tableCell.Text = FormatCurrency(tableCell.Text)
                        tableCell.Style.Add(HtmlTextWriterStyle.TextAlign, "Right")
                    Else
                        If Array.IndexOf(appropriation, tableCell.Text) <> -1 Then
                            tableCell.BackColor = businessRules.GetAppropriationColor(e.Row.Cells(0).Text, e.Row.Cells(1).Text)
                            tableCell.ForeColor = Color.White
                        Else
                            tableCell.BackColor = Color.White
                            tableCell.ForeColor = Color.Black
                        End If
                        tableCell.Font.Bold = True
                    End If
                    If e.Row.Cells(1).Text = "zzz3Total" And tableCell.BackColor <> Color.Yellow Then
                        e.Row.Cells(1).ForeColor = Color.Black
                        tableCell.BackColor = ColorTranslator.FromHtml("#DEDFDE")
                    End If
                Next

                If selectedCostSummary.Value = "Weapon System Manpower" Then
                    If e.Row.Cells(6).Text.EndsWith("Total") Then
                        e.Row.Cells(6).HorizontalAlign = HorizontalAlign.Right
                        For Each oCell As TableCell In e.Row.Cells
                            oCell.BackColor = ColorTranslator.FromHtml("#DEDFDE")
                        Next
                    End If
                Else
                    If e.Row.Cells(3).Text.EndsWith("Total") Then
                        e.Row.Cells(3).HorizontalAlign = HorizontalAlign.Right
                        For Each oCell As TableCell In e.Row.Cells
                            oCell.BackColor = ColorTranslator.FromHtml("#DEDFDE")
                        Next
                    End If
                End If

            End If

            If e.Row.RowType = DataControlRowType.Footer Then
                e.Row.Cells(3).Text = "Total"
                For Each tableCell As TableCell In e.Row.Cells
                    If e.Row.Cells.GetCellIndex(tableCell) >= costsGridCostColumnStartIndex Then
                        tableCell.Text = Convert.ToString(aCostsTotals(e.Row.Cells.GetCellIndex(tableCell)))
                        tableCell.Text = FormatCurrency(tableCell.Text)
                        tableCell.Style.Add(HtmlTextWriterStyle.TextAlign, "Right")
                    End If
                Next
            End If

        End If

        If e.Row.Cells(1).Text.StartsWith("zzz") Then
            e.Row.Cells(1).Text = e.Row.Cells(1).Text.Substring(4) ' for CCE only.  9/28/2015
        End If

    End Sub
    Protected Sub AppropriationGroupGridView_RowDataBound(ByVal sender As Object, ByVal e As System.Web.UI.WebControls.GridViewRowEventArgs) Handles AppropriationGroupGridView.RowDataBound

        Dim businessRules As New Logic.PayPlan(selectedPayPlan.Value)


        If Not e.Row.RowType = DataControlRowType.EmptyDataRow Then
            Select Case e.Row.RowType

                'Edit the values of the grade levels for the header row
                Case DataControlRowType.Header
                    For Each tableCell As TableCell In e.Row.Cells
                        If IsNumeric(tableCell.Text) Then
                            Select Case selectedPayPlan.Value
                                Case "AE", "RE", "NE"
                                    tableCell.Text = "E" + tableCell.Text
                                Case "AO", "RO", "NO"
                                    tableCell.Text = "O" + tableCell.Text
                                Case "AWO", "RWO", "NWO"
                                    tableCell.Text = "W" + tableCell.Text
                                Case "SES"
                                    Select Case tableCell.Text
                                        Case "1"
                                            tableCell.Text = "MIN"
                                        Case "2"
                                            tableCell.Text = "AVG"
                                        Case "3"
                                            tableCell.Text = "MAX"
                                        Case Else
                                            tableCell.Text = "Error"
                                    End Select
                                Case "CCE"
                                    tableCell.Text = "Level " + tableCell.Text
                                Case Else
                                    tableCell.Text = selectedPayPlan.Value + tableCell.Text
                            End Select
                        End If
                    Next

                'Format table cells
                Case DataControlRowType.DataRow
                    For Each tableCell As TableCell In e.Row.Cells
                        If (tableCell.Text = "MIN") Or (tableCell.Text = "AVG") Or (tableCell.Text = "MAX") Or IsNumeric(tableCell.Text) Then
                            'Format numbers for currency
                            Dim cellIndex As Integer = e.Row.Cells.GetCellIndex(tableCell)
                            If appropriationGridCostColumnStartIndex = -1 Then
                                appropriationGridCostColumnStartIndex = cellIndex
                            End If
                            aAPPNTotals(cellIndex) = aAPPNTotals(cellIndex) + CDbl(tableCell.Text)
                            tableCell.Text = FormatCurrency(tableCell.Text)
                            tableCell.Style.Add(HtmlTextWriterStyle.TextAlign, "Right")
                        Else
                            'Set the background color based on appropriation/Army CES Title
                            If selectedCostSummary.Value = "Weapon System Manpower" Then
                                tableCell.BackColor = businessRules.GetArmyCesTitleColor(e.Row.Cells(0).Text)
                            Else
                                tableCell.BackColor = businessRules.GetAppropriationColor(e.Row.Cells(0).Text, e.Row.Cells(1).Text)
                            End If

                            tableCell.Font.Bold = True
                            tableCell.ForeColor = Color.White
                        End If
                    Next
            End Select

            'Total line only exists for all summaries except "Ancillary"
            If selectedCostSummary.Value <> "Ancillary" Then
                If e.Row.RowType = DataControlRowType.Footer Then
                    e.Row.Cells(0).Text = "Total"
                    e.Row.Cells(0).HorizontalAlign = HorizontalAlign.Right
                    e.Row.Cells(0).Font.Bold = True

                    For Each tableCell As TableCell In e.Row.Cells
                        Dim cellIndex As Integer = e.Row.Cells.GetCellIndex(tableCell)
                        If cellIndex >= appropriationGridCostColumnStartIndex Then
                            tableCell.Text = aAPPNTotals(cellIndex).ToString
                            tableCell.Text = FormatCurrency(tableCell.Text)
                            tableCell.HorizontalAlign = HorizontalAlign.Right
                        End If
                    Next
                End If
            End If
        End If

    End Sub

    Protected Sub ShowCosts_Click(ByVal sender As Object, ByVal e As System.EventArgs) Handles showCostsButton.Click

        If Not Page.IsValid Then
            Exit Sub
        End If

        Dim Logging As Boolean = False
        Dim customSetting As String = AppSettings("AmcosLiteLogging")
        If Not (customSetting = Nothing) Then
            If (customSetting = "ButtonClick") Or (customSetting = "Both") Then
                Logging = True
            Else
                Logging = False
            End If
        Else
            Logging = False
        End If

        Dim PayPlan As String = selectedPayPlan.Value
        Dim CostSummaryName As String = selectedCostSummary.Value
        Dim CategoryGroupCode As String = selectedCategoryGroupCode.Value
        Dim CategorySubgroupCode As String = selectedCategorySubgroupCode.Value
        Dim CareerProgramNumber As String = selectedCareerProgramNumber.Value
        Dim LocationId As Integer = Integer.Parse(selectedLocationId.Value)
        Dim LocationText As String = selectedLocationText.Value
        Dim ScienceTechnologyReinventionLaboratory As String = selectedScienceTechnologyReinventionLaboratory.Value
        Dim DependentStatus As String = selectedDependentStatusText.Value
        Dim NumberOfDependents As Integer = Integer.Parse(selectedNumberOfDependents.Value)

        Dim OverheadPercent As Single
        If inputOverheadPercent.Value <> "" Then
            OverheadPercent = Single.Parse(inputOverheadPercent.Value)
        End If

        Dim InflationConversionType As String = selectedInflationConversionType.Value
        Dim InflationYear As String = selectedInflationYear.Value

        Dim userId As String
        userId = currentUser.UserId

        Dim ds As DataSet = New DataSet

        If PayPlan = "CCE" Then
            lblPayTableTitle.Text = ""
            Dim amcosLite As New Lite("CCE")

            If Logging Then
                Try
                    Dim amcosLiteViewModel As AmcosLiteViewModel = New AmcosLiteViewModel With {
                            .UserId = currentUser.UserId,
                            .PayPlan = PayPlan,
                            .CostSummaryName = CostSummaryName,
                            .CategoryGroupCode = CategoryGroupCode,
                            .CategorySubgroupCode = CategorySubgroupCode,
                            .CareerProgramNumber = CareerProgramNumber,
                            .LocationId = LocationId,
                            .LocationText = LocationText,
                            .ScienceTechnologyReinventionLaboratory = ScienceTechnologyReinventionLaboratory,
                            .DependentStatus = DependentStatus,
                            .NumberOfDependents = NumberOfDependents,
                            .OverheadPercent = OverheadPercent,
                            .InflationConversionType = InflationConversionType,
                            .InflationYear = InflationYear,
                            .AmcosVersionId = amcosVersionId
                            }
                    amcosLite.LogSelections("ShowCosts", "ShowCostsButton", amcosLiteViewModel)
                Catch ex As Exception

                End Try
            End If

            ds = amcosLite.Costs(CategoryGroupCode, CategorySubgroupCode, LocationId, OverheadPercent, InflationConversionType, InflationYear, amcosVersionId)

            CostsGridView.DataSource = ds.Tables(0)
            CostsGridView.DataBind()
            Session("dvForExportPart1") = ds.Tables(0)
            'TODO Use a variable to represent AmcosVersionId
            PopulateRateHeader(InflationConversionType, PayPlan, InflationYear, amcosVersionId)
            ScriptManager.RegisterStartupScript(Me, Me.GetType(), "CCENote", "showCCENote();", True)
        Else
            lblPayTableTitle.Text = ""
            Dim amcosLite = New Lite With {
            .PayPlan = PayPlan,
            .CostSummaryName = CostSummaryName,
            .CategoryGroupCode = CategoryGroupCode,
            .CategorySubgroupCode = CategorySubgroupCode,
            .CareerProgramNumber = CareerProgramNumber,
            .LocationId = LocationId,
            .ScienceTechnologyReinventionLaboratory = ScienceTechnologyReinventionLaboratory,
            .DependentStatus = DependentStatus,
            .NumberOfDependents = NumberOfDependents,
            .OverheadPercent = OverheadPercent,
            .InflationConversionType = InflationConversionType,
            .InflationYear = InflationYear,
            .AmcosVersionId = amcosVersionId
            }

            ds = amcosLite.GetCosts(currentUser.UserId)

            If Logging Then
                Try
                    Dim amcosLiteViewModel As AmcosLiteViewModel = New AmcosLiteViewModel With {
                    .UserId = currentUser.UserId,
                    .PayPlan = PayPlan,
                    .CostSummaryName = CostSummaryName,
                    .CategoryGroupCode = CategoryGroupCode,
                    .CategorySubgroupCode = CategorySubgroupCode,
                    .CareerProgramNumber = CareerProgramNumber,
                    .LocationId = LocationId,
                    .LocationText = LocationText,
                    .ScienceTechnologyReinventionLaboratory = ScienceTechnologyReinventionLaboratory,
                    .DependentStatus = DependentStatus,
                    .NumberOfDependents = NumberOfDependents,
                    .OverheadPercent = OverheadPercent,
                    .InflationConversionType = InflationConversionType,
                    .InflationYear = InflationYear
                    }
                    amcosLite.LogSelections("ShowCosts", "ShowCostsButton", amcosLiteViewModel)
                Catch ex As Exception

                End Try
            End If
        End If

        Dim builder As StringBuilder = New StringBuilder
        Dim dataVisualization As DataVisualization = New DataVisualization
        If PayPlan <> "CCE" And CostSummaryName = "Default" Then
            builder.Append("var c3ChartData = " & dataVisualization.CreateC3Json(PayPlan, ds, False) & ";" & vbCrLf)
        End If
        builder.Append("drawC3Chart();")
        ScriptManager.RegisterStartupScript(Me, Me.GetType(), "drawchart", builder.ToString, True)

        If PayPlan <> "CCE" Then
            Select Case CostSummaryName
                Case "Default"
                    ProcessAndBindData(ds.Tables(2))
                Case Else
                    ProcessAndBindData(ds.Tables(0))
            End Select
        End If

        'hide the appropriation grid if pay plan is CCE or Summary is 'Ancillary'
        If PayPlan = "CCE" Or CostSummaryName = "Ancillary" Then
            AppropriationGroupGridView.CssClass = "hide"
        Else
            AppropriationGroupGridView.CssClass = AppropriationGroupGridView.CssClass.Replace("hide", "")
        End If

        ScriptManager.RegisterStartupScript(Me, Me.GetType(), "ExportButton", "document.getElementById('exportButton').classList.remove('hide');", True)

        _blinkSwitch = "stopBlink();"

    End Sub
    Private Sub ProcessAndBindData(CostElementCostsByGrade As DataTable)

        Dim PayPlan As String = selectedPayPlan.Value
        Dim CostSummaryName As String = selectedCostSummary.Value
        Dim CategoryGroupCode As String = selectedCategoryGroupCode.Value
        Dim CategorySubgroupCode As String = selectedCategorySubgroupCode.Value
        Dim InflationConversionType As String = selectedInflationConversionType.Value
        Dim InflationYear As String = selectedInflationYear.Value

        Dim AmcosLite As Lite = New Lite(PayPlan, CostSummaryName, CategoryGroupCode, CategorySubgroupCode)
        Dim CostTable As DataTable = AmcosLite.GetCostTableWithOrder(CostSummaryName, CostElementCostsByGrade)
        Dim AppropriationGroupTable As DataTable = GetAppropriationGroupTable(CostElementCostsByGrade)

        Session("dvForExportPart1") = CostTable

        'TODO Use a variable to represent AmcosVersionId
        PopulateRateHeader(InflationConversionType, PayPlan, InflationYear, amcosVersionId)

        CostsGridView.DataSource = New DataView(CostTable, "", "ShowOrder", DataViewRowState.CurrentRows)
        CostsGridView.DataBind()

        AppropriationGroupGridView.DataSource = New DataView(AppropriationGroupTable, "", "ShowOrder", DataViewRowState.CurrentRows)
        AppropriationGroupGridView.ShowFooter = (CostSummaryName <> "Ancillary")
        AppropriationGroupGridView.Visible = (CostSummaryName <> "Ancillary")
        AppropriationGroupGridView.DataBind()

        ' Process the AppropriationGroupTable table for export
        Dim drTotal As DataRow = AppropriationGroupTable.NewRow
        drTotal(0) = "Total"
        For i = 1 To AppropriationGroupTable.Columns.Count - 1
            drTotal(i) = AppropriationGroupTable.Compute("Sum([" + AppropriationGroupTable.Columns(i).ColumnName + "])", "")
        Next
        AppropriationGroupTable.Rows.Add(drTotal)

        For i = 2 To AppropriationGroupTable.Columns.Count - 1
            Select Case selectedPayPlan.Value
                Case "SES"
                    Select Case AppropriationGroupTable.Columns(i).ColumnName
                        Case "1"
                            AppropriationGroupTable.Columns(i).ColumnName = "MIN"
                        Case "2"
                            AppropriationGroupTable.Columns(i).ColumnName = "AVG"
                        Case "3"
                            AppropriationGroupTable.Columns(i).ColumnName = "MAX"
                    End Select
            End Select
        Next
        AppropriationGroupTable.AcceptChanges()
        Session("dvForExportPartA") = AppropriationGroupTable
    End Sub
    Private Function GetFiltersForPrint() As DataTable
        ' Refresh Export Headers
        Dim payPlan As PayPlan = New PayPlan(selectedPayPlan.Value)
        Dim ChosenFilters As New DataTable
        ChosenFilters.Columns.Add(New DataColumn("label", GetType(String)))
        ChosenFilters.Columns.Add(New DataColumn("value", GetType(String)))

        ChosenFilters.Rows.Add(New Object() {"PayPlan", payPlan.GetDisplayTitle()})

        If selectedCategoryGroupCode.Value <> "-1" Then
            ChosenFilters.Rows.Add(New Object() {payPlan.GetCategoryGroupLabel, payPlan.GetCategoryGroupText(selectedCategoryGroupCode.Value)})
        End If

        If selectedCategorySubgroupCode.Value <> "-1" Then
            ChosenFilters.Rows.Add(New Object() {payPlan.GetCategorySubgroupLabel, payPlan.GetCategorySubgroupText(selectedCategorySubgroupCode.Value)})
        End If

        If selectedCareerProgramNumber.Value <> "-1" Then
            ChosenFilters.Rows.Add(New Object() {"Army Career Program", payPlan.GetCareerProgramText(selectedCareerProgramNumber.Value)})
        End If

        If selectedLocationId.Value <> "-1" Then
            ChosenFilters.Rows.Add(New Object() {"Location", selectedLocationText.Value()})
        End If

        If selectedDependentStatusText.Value <> "-1" Then
            ChosenFilters.Rows.Add(New Object() {"Dependent Status", selectedDependentStatusText.Value})
        End If

        If selectedScienceTechnologyReinventionLaboratory.Value <> "-1" Then
            ChosenFilters.Rows.Add(New Object() {"Science And Technology Reinvention Laboratory (STRL)", selectedScienceTechnologyReinventionLaboratory.Value})
        End If

        If selectedPayPlan.Value = "CCE" Then
            If inputOverheadPercent.Value <> "-1" Then
                ChosenFilters.Rows.Add(New Object() {"Overhead Percent", inputOverheadPercent.Value + "%"})
            End If
        End If

        ChosenFilters.Rows.Add(New Object() {String.Format("Inflation (Base/Input Year:  {0})", AppSettings("DefaultYear")), payPlan.GetInflationConversionTypeText(selectedInflationConversionType.Value)})
        ChosenFilters.Rows.Add(New Object() {"Output/Target Year", selectedInflationYear.Value})
        ChosenFilters.Rows.Add(New Object() {"Summary", selectedCostSummary.Value})
        Return ChosenFilters

    End Function
    Private Shared Sub AddAppropriationGroupRow(ByRef dtAppn As DataTable, dtCost As DataTable, AppropriationGroup As String, SortOrder As Integer)
        Dim dataRow As DataRow = dtAppn.NewRow
        dataRow("Appropriation Group") = AppropriationGroup
        dataRow("ShowOrder") = SortOrder
        For columnIndex As Integer = 2 To dtAppn.Columns.Count - 1
            dataRow(columnIndex) = dtCost.Compute("Sum([" + dtAppn.Columns(columnIndex).ColumnName + "])", "appnGroup='" + AppropriationGroup + "'")
        Next
        dtAppn.Rows.Add(dataRow)
    End Sub
    Private Shared Sub AddAppropriationGroupRowForWeaponSystemManpowerSummary(ByRef dtAppnAC As DataTable, dtCost As DataTable, CostElementStructureText As String, SortOrder As Integer)
        Dim dataRow As DataRow = dtAppnAC.NewRow
        dataRow(0) = CostElementStructureText
        dataRow("ShowOrder") = SortOrder
        'Sum the numeric columns
        For columnIndex As Integer = 2 To dtAppnAC.Columns.Count - 1
            dataRow(columnIndex) = dtCost.Compute("Sum([" + dtAppnAC.Columns(columnIndex).ColumnName + "])", "[Army CES Title]='" + CostElementStructureText + "'")
        Next
        dtAppnAC.Rows.Add(dataRow)
    End Sub
    Private Function GetAppropriationGroupTable(CostElementCostsByGrade As DataTable) As DataTable

        Dim AppropriationTable As DataTable = CostElementCostsByGrade.Clone
        Dim amcosLite As Lite = New Lite()

        If AppropriationTable.Columns.IndexOf("Army CES Title") = -1 Then
            AppropriationTable.Columns.Remove("Description")
            AppropriationTable.Columns.Remove("Cost Element Name")
            AppropriationTable.Columns.Remove("Cost Element Category")
            AppropriationTable.Columns.Remove("APPN")
            AppropriationTable.Columns(0).ColumnName = "Appropriation Group"
            If CostElementCostsByGrade.Select("appnGroup='ARMY'").Length > 0 Then
                AddAppropriationGroupRow(AppropriationTable, CostElementCostsByGrade, "ARMY", 1)
            End If
            If CostElementCostsByGrade.Select("appnGroup='DoD'").Length > 0 Then
                AddAppropriationGroupRow(AppropriationTable, CostElementCostsByGrade, "DoD", 2)
            End If
            If CostElementCostsByGrade.Select("appnGroup='FEDERAL'").Length > 0 Then
                AddAppropriationGroupRow(AppropriationTable, CostElementCostsByGrade, "FEDERAL", 3)
            End If
            If CostElementCostsByGrade.Select("appnGroup='PA'").Length > 0 Then
                AddAppropriationGroupRow(AppropriationTable, CostElementCostsByGrade, "PA", 1)
            End If
            If CostElementCostsByGrade.Select("appnGroup='OM'").Length > 0 Then
                AddAppropriationGroupRow(AppropriationTable, CostElementCostsByGrade, "OM", 2)
            End If
        Else
            If AppropriationTable.Columns.IndexOf("Description") <> -1 Then
                AppropriationTable.Columns.Remove("Description")
            End If

            If AppropriationTable.Columns.IndexOf("Cost Element Name") <> -1 Then
                AppropriationTable.Columns.Remove("Cost Element Name")
            End If

            If AppropriationTable.Columns.IndexOf("Cost Element Category") <> -1 Then
                AppropriationTable.Columns.Remove("Cost Element Category")
            End If

            If AppropriationTable.Columns.IndexOf("APPN") <> -1 Then
                AppropriationTable.Columns.Remove("APPN")
            End If

            If AppropriationTable.Columns.IndexOf("appnGroup") <> -1 Then
                AppropriationTable.Columns.Remove("appnGroup")
            End If

            If AppropriationTable.Columns.IndexOf("Weapon System Name") <> -1 Then
                AppropriationTable.Columns.Remove("Weapon System Name")
            End If

            If AppropriationTable.Columns.IndexOf("OSD CAPE CES Title") <> -1 Then
                AppropriationTable.Columns.Remove("OSD CAPE CES Title")
            End If

            Dim armyCesTitles As IEnumerable(Of Object) = amcosLite.GetArmyCesTitles(selectedPayPlan.Value, selectedCostSummary.Value)

            For i As Integer = 0 To armyCesTitles.Count - 1
                If CostElementCostsByGrade.Select("[Army CES Title]='" + armyCesTitles(i).ToString + "'").Length > 0 Then
                    AddAppropriationGroupRowForWeaponSystemManpowerSummary(AppropriationTable, CostElementCostsByGrade, armyCesTitles(i).ToString, i)
                End If
            Next
        End If
        AppropriationTable.AcceptChanges()
        Return AppropriationTable

    End Function
    Private Sub CheckBlink()
        If IsPostBack Then
            _blinkSwitch = "startBlink();"
            exportButton.Visible = False
        End If
    End Sub
    Protected Sub IbDownloadExcel_Click(ByVal sender As Object, ByVal e As System.Web.UI.ImageClickEventArgs) Handles ibDownloadExcel.Click

        Dim payPlanObject As PayPlan = New PayPlan(selectedPayPlan.Value)

        Dim license As Aspose.Cells.License = New Aspose.Cells.License()
        license.SetLicense("Aspose.Cells.lic")
        Dim wb As New Aspose.Cells.Workbook()
        Dim ws As Aspose.Cells.Worksheet = wb.Worksheets(0)

        Dim importOptions As ImportTableOptions = New ImportTableOptions()
        Dim style As Aspose.Cells.Style
        Dim styleFlag As StyleFlag
        Dim showCCEOverSalaryLimitNote As Boolean = False
        Dim showCCEWageEstimateNotAvailableNote As Boolean = False

        ' Export the Cost grid at the bottom
        Dim Costs As DataTable = CType(Session("dvForExportPart1"), DataTable)
        Dim CostTable As DataTable = GetCostDataForExport(Costs).Copy
        Dim excelExportDataView As DataView


        If selectedPayPlan.Value = "CCE" Then
            excelExportDataView = New DataView(CostTable, "", "", DataViewRowState.CurrentRows)
            excelExportDataView = RenameColumns(excelExportDataView)

            ws.Cells.ImportDataView(excelExportDataView, True, 0, 0, True)
            ws.Cells.DeleteRange(0, 0, 4, 0, Aspose.Cells.ShiftType.Left)
            ws.Cells(1, 0).Value = ws.Cells(1, 0).Value.ToString.Substring(4)
            ws.Cells(2, 0).Value = ws.Cells(2, 0).Value.ToString.Substring(4)
            ws.Cells(3, 0).Value = ws.Cells(3, 0).Value.ToString.Substring(4)
            ws.Cells(4, 0).Value = ws.Cells(4, 0).Value.ToString.Substring(4)
            ' set header row style
            style = wb.CreateStyle()
            style.Borders(BorderType.TopBorder).LineStyle = CellBorderType.Thin
            style.Borders(BorderType.BottomBorder).LineStyle = CellBorderType.Thin
            style.Borders(BorderType.LeftBorder).LineStyle = CellBorderType.Thin
            style.Borders(BorderType.RightBorder).LineStyle = CellBorderType.Thin
            style.Font.IsBold = True
            style.Font.Color = Color.White
            style.ForegroundColor = Color.Black
            style.Pattern = Aspose.Cells.BackgroundType.Solid
            style.ShrinkToFit = True
            style.HorizontalAlignment = TextAlignmentType.Center
            style.Number = 7

            styleFlag = New StyleFlag With {
                .Borders = True,
                .FontBold = True,
                .FontColor = True,
                .CellShading = True,
                .HorizontalAlignment = True,
                .NumberFormat = True
            }

            ' set header row style
            ws.Cells.CreateRange(0, 0, 1, 6).ApplyStyle(style, styleFlag)

            ' set first column bold
            style.Pattern = Aspose.Cells.BackgroundType.None
            styleFlag.FontColor = False
            ws.Cells.CreateRange(1, 0, 3, 1).ApplyStyle(style, styleFlag)

            ' set the first column color bottom line
            style.Font.Color = Color.Black
            style.Pattern = Aspose.Cells.BackgroundType.Solid
            style.ForegroundColor = Color.LightGray
            ws.Cells(4, 0).SetStyle(style)

            ' set the other columns grid line
            style.Font.IsBold = False
            style.HorizontalAlignment = TextAlignmentType.Right
            styleFlag.Borders = True
            styleFlag.FontBold = False
            styleFlag.FontColor = False
            styleFlag.CellShading = False
            styleFlag.HorizontalAlignment = True
            ws.Cells.CreateRange(1, 1, 4, 5).ApplyStyle(style, styleFlag)

            ' set the other columns color bottom line
            styleFlag.CellShading = True
            ws.Cells.CreateRange(4, 1, 1, 5).ApplyStyle(style, styleFlag)

            'Determine which grade levels exceed the salary limit
            Dim cceColumnsOverSalaryLimit As New List(Of Integer)
            For columnNumber As Integer = 1 To 5
                If CDec(ws.Cells(1, columnNumber).Value) = cceMaxPayFootnote Then
                    cceColumnsOverSalaryLimit.Add(columnNumber)
                    showCCEOverSalaryLimitNote = True
                End If
            Next

            'Determine if any grade levels contain a wage estimate that is not available (-1)
            Dim cceWageEstimateNotAvailable As New List(Of Integer)
            For columnNumber As Integer = 1 To 5
                If CDec(ws.Cells(1, columnNumber).Value) = -1 Then
                    cceWageEstimateNotAvailable.Add(columnNumber)
                    showCCEWageEstimateNotAvailableNote = True
                End If
            Next

            ' format the cost numbers
            For rowNumber As Integer = 1 To 4
                For columnNumber As Integer = 1 To 5
                    If cceColumnsOverSalaryLimit.Contains(columnNumber) Then
                        style.ForegroundColor = Color.Yellow
                        ws.Cells(rowNumber, columnNumber).SetStyle(style)
                    Else
                        ws.Cells(rowNumber, columnNumber).Value = CType(ws.Cells(rowNumber, columnNumber).Value, Double)
                    End If
                Next
            Next

            'Add a note if any values exceed the salary limit
            If showCCEOverSalaryLimitNote Then
                ws.Cells(5, 0).PutValue("NOTE: The highlighted field(s) indicate a value based on CCE salary greater than " & FormatCurrency(cceMaxPayFootnote, 2) & " per year.  The Contractor APPN Total sums the displayed CCE values but may be greater if your report includes highlighted cells.")
                style = ws.Cells(5, 0).GetStyle()
                style.IsTextWrapped = True
                ws.Cells(5, 0).SetStyle(style)
                ws.Cells.Merge(5, 0, 2, 6)
            End If

            'Add a note if any values exceed the salary limit
            If showCCEWageEstimateNotAvailableNote Then
                ws.Cells(6, 0).PutValue("NOTE: A value of negative one [($1.00)] indicates a wage estimate is not available.")
                style = ws.Cells(6, 0).GetStyle()
                style.IsTextWrapped = True
                ws.Cells(6, 0).SetStyle(style)
            End If

        ElseIf payPlanObject.GetTags().Contains("GFEBS") Then
            'Case "DB", "DE", "DJ", "DK", "GP", "NH", "NJ", "NK"
            'import the costs                
            excelExportDataView = New DataView(CostTable, "", "showOrder", DataViewRowState.CurrentRows)
            excelExportDataView = RenameColumns(excelExportDataView)

            ws.Cells.ImportDataView(excelExportDataView, True, 0, 0, True)

            ' set header row style
            style = wb.CreateStyle()
            style.Borders(BorderType.TopBorder).LineStyle = CellBorderType.Thin
            style.Borders(BorderType.BottomBorder).LineStyle = CellBorderType.Thin
            style.Borders(BorderType.LeftBorder).LineStyle = CellBorderType.Thin
            style.Borders(BorderType.RightBorder).LineStyle = CellBorderType.Thin
            style.Font.IsBold = True
            style.Font.Color = Color.White
            style.ForegroundColor = Color.Black
            style.Pattern = BackgroundType.Solid
            style.ShrinkToFit = True
            style.HorizontalAlignment = TextAlignmentType.Center
            style.Number = 7

            'set styleFlat
            styleFlag = New StyleFlag With {
                .Borders = True,
                .FontBold = True,
                .FontColor = True,
                .CellShading = True,
                .HorizontalAlignment = True,
                .NumberFormat = True
            }

            ' set header row style
            ws.Cells.CreateRange(0, 1, 1, excelExportDataView.Table.Columns.Count - 1).ApplyStyle(style, styleFlag)

            Dim NumRowsExcludingTotal As Integer = CType(IIf(selectedCostSummary.Value = "0", excelExportDataView.Count, excelExportDataView.Count - 1), Integer)

            ' set the first APPN column colors
            style.HorizontalAlignment = TextAlignmentType.Left
            For rowIndex As Integer = 1 To NumRowsExcludingTotal
                Dim appropriationColor As Color = payPlanObject.GetAppropriationColor(ws.Cells(rowIndex, 0).Value.ToString, ws.Cells(rowIndex, 1).Value.ToString)
                style.ForegroundColor = appropriationColor
                ws.Cells(rowIndex, 1).SetStyle(style)
            Next

            'Total line only exists for all summaries except "Ancillary"
            If selectedCostSummary.Value <> "Ancillary" Then
                ' set the first APPN column color bottom line
                style.ForegroundColor = ColorTranslator.FromHtml("#DEDFDE")
                ws.Cells(excelExportDataView.Count, 1).SetStyle(style)
            End If

            ' set 2nd and 3rd column bold
            style.Pattern = BackgroundType.None
            styleFlag.FontColor = False
            ws.Cells.CreateRange(1, 2, NumRowsExcludingTotal, 2).ApplyStyle(style, styleFlag)

            'Total line only exists for all summaries except "Ancillary"
            If selectedCostSummary.Value <> "Ancillary" Then
                ' set the first three columns color bottom line
                style.Pattern = BackgroundType.Solid
                ws.Cells.CreateRange(excelExportDataView.Count, 2, 1, 2).ApplyStyle(style, styleFlag)
            End If

            ' set the other columns grid line
            style.Font.IsBold = False
            style.Font.Color = Color.Black
            style.HorizontalAlignment = TextAlignmentType.Right
            styleFlag.Borders = True
            styleFlag.FontBold = False
            styleFlag.FontColor = False
            styleFlag.CellShading = False
            styleFlag.HorizontalAlignment = True
            ws.Cells.CreateRange(1, 4, NumRowsExcludingTotal, excelExportDataView.Table.Columns.Count - 4).ApplyStyle(style, styleFlag)

            'Total line only exists for all summaries except "Ancillary"
            If selectedCostSummary.Value <> "Ancillary" Then
                ' set the other columns color bottom line
                styleFlag.CellShading = True
                ws.Cells.CreateRange(excelExportDataView.Count, 2, 1, 2).ApplyStyle(style, styleFlag)
                ws.Cells.CreateRange(excelExportDataView.Count, 4, 1, excelExportDataView.Table.Columns.Count - 4).ApplyStyle(style, styleFlag)
            End If

            ' format the cost numbers
            For tableRow As Integer = 1 To excelExportDataView.Count
                For tableColumn As Integer = 4 To excelExportDataView.Table.Columns.Count - 1
                    ' ws.Cells(i, j).Value = FormatCurrency(ws.Cells(i, j).Value)
                    If IsNumeric(ws.Cells(tableRow, tableColumn).Value) Then
                        ws.Cells(tableRow, tableColumn).Value = CType(ws.Cells(tableRow, tableColumn).Value, Double)
                    End If
                Next
            Next

            'Remove the first column
            ws.Cells.DeleteRange(0, 0, excelExportDataView.Count, 0, ShiftType.Left)
        Else
            excelExportDataView = New DataView(CostTable, "", "showOrder", DataViewRowState.CurrentRows)
            excelExportDataView = RenameColumns(excelExportDataView)

            ws.Cells.ImportDataView(excelExportDataView, True, 0, 0, True)

            ' set header row style
            style = wb.CreateStyle()
            style.Borders(BorderType.TopBorder).LineStyle = CellBorderType.Thin
            style.Borders(BorderType.BottomBorder).LineStyle = CellBorderType.Thin
            style.Borders(BorderType.LeftBorder).LineStyle = CellBorderType.Thin
            style.Borders(BorderType.RightBorder).LineStyle = CellBorderType.Thin
            style.Font.IsBold = True
            style.Font.Color = Color.White
            style.ForegroundColor = Color.Black
            style.Pattern = Aspose.Cells.BackgroundType.Solid
            style.ShrinkToFit = True
            style.HorizontalAlignment = TextAlignmentType.Center
            style.Number = 7

            styleFlag = New StyleFlag With {
                .Borders = True,
                .FontBold = True,
                .FontColor = True,
                .CellShading = True,
                .HorizontalAlignment = True,
                .NumberFormat = True
            }

            ' set header row style
            ws.Cells.CreateRange(0, 1, 1, excelExportDataView.Table.Columns.Count - 1).ApplyStyle(style, styleFlag)

            Dim NumberOfRowsExcludingTotal As Integer = CType(IIf(selectedCostSummary.Value = "Ancillary", excelExportDataView.Count, excelExportDataView.Count - 1), Integer)

            ' set the first APPN column colors
            style.HorizontalAlignment = TextAlignmentType.Left
            For i As Integer = 1 To NumberOfRowsExcludingTotal
                If Not ws.Cells(i, 0).Value Is Nothing And Not ws.Cells(i, 1).Value Is Nothing Then
                    Dim appropriationColor As Color = payPlanObject.GetAppropriationColor(ws.Cells(i, 0).Value.ToString, ws.Cells(i, 1).Value.ToString)
                    style.ForegroundColor = appropriationColor
                    ws.Cells(i, 1).SetStyle(style)
                End If
            Next

            'Total line only exists for all summaries except "Ancillary"
            If selectedCostSummary.Value <> "Ancillary" Then
                ' set the first APPN column color bottom line
                style.ForegroundColor = ColorTranslator.FromHtml("#DEDFDE")
                ws.Cells(excelExportDataView.Count, 1).SetStyle(style)
            End If

            ' set 2nd and 3rd column bold
            style.Pattern = Aspose.Cells.BackgroundType.None
            styleFlag.FontColor = False
            ws.Cells.CreateRange(1, 2, NumberOfRowsExcludingTotal, 2).ApplyStyle(style, styleFlag)

            'Total line only exists for all summaries except "Ancillary"
            If selectedCostSummary.Value <> "Ancillary" Then
                ' set the first three columns color bottom line
                style.Pattern = Aspose.Cells.BackgroundType.Solid
                ws.Cells.CreateRange(excelExportDataView.Count, 2, 1, 2).ApplyStyle(style, styleFlag)
            End If

            ' set the other columns grid line
            style.Font.IsBold = False
            style.Font.Color = Color.Black
            style.HorizontalAlignment = TextAlignmentType.Right
            styleFlag.Borders = True
            styleFlag.FontBold = False
            styleFlag.FontColor = False
            styleFlag.CellShading = False
            styleFlag.HorizontalAlignment = True
            ws.Cells.CreateRange(1, 4, NumberOfRowsExcludingTotal, excelExportDataView.Table.Columns.Count - 4).ApplyStyle(style, styleFlag)

            'Total line only exists for all summaries except "Ancillary"
            If selectedCostSummary.Value <> "Ancillary" Then
                ' set the other columns color bottom line
                styleFlag.CellShading = True
                ws.Cells.CreateRange(excelExportDataView.Count, 2, 1, 2).ApplyStyle(style, styleFlag)
                ws.Cells.CreateRange(excelExportDataView.Count, 4, 1, excelExportDataView.Table.Columns.Count - 4).ApplyStyle(style, styleFlag)
            End If

            'Format the cost cells
            For i As Integer = 1 To excelExportDataView.Count
                For j As Integer = 4 To excelExportDataView.Table.Columns.Count - 1
                    If IsNumeric(ws.Cells(i, j).Value) Then
                        ws.Cells(i, j).Value = CType(ws.Cells(i, j).Value, Double)
                    End If
                Next
            Next

            'Remove the first column
            ws.Cells.DeleteRange(0, 0, excelExportDataView.Count, 0, ShiftType.Left)

            'Process case of having Weapon System Manpower and Federal OM
            If selectedCostSummary.Value = "Weapon System Manpower" AndAlso selectedPayPlan.Value.StartsWith("A") Then
                style.HorizontalAlignment = TextAlignmentType.Left
                style.ForegroundColor = ColorTranslator.FromHtml("#FFFFFF")
                style.Font.IsBold = True
                styleFlag.FontBold = True
                ws.Cells.CreateRange(1, 3, excelExportDataView.Count - 7, 3).ApplyStyle(style, styleFlag)
                ws.Cells.CreateRange(excelExportDataView.Count - 6, 3, 5, 3).ApplyStyle(style, styleFlag)

                style.HorizontalAlignment = TextAlignmentType.Right
                'styleFlag.FontBold = False
                style.ForegroundColor = ColorTranslator.FromHtml("#DEDFDE")
                'Weapon System Manpower Total Row
                ws.Cells.CreateRange(excelExportDataView.Count - 6, 0, 1, excelExportDataView.Table.Columns.Count - 1).ApplyStyle(style, styleFlag)
                'Federal OM Total Row
                ws.Cells.CreateRange(excelExportDataView.Count - 1, 0, 1, excelExportDataView.Table.Columns.Count - 1).ApplyStyle(style, styleFlag)


            End If
        End If

        'Add a blank row
        ws.Cells.InsertRow(0)

        'Add a blank row
        ws.Cells.InsertRow(0)

        'Export the appropriation group/weapon system summary table
        InsertSummaryTable(wb, ws)

        'Add a blank row
        ws.Cells.InsertRow(0)

        ' Insert the the selected dropdown values grid at the middle
        InsertFilterSelections(wb, ws)

        'Insert the inflation rate table
        InsertInflationRateTable(wb, ws)

        ' Add the Page header at the top
        ws.Cells.InsertRow(0)
        ws.Cells.Rows(0).Item(0).Value = "AMCOS Lite"
        style = wb.CreateStyle()
        style.Font.IsBold = True
        style.Font.Size = 16
        style.ShrinkToFit = True
        styleFlag = New StyleFlag With {
            .Font = True
        }
        ws.Cells.CreateRange(0, 0, 1, 1).ApplyStyle(style, styleFlag)

        AddClassification(ws)
        ws.AutoFitColumns()
        wb.Save(Response, "AMCOSLiteData_" + Now().ToString("yyyyMMdd-HHmmss") + ".xlsx", Aspose.Cells.ContentDisposition.Attachment, New Aspose.Cells.OoxmlSaveOptions(Aspose.Cells.SaveFormat.Xlsx))
        Response.End()
    End Sub
    Private Sub InsertSummaryTable(wb As Aspose.Cells.Workbook, ws As Aspose.Cells.Worksheet)

        Dim businessRules As New Logic.PayPlan(selectedPayPlan.Value)
        Dim style As Aspose.Cells.Style
        Dim styleFlag As StyleFlag = New StyleFlag()
        Dim summaryTableStartColumn As Integer

        If selectedCostSummary.Value = "Weapon System Manpower" Then
            summaryTableStartColumn = 5
        Else
            summaryTableStartColumn = 2
        End If

        If selectedPayPlan.Value <> "CCE" And selectedCostSummary.Value <> "Ancillary" Then
            Dim AppropriationGroupDataView As DataView = CType(Session("dvForExportPartA"), DataTable).DefaultView

            'Delete the ShowOrder column
            If AppropriationGroupDataView.Table.Columns.IndexOf("ShowOrder") <> -1 Then
                AppropriationGroupDataView.Table.Columns.Remove("ShowOrder")
            End If

            ws.Cells.ImportDataView(AppropriationGroupDataView, True, 0, summaryTableStartColumn, True)

            style = wb.CreateStyle()
            style.Borders(BorderType.TopBorder).LineStyle = CellBorderType.Thin
            style.Borders(BorderType.BottomBorder).LineStyle = CellBorderType.Thin
            style.Borders(BorderType.LeftBorder).LineStyle = CellBorderType.Thin
            style.Borders(BorderType.RightBorder).LineStyle = CellBorderType.Thin
            style.Font.IsBold = True
            style.Font.Color = Color.White
            style.ForegroundColor = Color.Black
            style.Pattern = Aspose.Cells.BackgroundType.Solid
            style.ShrinkToFit = True
            style.HorizontalAlignment = TextAlignmentType.Left
            style.Number = 7
            styleFlag.FontColor = True
            styleFlag.FontBold = True
            styleFlag.CellShading = True

            ' set header row style
            ws.Cells.CreateRange(0, summaryTableStartColumn, 1, AppropriationGroupDataView.Table.Columns.Count).ApplyStyle(style, styleFlag)

            ' set the first column colors
            style.HorizontalAlignment = TextAlignmentType.Left
            For rowIndex As Integer = 1 To AppropriationGroupDataView.Count
                If selectedCostSummary.Value = "Weapon System Manpower" Then
                    style.ForegroundColor = businessRules.GetArmyCesTitleColor(ws.Cells(rowIndex, summaryTableStartColumn).Value.ToString)
                Else
                    style.ForegroundColor = businessRules.GetAppropriationGroupColor(ws.Cells(rowIndex, summaryTableStartColumn).Value.ToString)
                End If

                ws.Cells(rowIndex, summaryTableStartColumn).SetStyle(style)
            Next

            ' set the first column footer
            style.Font.Color = Color.Black
            style.ForegroundColor = ColorTranslator.FromHtml("#DEDFDE")
            ws.Cells(AppropriationGroupDataView.Count, summaryTableStartColumn).SetStyle(style)

            'Column Headers
            style.Font.IsBold = False
            style.HorizontalAlignment = TextAlignmentType.Center
            styleFlag.Borders = True
            styleFlag.FontBold = False
            styleFlag.FontColor = False
            styleFlag.CellShading = False
            styleFlag.HorizontalAlignment = True
            styleFlag.NumberFormat = True
            ws.Cells.CreateRange(0, summaryTableStartColumn, 1, AppropriationGroupDataView.Table.Columns.Count).ApplyStyle(style, styleFlag)

            ' Grid lines for data rows
            style.Font.IsBold = False
            style.HorizontalAlignment = TextAlignmentType.Right
            styleFlag.Borders = True
            styleFlag.FontBold = False
            styleFlag.FontColor = False
            styleFlag.CellShading = False
            styleFlag.HorizontalAlignment = True
            styleFlag.NumberFormat = True
            ws.Cells.CreateRange(1, summaryTableStartColumn + 1, AppropriationGroupDataView.Count, AppropriationGroupDataView.Table.Columns.Count - 1).ApplyStyle(style, styleFlag)

            ' Footer
            styleFlag.CellShading = True
            ws.Cells.CreateRange(AppropriationGroupDataView.Count, summaryTableStartColumn + 1, 1, AppropriationGroupDataView.Table.Columns.Count - 1).ApplyStyle(style, styleFlag)

            ' format the cost numbers
            For worksheetRow As Integer = 1 To AppropriationGroupDataView.Count
                For worksheetColumn As Integer = summaryTableStartColumn + 1 To AppropriationGroupDataView.Table.Columns.Count + 2
                    If IsNumeric(ws.Cells(worksheetRow, worksheetColumn).Value) Then ws.Cells(worksheetRow, worksheetColumn).Value = CType(ws.Cells(worksheetRow, worksheetColumn).Value, Double)
                Next
            Next
        End If

    End Sub
    Private Sub InsertFilterSelections(wb As Aspose.Cells.Workbook, ws As Aspose.Cells.Worksheet)

        Dim style As Aspose.Cells.Style
        Dim styleFlag As StyleFlag = New StyleFlag()
        Dim FilterSelectionsDataView As DataView = GetFiltersForPrint.DefaultView

        ws.Cells.ImportDataView(FilterSelectionsDataView, False, 0, 0, True)
        style = wb.CreateStyle()
        style.Borders(BorderType.TopBorder).LineStyle = CellBorderType.Thin
        style.Borders(BorderType.BottomBorder).LineStyle = CellBorderType.Thin
        style.Borders(BorderType.LeftBorder).LineStyle = CellBorderType.Thin
        style.Borders(BorderType.RightBorder).LineStyle = CellBorderType.Thin
        style.Font.IsBold = True
        style.ShrinkToFit = True
        styleFlag = New StyleFlag With {
            .Borders = True,
            .FontBold = False
        }
        ws.Cells.CreateRange(0, 0, FilterSelectionsDataView.Count, FilterSelectionsDataView.Table.Columns.Count).ApplyStyle(style, styleFlag)
        styleFlag.FontBold = True
        ws.Cells.CreateRange(0, 0, FilterSelectionsDataView.Count, 1).ApplyStyle(style, styleFlag)
        ws.Cells.InsertRow(0)

    End Sub
    Private Sub InsertInflationRateTable(wb As Aspose.Cells.Workbook, ws As Aspose.Cells.Worksheet)

        ' Find the row that contains 'Inflation (Base/Input Year:  2019)'
        ' This will be the value for firstRow when importing the gridview
        Dim payPlanObject As PayPlan = New PayPlan(selectedPayPlan.Value)
        Dim InflationGridImportOptions As ImportTableOptions = New ImportTableOptions()
        Dim style As Aspose.Cells.Style
        Dim styleFlag As StyleFlag = New StyleFlag()
        Dim numInflationHeaderColumns As Integer = 1
        Dim InflationCellRow As Integer

        Dim opts As FindOptions = New FindOptions With {
            .LookInType = LookInType.Values,
            .LookAtType = LookAtType.EntireContent
        }
        Dim InflationCell As Aspose.Cells.Cell = ws.Cells.Find(String.Format("Inflation (Base/Input Year:  {0})", AppSettings("DefaultYear")), Nothing, opts)

        If Not InflationCell Is Nothing Then
            InflationCellRow = InflationCell.Row
        Else
            InflationCellRow = 5
        End If

        InflationGridImportOptions.InsertRows = False
        ws.Cells.ImportGridView(InflationRatesGridView, InflationCellRow, 2, InflationGridImportOptions)

        style = wb.CreateStyle()
        style.Borders(BorderType.TopBorder).LineStyle = CellBorderType.Thin
        style.Borders(BorderType.BottomBorder).LineStyle = CellBorderType.Thin
        style.Borders(BorderType.LeftBorder).LineStyle = CellBorderType.Thin
        style.Borders(BorderType.RightBorder).LineStyle = CellBorderType.Thin
        style.Font.IsBold = True
        style.Font.Color = Color.White
        style.ForegroundColor = Color.Black
        style.Pattern = Aspose.Cells.BackgroundType.Solid
        style.ShrinkToFit = True
        style.HorizontalAlignment = TextAlignmentType.Left
        style.Number = 7
        styleFlag.FontColor = True
        styleFlag.FontBold = True
        styleFlag.CellShading = True

        'how many columns?
        If payPlanObject.GetTags().Contains("Active Military") Or payPlanObject.GetTags().Contains("National Guard") Or payPlanObject.GetTags().Contains("Reserves") Then
            numInflationHeaderColumns = 7
        ElseIf payPlanObject.GetTags().Contains("Civilian") Or payPlanObject.GetTags().Contains("GFEBS") Or payPlanObject.GetTags().Contains("Wage") Then
            numInflationHeaderColumns = 4
        ElseIf selectedPayPlan.Value = "CCE" Then
            numInflationHeaderColumns = 2
        End If

        ' set header row style
        ws.Cells.CreateRange(InflationCellRow, 2, 1, numInflationHeaderColumns).ApplyStyle(style, styleFlag)

    End Sub
    Private Function GetCostDataForExport(Costs As DataTable) As DataTable

        If Costs.Columns.IndexOf("Description") <> -1 Then
            Costs.Columns.Remove("Description")
        End If

        For i As Integer = 5 To Costs.Columns.Count - 1
            If IsNumeric(Costs.Columns(i).ColumnName) Then
                Select Case selectedPayPlan.Value
                    Case "SES"
                        If Costs.Columns(i).ColumnName = "1" Then
                            Costs.Columns(i).ColumnName = "MIN"
                        End If
                        If Costs.Columns(i).ColumnName = "2" Then
                            Costs.Columns(i).ColumnName = "AVG"
                        End If
                        If Costs.Columns(i).ColumnName = "3" Then
                            Costs.Columns(i).ColumnName = "MAX"
                        End If
                End Select
            End If
        Next

        If Costs.Select("[Cost Element Name]='Total'").Length = 0 And selectedPayPlan.Value <> "CCE" And selectedCostSummary.Value <> "Ancillary" Then
            Dim dr As DataRow = Costs.NewRow
            dr(costsGridCostElementNameColumnIndex) = "Total"
            For i As Integer = costsGridCostElementNameColumnIndex + 1 To Costs.Columns.Count - 1
                dr(i) = Costs.Compute("Sum([" + Costs.Columns(i).ColumnName + "])", "1=1")
            Next
            Costs.Rows.Add(dr)
        End If


        'Delete zero value rows
        Dim rowFilter As String = "([Cost Element Name] = 'Avg Cost of Weapon Specific Training' OR [Cost Element Name] = 'Avg Cost of Weapon Specific Training (Amortized)' OR [Cost Element Name] = 'Avg Fixed Cost of Weapon Specific Training' OR [Cost Element Name] = 'Avg Fixed Cost of Weapon Specific Training (Amortized)')"
        For tableColumn As Integer = Costs.Columns.IndexOf("[Cost Element Name]") + 1 To Costs.Columns.Count - 1
            rowFilter = rowFilter + " AND ([" + Costs.Columns(tableColumn).ColumnName + "] = '0')"
        Next
        Dim foundRows() As DataRow

        foundRows = Costs.Select(rowFilter)

        For i = 0 To foundRows.GetUpperBound(0)
            foundRows(i).Delete()
        Next i

        Costs.AcceptChanges()

        Return Costs
    End Function
    Private Sub PopulateRateHeader(ConversionType As String, PayPlan As String, Year As String, AmcosVersionId As Integer)

        Dim payPlanObject As PayPlan = New PayPlan(PayPlan)
        Dim SqlStatement As String = ""

        If payPlanObject.GetTags().Contains("Active Military") Then
            SqlStatement = "SELECT [Appropriation], [MPA], [MPA Non-Pay], [OMA], [OMA_1], [OMDW], [Federal OM] FROM web.GetInflationRateHeader(@ConversionType,@Year,@AmcosVersionId);"
        ElseIf payPlanObject.GetTags().Contains("National Guard") Then
            SqlStatement = "SELECT [Appropriation], [NGPA], [MPA], [OMNG], [OMA], [OMA_1], [OMNG_1] FROM web.GetInflationRateHeader(@ConversionType,@Year,@AmcosVersionId);"
        ElseIf payPlanObject.GetTags().Contains("Reserves") Then
            SqlStatement = "SELECT [Appropriation], [RPA], [MPA], [OMAR], [OMA], [OMA_1], [OMAR_1] FROM web.GetInflationRateHeader(@ConversionType,@Year,@AmcosVersionId);"
        ElseIf payPlanObject.GetTags().Contains("Civilian") Or payPlanObject.GetTags().Contains("GFEBS") Or payPlanObject.GetTags().Contains("Wage") Then
            SqlStatement = "SELECT [Appropriation], [Army CivPay], [OMA], [Federal OM] FROM web.GetInflationRateHeader(@ConversionType,@Year,@AmcosVersionId);"
        ElseIf PayPlan = "CCE" Then
            SqlStatement = "SELECT [Appropriation], [OMA] FROM web.GetInflationRateHeader(@ConversionType,@Year,@AmcosVersionId);"
        End If

        If SqlStatement <> "" Then
            Using connection As New SqlConnection(ConnectionStrings("AmcosAdo").ConnectionString)
                connection.Open()
                Using command As SqlCommand = New SqlCommand(SqlStatement, connection)
                    command.Parameters.AddWithValue("@ConversionType", ConversionType)
                    command.Parameters.AddWithValue("@Year", Year)
                    command.Parameters.AddWithValue("@AmcosVersionId", AmcosVersionId)
                    command.CommandType = CommandType.Text
                    Using reader As SqlDataReader = command.ExecuteReader()
                        InflationRatesGridView.DataSource = reader
                        InflationRatesGridView.DataBind()
                        InflationRatesGridView.Visible = True
                    End Using
                End Using
            End Using
        End If

    End Sub
    Private Sub InflationRatesGridView_RowDataBound(sender As Object, e As GridViewRowEventArgs) Handles InflationRatesGridView.RowDataBound

        If e.Row.RowType = DataControlRowType.DataRow Then
            For Each cell As TableCell In e.Row.Cells
                If IsNumeric(cell.Text) Then
                    cell.Text = FormatPercent(cell.Text, 4)
                End If
            Next
        End If

    End Sub
    Private Function RenameColumns(dv As DataView) As DataView

        If dv.Table.Columns.IndexOf("ShowOrder") <> -1 Then
            dv.Table.Columns.Remove("ShowOrder")
        End If

        Return dv

    End Function
End Class
