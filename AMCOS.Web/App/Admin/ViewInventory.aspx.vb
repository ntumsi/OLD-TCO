Imports AMCOS.Logic

Partial Class ViewInventory
    Inherits BasePage

    Private dtDev As DataTable

    Protected Sub form1_Load(sender As Object, e As System.EventArgs) Handles form1.Load
        lblPayPlan.Text = Request.QueryString("PayPlan")
        lblGroup.Text = Request.QueryString("Group")
        lblSubGroup.Text = Request.QueryString("SubGroup")

        dtDev = DataAccessUtility.GetDataTableByDynamicSql("select GradeLevel, sum(Inventory) as Development from data.Inventory where PayPlan='" + Request.QueryString("PayPlan") + "'", {(Request.QueryString("Group").IndexOf("ALL") < 0), (Request.QueryString("SubGroup").IndexOf("ALL") < 0)},
                    {"CategoryGroupCode", "CategorySubGroupCode"}, {Request.QueryString("Group"), Request.QueryString("SubGroup")}, " group by GradeLevel order by GradeLevel")

        Dim dtProd As DataTable = DataAccessUtility.GetDataTableByDynamicSql("select GradeLevel, sum(Amount) as Production from tblData_Inventory_Prod where PayPlan='" + Request.QueryString("PayPlan") + "'", {(Request.QueryString("Group").IndexOf("ALL") < 0), (Request.QueryString("SubGroup").IndexOf("ALL") < 0)},
                    {"Group", "CategorySubGroupCode"}, {Request.QueryString("Group"), Request.QueryString("SubGroup")}, " group by GradeLevel order by GradeLevel")

        For Each drP As DataRow In dtProd.Rows
            If dtDev.Select("GradeLevel=" & drP("GradeLevel").ToString).Length = 0 Then
                dtDev.Rows.Add(New Object() {drP(0), 0})
            End If
        Next
        dtDev.AcceptChanges()

        For Each drD As DataRow In dtDev.Rows
            If dtProd.Select("GradeLevel=" & drD("GradeLevel").ToString).Length = 0 Then
                dtProd.Rows.Add(New Object() {drD(0), 0})
            End If
        Next
        dtDev.AcceptChanges()

        dtDev.Columns.Add(New DataColumn("Production", GetType(Integer)))
        dtDev.Columns.Add(New DataColumn("Diff", GetType(Integer)))
        dtDev.Columns.Add(New DataColumn("Diff in %", GetType(String)))
        For Each drD As DataRow In dtDev.Rows
            Dim drP As DataRow = dtProd.Select("GradeLevel=" & drD("GradeLevel").ToString)(0)
            drD("Production") = drP("Production")
            drD("Diff") = Convert.ToDecimal(drD("Development")) - Convert.ToDecimal(drP("Production"))
            If Convert.ToDecimal(drP("Production")) = 0 Then
                drD("Diff in %") = "_"
            Else
                Dim d As Double = 1.0 * Convert.ToDouble(drD("Diff")) / Convert.ToDouble(drP("Production"))
                drD("Diff in %") = d.ToString("P")
            End If

        Next
        dtDev.AcceptChanges()

        gvDiffDP.DataSource = New DataView(dtDev, "", "GradeLevel", DataViewRowState.CurrentRows)
        gvDiffDP.DataBind()
    End Sub

    Protected Sub gvDiffDP_RowDataBound(sender As Object, e As System.Web.UI.WebControls.GridViewRowEventArgs) Handles gvDiffDP.RowDataBound
        Dim oRow As GridViewRow = e.Row
        If oRow.Cells.Count > 1 Then
            If oRow.RowType = DataControlRowType.Header Then
                For Each oCell As TableCell In oRow.Cells
                    If IsNumeric(oCell.Text) Then
                        Select Case lblPayPlan.Text
                            Case "AE", "RE", "NE"
                                oCell.Text = "E" + oCell.Text
                            Case "AO", "RO", "NO"
                                oCell.Text = "O" + oCell.Text
                            Case "AWO", "RWO", "NWO"
                                oCell.Text = "W" + oCell.Text
                            Case "SES"
                                Select Case oCell.Text
                                    Case "1"
                                        oCell.Text = "MIN"
                                    Case "2"
                                        oCell.Text = "AVG"
                                    Case "3"
                                        oCell.Text = "MAX"
                                    Case Else
                                        oCell.Text = "Error"
                                End Select
                            Case "CCE"
                                ' do nothing
                            Case Else
                                oCell.Text = lblPayPlan.Text + oCell.Text
                        End Select
                    End If
                Next
            End If

            If oRow.RowType = DataControlRowType.DataRow Then
                If oRow.Cells(3).Text = "0" Then oRow.Cells(3).Text = ""
                If oRow.Cells(3).Text.StartsWith("-") Then
                    oRow.Cells(3).Text = "(" + oRow.Cells(3).Text.Substring(1) + ")"
                    oRow.Cells(3).ForeColor = Drawing.Color.Red
                End If
                If oRow.Cells(4).Text = "0.00 %" Then oRow.Cells(4).Text = ""
                If oRow.Cells(4).Text.StartsWith("-") Then
                    oRow.Cells(4).Text = "(" + oRow.Cells(4).Text.Substring(1) + ")"
                    oRow.Cells(4).ForeColor = Drawing.Color.Red
                End If
            End If

            If oRow.RowType = DataControlRowType.Footer Then
                oRow.Cells(0).Text = "Total"

                Dim dTotalDev As Decimal = Convert.ToDecimal(dtDev.Compute("sum(Development)", ""))
                oRow.Cells(1).Text = dTotalDev.ToString
                Dim dTotalProd As Decimal = Convert.ToDecimal(dtDev.Compute("sum(Production)", ""))
                oRow.Cells(2).Text = dTotalProd.ToString

                oRow.Cells(3).Text = (dTotalDev - dTotalProd).ToString
                If oRow.Cells(3).Text = "0" Then oRow.Cells(3).Text = ""
                If oRow.Cells(3).Text.StartsWith("-") Then
                    oRow.Cells(3).Text = "(" + oRow.Cells(3).Text.Substring(1) + ")"
                    oRow.Cells(3).ForeColor = Drawing.Color.Red
                End If

                If oRow.Cells(3).Text = "" Then
                    oRow.Cells(4).Text = ""
                Else
                    If dTotalProd = 0 Then
                        oRow.Cells(4).Text = "_"
                    Else
                        Dim dd As Double = (Convert.ToDouble(dTotalDev) - Convert.ToDouble(dTotalProd)) / Convert.ToDouble(dTotalProd)
                        oRow.Cells(4).Text = dd.ToString("P")
                        If oRow.Cells(4).Text.StartsWith("-") Then
                            oRow.Cells(4).Text = "(" + oRow.Cells(4).Text.Substring(1) + ")"
                            oRow.Cells(4).ForeColor = Drawing.Color.Red
                        End If
                    End If
                End If

            End If
        End If

    End Sub

End Class
