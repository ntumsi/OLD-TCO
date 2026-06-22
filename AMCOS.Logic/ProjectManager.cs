using System;
using System.Collections.Generic;
using System.Data;
using Npgsql;
using NpgsqlTypes;
using System.Linq;
using AMCOS.Data;
using AMCOS.Data.Entities;

namespace AMCOS.Logic
{
    public class ProjectManager
    {
        public string Appropriation { get; set; }
        public string UserId { get; set; }
        public int ProjectId { get; set; }
        public int CategoryId { get; set; }
        public ProjectManager()
        {
            //Default constructor
        }
        public ProjectManager(string userId, int projectId, int categoryId)
        {
            UserId = userId;
            ProjectId = projectId;
            CategoryId = categoryId;
        }        
        public void BuildExcelWorksheet(DataTable discountedCosts, int costElementNameColumnIndex)
        {
            //License license = new License();
            //license.SetLicense("Aspose.Cells.lic");

            //Workbook wb = new Workbook();
            //Worksheet ws = wb.Worksheets[0];
            //DataView dv;
            //Style style;
            //StyleFlag styleFlag;

            ////Export the discounted Cost grid 
            //dv = new DataView(DiscountedCosts, "", "seqOrder", DataViewRowState.CurrentRows);

            //ws.Cells.ImportDataView(dv, true, 0, 0, true);

            ////Set header row style
            //style = wb.CreateStyle();
            //style.Borders[BorderType.TopBorder].LineStyle = CellBorderType.Thin;
            //style.Borders[BorderType.BottomBorder].LineStyle = CellBorderType.Thin;
            //style.Borders[BorderType.LeftBorder].LineStyle = CellBorderType.Thin;
            //style.Borders[BorderType.RightBorder].LineStyle = CellBorderType.Thin;
            //style.Number = 0;
            //style.Font.IsBold = true;
            //style.Font.Color = Color.White;
            //style.ForegroundColor = Color.Black;
            //style.Pattern = Aspose.Cells.BackgroundType.Solid;
            //style.ShrinkToFit = true;
            //style.HorizontalAlignment = Aspose.Cells.TextAlignmentType.Center;

            //styleFlag = new StyleFlag();
            //styleFlag.Borders = true;
            //styleFlag.FontBold = true;
            //styleFlag.FontColor = true;
            //styleFlag.CellShading = true;
            //styleFlag.HorizontalAlignment = true;
            //styleFlag.NumberFormat = true;

            ////Set header row style
            //ws.Cells.CreateRange(0, 0, 1, dv.Table.Columns.Count - 1).ApplyStyle(style, styleFlag);

            ////Set all grid lines
            //style.Font.IsBold = false;
            //style.Font.Color = Color.Black;
            //style.ForegroundColor = Color.White;
            //style.HorizontalAlignment = TextAlignmentType.Left;
            //ws.Cells.CreateRange(1, 0, dv.Count, CostElementNameColumnIndex + 1).ApplyStyle(style, styleFlag);

            ////The number columns right alignment
            //style.HorizontalAlignment = TextAlignmentType.Right;
            //style.Number = 7;
            //ws.Cells.CreateRange(1, CostElementNameColumnIndex + 1, dv.Count, DiscountedCosts.Columns.Count - CostElementNameColumnIndex - 2).ApplyStyle(style, styleFlag);

            ////Set the APPN column colors
            //style.Font.IsBold = true;
            //style.Font.Color = Color.White;
            //style.ForegroundColor = Color.Black;
            //style.HorizontalAlignment = TextAlignmentType.Left;
            //for (int i = 1; i <= dv.Count; i++)
            //{
            //    int iColor = GetAppropriationForegroundAgrbColor(ws.Cells[i, CostElementNameColumnIndex - 2].Value.ToString());
            //    style.ForegroundArgbColor = iColor;
            //    ws.Cells[i, CostElementNameColumnIndex - 2].SetStyle(style);
            //}

            ////Set the _CostElementCol column  color for Total lines
            //for (int i = 1; i <= dv.Count; i++)
            //{
            //    string sLastDigitOfSeqNo = ws.Cells[i, dv.Table.Columns.Count - 1].Value.ToString();
            //    sLastDigitOfSeqNo = sLastDigitOfSeqNo.Substring(sLastDigitOfSeqNo.Length - 1);

            //    if (sLastDigitOfSeqNo != "0")
            //    {
            //        style.Font.IsBold = true;
            //        style.Font.Color = Color.White;
            //        style.HorizontalAlignment = TextAlignmentType.Right;
            //        switch (sLastDigitOfSeqNo)
            //        {
            //            case "1":
            //                style.ForegroundArgbColor = colorArgbSumArmy;
            //                break;
            //            case "2":
            //                style.ForegroundArgbColor = colorArgbSumDOD;
            //                break;
            //            case "3":
            //                style.ForegroundArgbColor = colorArgbSumFed;
            //                break;
            //            case "4":
            //                style.ForegroundArgbColor = colorArgbArngOM;
            //                break;
            //            case "5":
            //                style.ForegroundArgbColor = colorArgbUsarOM;
            //                break;
            //            case "6":
            //                style.ForegroundArgbColor = colorArgbCce;
            //                break;
            //            case "8":
            //                style.ForegroundColor = Color.Yellow;
            //                style.Font.Color = Color.Black;
            //                break;
            //            case "9":
            //                style.ForegroundColor = Color.Black;
            //                style.Font.Color = Color.White;
            //                style.HorizontalAlignment = TextAlignmentType.Left;

            //                if (ws.Cells[i, 0].Value.ToString() == "LastDividerLine")
            //                {
            //                    ws.Cells[i, 0].Value = "";
            //                    ws.Cells[i, CostElementNameColumnIndex].Value = "TOTAL APPN COST SUMMARY: ";
            //                    ws.Cells.CreateRange(i, CostElementNameColumnIndex, 1, DiscountedCosts.Columns.Count - CostElementNameColumnIndex - 1).ApplyStyle(style, styleFlag);
            //                    for (int j = CostElementNameColumnIndex + 1; j <= DiscountedCosts.Columns.Count - 2; j++)
            //                    {
            //                        ws.Cells[i, j].Value = "";
            //                    }
            //                }
            //                else
            //                {
            //                    ws.Cells[i, 0].Value = "BEGINNING OF SUB-PROJECT: ";
            //                    ws.Cells.CreateRange(i, 0, 1, DiscountedCosts.Columns.Count - 1).ApplyStyle(style, styleFlag);
            //                    for (int j = CostElementNameColumnIndex; j <= DiscountedCosts.Columns.Count - 2; j++)
            //                    {
            //                        ws.Cells[i, j].Value = "";
            //                    }
            //                }
            //                break;

            //                //    ' for plm
            //                //'    If IsNumeric(e.Row.Cells(i).Text) AndAlso e.Row.Cells(i).Text <> "$0.00" Then
            //                //'        e.Row.Cells(i).ForeColor = Color.White
            //                //'    Else
            //                //'        e.Row.Cells(i).ForeColor = Color.Black
            //                //'        e.Row.Cells(i).Text = ""
            //                //'    End If
            //        }
            //        ws.Cells[i, CostElementNameColumnIndex].SetStyle(style);
            //        //Format the cost numbers
            //        for (int j = CostElementNameColumnIndex + 1; j <= dtD.Columns.Count - 2; j++)
            //        {
            //            if (IsNumeric(ws.Cells[i, j].Value))
            //            {
            //                ws.Cells[i, j].SetStyle(style);
            //            }
            //        }
            //    }
            //    //Format the cost numbers
            //    for (int j = CostElementNameColumnIndex + 1; j <= dtD.Columns.Count - 2; j++)
            //    {
            //        if (Information.IsNumeric(ws.Cells[i, j].Value))
            //        {
            //            ws.Cells[i, j].Value = CType(ws.Cells[i, j].Value, double);
            //        }
            //    }
            //}

            ////Remove the last column
            //ws.Cells.DeleteRange(0, dv.Table.Columns.Count - 1, dv.Count, dv.Table.Columns.Count - 1, Aspose.Cells.ShiftType.None);

            //ws.Cells.InsertRow(0);
            //ws.Cells.InsertRow(0);
            //ws.Cells.InsertRow(0);

            //ws.Cells.CopyRows(ws.Cells, 0, dv.Count + 4, dv.Count + 4);

            //ws.Cells[1, 0].Value = "Default Summary";
            //ws.Cells[dv.Count + 5, 0].Value = "Discounted Default Summary";
            //style.ForegroundColor = Color.White;
            //style.Font.Color = Color.Black;
            //style.Font.IsBold = true;
            //style.Font.IsItalic = true;
            //style.Font.Underline = Aspose.Cells.FontUnderlineType.Single;
            //style.Font.Size = 14;
            //style.Borders[BorderType.TopBorder].LineStyle = Aspose.Cells.CellBorderType.None;
            //style.Borders[BorderType.BottomBorder].LineStyle = Aspose.Cells.CellBorderType.None;
            //style.Borders[BorderType.LeftBorder].LineStyle = Aspose.Cells.CellBorderType.None;
            //style.Borders[BorderType.RightBorder].LineStyle = Aspose.Cells.CellBorderType.None;

            //style.HorizontalAlignment = Aspose.Cells.TextAlignmentType.Left;
            //ws.Cells[1, 0].SetStyle(style);
            //ws.Cells[dv.Count + 5, 0].SetStyle(style);

            //// discount the values here !
            //_discountFactorTable = CType(Session("discountFactorTable"), DataTable);
            //for (int i = dv.Count + 8; i <= 2 * dv.Count + 7; i++)
            //{
            //    for (int j = CostElementNameColumnIndex + 1; j <= dv.Table.Columns.Count - 2; j++)
            //    {
            //        decimal discnt = CType(_discountFactorTable.Rows(0)(j - CostElementNameColumnIndex), decimal);
            //        try
            //        {
            //            ws.Cells[i, j].Value = discnt * CDbl(ws.Cells[i, j].Value);
            //        }
            //        catch (Exception e)
            //        {
            //            //do nothing, just for skipping the row of "Beginining Subproject"
            //        }
            //    }
            //}

            //// ** NOTE line
            //ws.Cells.InsertRow(0);
            //ws.Cells.Merge(0, 0, 1, 9);
            //ws.Cells[0, 0].Value = "**NOTE - Cost Values are not inflated for ""Average Cost of Special Pays"".";
            //style.ForegroundColor = Color.White;
            //style.Font.Color = Color.Black;
            //style.Font.IsBold = true;
            //style.Font.IsItalic = false;
            //style.Font.Underline = Aspose.Cells.FontUnderlineType.None;
            //style.Font.Size = 12;
            //style.Borders[BorderType.TopBorder].LineStyle = Aspose.Cells.CellBorderType.None;
            //style.Borders[BorderType.BottomBorder].LineStyle = Aspose.Cells.CellBorderType.None;
            //style.Borders[BorderType.LeftBorder].LineStyle = Aspose.Cells.CellBorderType.None;
            //style.Borders[BorderType.RightBorder].LineStyle = Aspose.Cells.CellBorderType.None;

            //style.HorizontalAlignment = Aspose.Cells.TextAlignmentType.Left;
            //style.IsTextWrapped = true;
            //style.Number = 0; //Set to normal number format without $ any more
            //ws.Cells[0, 0].SetStyle(style);

            ////NOTE: section
            //ws.Cells.InsertRow(0);
            //ws.Cells.InsertRow(0);
            //ws.Cells.InsertRow(0);
            //ws.Cells.InsertRow(0);
            //ws.Cells.InsertRow(0);
            //ws.Cells.InsertRow(0);
            //ws.Cells.Merge(0, 0, 5, 19);
            //ws.Cells[0, 0].SetStyle(style);
            //StringBuilder Note = new StringBuilder("NOTE: For analysts costing overseas positions, consider adding Civilian \"Discount Groceries (OCONUS Only)\" costs, if required, apply the following:" + System.Environment.NewLine);
            //sb.Append("   " + Strings.Chr(149) + "  For the AMCOS base year, add Discount Groceries (OCONUS Only) costs found on the Full Cost of Manpower (FCoM) web site http://fcom.cape.osd.mil/." + System.Environment.NewLine);
            //sb.Append("   " + Strings.Chr(149) + "  For future year \"Default Summary\" cost element projections, multiply the Discount Groceries Factor by the \"Civilian DoD OMA\" inflation factor for the desired year." + System.Environment.NewLine);
            //sb.Append("   " + Strings.Chr(149) + "  For future year \"Discounted Default Summary\" cost element projections, multiply the Default Summary \"Discount Groceries (OCONUS Only)\" costs for the desired year by the corresponding year's Discounting and Present Value Factor (PVF). " + System.Environment.NewLine);
            //ws.Cells[0, 0].Value = Note;
            //style.VerticalAlignment = TextAlignmentType.Top;
            //style.ShrinkToFit = true;
            //ws.Cells[0, 0].SetStyle(style);
            //ws.Cells.InsertRow(0);

            ////Cost Lines 2
            //ws.Cells.InsertRow(0);
            //ws.Cells.Merge(0, 0, 1, 9);
            //style.Font.IsBold = false;
            //ws.Cells[0, 0].Value = "The Costing Reports are produced both with and without the discount rate the analyst inputs to the cost estimate.";
            //ws.Cells[0, 0].SetStyle(style);

            //ws.Cells.InsertRow(0);
            //ws.Cells.InsertRow(0);
            //style.Font.IsBold = true;
            //style.Font.Size = 14;
            //ws.Cells[0, 0].SetStyle(style);
            //ws.Cells[0, 0].Value = "Cost";

            //ws.Cells.InsertRow(0);

            ////Inventory grid
            //ImportTableOptions importOptions = new ImportTableOptions();
            //importOptions.InsertRows = true;
            //importOptions.ConvertNumericData = false;
            //importOptions.ConvertGridStyle = false;
            //ws.Cells.ImportGridView(gvProjectInventory, 0, 0, importOptions);
            //for (int i = 0; i <= gvProjectInventory.Rows.Count - 1; i++)
            //{
            //    for (int j = 0; j <= gvProjectInventory.HeaderRow.Cells.Count - 1; j++)
            //    {
            //        if (ws.Cells[i, j].Value.ToString() == "&nbsp;")
            //            ws.Cells[i, j].Value = "";

            //        if ((Information.IsNumeric(gvProjectInventory.HeaderRow.Cells(j).Text)) || (gvProjectInventory.HeaderRow.Cells(j).Text == "Overhead %") AndAlso(IsNumeric(ws.Cells[i, j].Value))
            //        {
            //            ws.Cells[i, j].Value = CType(ws.Cells[i, j].Value, int);
            //        }
            //    }
            //}
            //ws.Cells.InsertRow(0);
            //for (int j = 0; j <= gvProjectInventory.HeaderRow.Cells.Count - 1; j++)
            //{
            //    ws.Cells[0, j].Value = gvProjectInventory.HeaderRow.Cells(j).Text;
            //}
            //style.Font.IsBold = false;
            //style.Font.Size = 10;
            //style.Borders[BorderType.TopBorder].LineStyle = CellBorderType.Thin;
            //style.Borders[BorderType.BottomBorder].LineStyle = CellBorderType.Thin;
            //style.Borders[BorderType.LeftBorder].LineStyle = CellBorderType.Thin;
            //style.Borders[BorderType.RightBorder].LineStyle = CellBorderType.Thin;

            //ws.Cells.CreateRange(1, 0, gvProjectInventory.Rows.Count, gvProjectInventory.HeaderRow.Cells.Count).ApplyStyle(style, styleFlag);
            //style.Font.IsBold = true;
            //style.Font.Color = Color.White;
            //style.ForegroundColor = Color.Navy;
            //ws.Cells.CreateRange(0, 0, 1, gvProjectInventory.HeaderRow.Cells.Count).ApplyStyle(style, styleFlag);

            //ws.Cells.InsertRow(0);
            //ws.Cells.InsertRow(0);
            //ws.Cells[0, 0].Value = "Inventory";
            //style.Font.IsBold = true;
            //style.Font.Size = 14;
            //style.Borders[BorderType.TopBorder].LineStyle = Aspose.Cells.CellBorderType.None;
            //style.Borders[BorderType.BottomBorder].LineStyle = Aspose.Cells.CellBorderType.None;
            //style.Borders[BorderType.LeftBorder].LineStyle = Aspose.Cells.CellBorderType.None;
            //style.Borders[BorderType.RightBorder].LineStyle = Aspose.Cells.CellBorderType.None;
            //style.Font.Color = Color.Black;
            //style.ForegroundColor = Color.White;
            //ws.Cells[0, 0].SetStyle(style);

            //ws.Cells.InsertRow(0);

            ////Discounting and Present Value Factor (PVF) section
            //ws.Cells.ImportDataTable(_discountFactorTable, true, 0, 0, true);
            //style.Font.Size = 10;
            //style.Borders[BorderType.TopBorder].LineStyle = Aspose.Cells.CellBorderType.Thin;
            //style.Borders[BorderType.BottomBorder].LineStyle = Aspose.Cells.CellBorderType.Thin;
            //style.Borders[BorderType.LeftBorder].LineStyle = Aspose.Cells.CellBorderType.Thin;
            //style.Borders[BorderType.RightBorder].LineStyle = Aspose.Cells.CellBorderType.Thin;
            //ws.Cells.CreateRange(0, 0, 1, _discountFactorTable.Columns.Count).ApplyStyle(style, styleFlag);
            //for (int j = 1; j <= _discountFactorTable.Columns.Count - 1; j++)
            //{
            //    ws.Cells[1, j].Value = CType(ws.Cells[1, j].Value, double);
            //}

            //style.Font.IsBold = false;
            //ws.Cells.CreateRange(1, 0, 1, _discountFactorTable.Columns.Count).ApplyStyle(style, styleFlag);

            //ws.Cells.InsertRow(0);
            //ws.Cells[0, 0].Value = "Discount Rates Based on " & lblYearForTheDiscount.Text & " Years Securities:";
            //style.Font.IsBold = true;
            //style.Borders[BorderType.TopBorder].LineStyle = CellBorderType.None;
            //style.Borders[BorderType.BottomBorder].LineStyle = CellBorderType.None;
            //style.Borders[BorderType.LeftBorder].LineStyle = CellBorderType.None;
            //style.Borders[BorderType.RightBorder].LineStyle = CellBorderType.None;
            //ws.Cells.Merge(0, 0, 1, 9);
            //ws.Cells[0, 0].SetStyle(style);


            //ws.Cells.InsertRow(0);
            //ws.Cells.InsertRow(0);
            //ws.Cells.Merge(0, 0, 1, 19);
            //ws.Cells[0, 0].Value = "Most cost comparison techniques take into consideration the time value of money, that is, a dollar today is worth some amount less in the future. Discount rates are prepared annually by the Office of Management and Budget (OMB).  OMB Circular A-94 and Department of Defense Instruction (DoDI) 7041.3 require the use of a discount rate based on the Treasury Department cost of borrowing funds, and reflect the expected cost of borrowing for 3, 5, 7, 10, 20, and 30 years securities.";

            //ws.Cells.InsertRow(0);
            //ws.Cells.InsertRow(0);
            //ws.Cells[0, 0].Value = "Discounting and Present Value Factor (PVF)";
            //style.Font.IsBold = true;
            //style.Font.Size = 14;
            //style.ShrinkToFit = true;
            //ws.Cells[0, 0].SetStyle(style);
            //ws.Cells.InsertRow(0);

            //ws.Cells.InsertRow(0);
            //ws.Cells.InsertRow(0);
            //ws.Cells.InsertRow(0);
            //ws.Cells.InsertRow(0);
            //ws.Cells.InsertRow(0);
            //ws.Cells.Merge(0, 0, 5, 12);
            //StringBuilder projectStartYearNote = new StringBuilder("The Project Start Year (YearStart) is set to " + _projectStartYear.ToString("#") + " and the number of years (YearDuration) is set to 5 years for costing an Active Duty position with the focus on \"SALARY\" cost element:" + System.Environment.NewLine);
            //projectStartYearNote.Append("   " + Strings.Chr(149) + "  " + _projectStartYear.ToString("#") + " Active Duty Salary = (AMCOS LITE \"Avg Cost Base Pay (Military)\" BASE YEAR SALARY) * (" + _projectStartYear.ToString("#") + " Active Duty MPA Inflation Factor)" + System.Environment.NewLine;
            //projectStartYearNote.Append("   " + Strings.Chr(149) + "  " + (_projectStartYear + 1).ToString("#") + " Active Duty Salary = (AMCOS LITE \"Avg Cost Base Pay (Military)\" BASE YEAR SALARY) * (" + (_projectStartYear + 1).ToString("#") + " Active Duty MPA Inflation Factor)" + System.Environment.NewLine;
            //projectStartYearNote.Append("   " + Strings.Chr(149) + "  " + (_projectStartYear + 2).ToString("#") + " Active Duty Salary = (AMCOS LITE \"Avg Cost Base Pay (Military)\" BASE YEAR SALARY) * (" + (_projectStartYear + 2).ToString("#") + " Active Duty MPA Inflation Factor)" + System.Environment.NewLine;
            //ws.Cells[0, 0].Value = s;
            //style.Font.Size = 10;
            //style.Font.IsBold = false;
            //style.ShrinkToFit = true;
            //ws.Cells[0, 0].SetStyle(style);

            //ws.Cells.InsertRow(0);
            //ws.Cells.Merge(0, 0, 1, 12);
            //ws.Cells[0, 0].Value = "For Example";
            //style.Font.IsBold = true;
            //style.Font.Underline = Aspose.Cells.FontUnderlineType.Single;
            //style.Borders[BorderType.BottomBorder].LineStyle = Aspose.Cells.CellBorderType.None;
            //ws.Cells[0, 0].SetStyle(style);

            //ws.Cells.InsertRow(0);
            //ws.Cells.Merge(0, 0, 1, 12);
            //ws.Cells[0, 0].Value = "In Project Manager (PM), the Fiscal Year (FY) costs generated in AMCOS LITE will be referred to as \"BASE YEAR\" costs. PM multiplies BASE YEAR costs by the appropriate target year INFLATION FACTOR generating Future Start Year and/or Future Year Cost Element costs across the entire duration.";
            //style.Font.IsBold = false;
            //style.Font.Underline = Aspose.Cells.FontUnderlineType.None;
            //ws.Cells[0, 0].SetStyle(style);

            //ws.Cells.InsertRow(0);
            //ws.Cells.Merge(0, 0, 1, 12);
            //ws.Cells[0, 0].Value = "Inflation Calculation Note:";
            //style.Font.IsBold = true;
            //style.Font.Underline = Aspose.Cells.FontUnderlineType.Single;
            //ws.Cells[0, 0].SetStyle(style);

            ////Inflation Factors
            //DataTable dtRate = CType(Session("dvForExportPart0"), DataTable);
            //ws.Cells.ImportDataTable(dtRate, true, 0, 0, true);
            //for (int i = 1; i <= dtRate.Rows.Count; i++)
            //{
            //    for (int j = 1; j <= dtRate.Columns.Count - 1; j++)
            //    {
            //        decimal val = CType(ws.Cells[i, j].Value, Decimal);
            //        ws.Cells[i, j].Value = val.ToString("0.0000");
            //        ws.Cells[i, j].Value = CType(ws.Cells[i, j].Value, double);
            //    }
            //}
            //style.Borders[BorderType.TopBorder].LineStyle = CellBorderType.Thin;
            //style.Borders[BorderType.BottomBorder].LineStyle = CellBorderType.Thin;
            //style.Borders[BorderType.LeftBorder].LineStyle = CellBorderType.Thin;
            //style.Borders[BorderType.RightBorder].LineStyle = CellBorderType.Thin;
            //ws.Cells.CreateRange(1, 0, dtRate.Rows.Count, dtRate.Columns.Count).ApplyStyle(style, styleFlag);

            //ws.Cells[0, 3].Value = "DoD-OMA (Civ)";
            //ws.Cells[0, 4].Value = "FED-OMA (Civ)";
            //ws.Cells[0, 8].Value = "DoD-OMA (Mil)";
            //ws.Cells[0, 9].Value = "FED-OMA (Mil)";
            //style.Font.IsBold = true;
            //style.Font.Color = Color.White;
            //style.ForegroundColor = Color.Navy;
            //ws.Cells.CreateRange(0, 0, 1, dtRate.Columns.Count).ApplyStyle(style, styleFlag);

            //ws.Cells.InsertRow(0);
            //ws.Cells.InsertRow(0);
            //ws.Cells.InsertRow(0);
            //ws.Cells.InsertRow(0);
            //ws.Cells.Merge(0, 0, 3, 15);
            //ws.Cells[0, 0].Value = "The current Joint Inflation Calculator (JIC) found on the OASA (FM&C) website, htp://asafm.army.mil/offices/CE/Rates.aspx?OfficeCode=1400, is the source for the fourteen (14) inflation factors built into Project Manager (PM).  Each component (Active, NG, & Reserves) has their own separate set of \"MPA\", \"MPA Non Pay\", & \"OMA\" inflation factors and Civilian (GS, WG, WL, WS, & SES) positions are only inflated by two inflation factors, \"CivPay\" or \"OMA\".  The \"MPA\" inflation factor is applied to all MPA Appropriation (APPN) cost elements except Permanent Change of Station (PCS) related cost elements.  In this case, the \"MPA Non Pay\" inflation factor is applied to a PCS cost element.  When AMCOS LITE displays APPN = \"OMA\" or \"Other\", the \"OMA\" inflation factor is applied to any cost element with either APPN.";
            //style.Font.IsBold = false;
            //style.Font.Color = Color.Black;
            //style.ForegroundColor = Color.White;
            //style.Font.Underline = FontUnderlineType.None;
            //style.Borders[BorderType.TopBorder].LineStyle = CellBorderType.None;
            //style.Borders[BorderType.BottomBorder].LineStyle = CellBorderType.None;
            //style.Borders[BorderType.LeftBorder].LineStyle = CellBorderType.None;
            //style.Borders[BorderType.RightBorder].LineStyle = CellBorderType.None;
            //ws.Cells[0, 0].SetStyle(style);
            //ws.Cells.InsertRow(0);
            //ws.Cells.InsertRow(0);

            //ws.Cells[0, 0].Value = "Inflation Factors";
            //style.Font.IsBold = true;
            //style.Font.Size = 14;
            //ws.Cells[0, 0].SetStyle(style);

            ////Report Properties on top
            //string sql = "SELECT distinct webuser.PMCategory.CategoryName AS [Sub-Project Name], webuser.PMReport.PayPlan FROM webuser.PMReport INNER JOIN webuser.PMCategory ON webuser.PMReport.CategoryID = webuser.PMCategory.CategoryID AND webuser.PMReport.ProjectID = webuser.PMCategory.ProjectID AND webuser.PMReport.UserID = webuser.PMCategory.UserID WHERE (webuser.PMReport.UserID = @uid) AND (webuser.PMReport.ProjectID = @pid)";
            //DataTable dtSubProj = DataAccessUtil.GetDatatableByStaticSql(sql, { "@uid", "@pid"}, { oUser.UserID, ProjectID});

            //int nRows = 7;
            //if (dtSubProj.Rows.Count > 6)
            //    nRows = dtSubProj.Rows.Count + 1;


            //for (int i = 0; i <= nRows; i++)
            //{
            //    ws.Cells.InsertRow(0);
            //}

            //ws.Cells.ImportDataTable(dtSubProj, true, 0, 3, false);

            //ws.Cells[0, 0].Value = "Project Creator";
            //ws.Cells[1, 0].Value = "Create Date";
            //ws.Cells[2, 0].Value = "Last Update";
            //ws.Cells[3, 0].Value = "Project Name";
            //ws.Cells[4, 0].Value = "Description";
            //ws.Cells[5, 0].Value = "Start Year";
            //ws.Cells[6, 0].Value = "Project Duration";
            //dtD = DataAccessUtil.GetDatatableByStaticSql("SELECT isnull(ProjectCreator,UserID), convert(varchar,CreateDate), convert(varchar,LastUpdate), ProjectName, Description, YearStart, YearDuration FROM webuser.PMProject WHERE ProjectID = @pid", { "@pid"}, { ProjectID});
            //for (int i = 0; i <= 6; i++)
            //{
            //    ws.Cells[i, 1].Value = dtD.Rows(0)(i);
            //}
            //style.Font.Size = 10;
            //style.Font.Color = Color.White;
            //style.ForegroundColor = Color.Navy;
            //style.Borders[BorderType.TopBorder].LineStyle = CellBorderType.Thin;
            //style.Borders[BorderType.BottomBorder].LineStyle = CellBorderType.Thin;
            //style.Borders[BorderType.LeftBorder].LineStyle = CellBorderType.Thin;
            //style.Borders[BorderType.RightBorder].LineStyle = CellBorderType.Thin;
            //ws.Cells.CreateRange(0, 0, 7, 1).ApplyStyle(style, styleFlag);
            //ws.Cells.CreateRange(0, 3, 1, 2).ApplyStyle(style, styleFlag);

            //style.Font.IsBold = false;
            //style.Font.Color = Color.Black;
            //style.ForegroundColor = Color.White;
            //ws.Cells.CreateRange(0, 1, 7, 1).ApplyStyle(style, styleFlag);
            //ws.Cells.CreateRange(1, 3, dtSubProj.Rows.Count, 2).ApplyStyle(style, styleFlag);


            //ws.Cells.InsertRow(0);
            //ws.Cells.InsertRow(0);
            //style.Font.Color = Color.Black;
            //style.ForegroundColor = Color.White;
            //style.Font.IsBold = true;
            //style.Font.Size = 14;
            //style.Borders[BorderType.TopBorder].LineStyle = Aspose.Cells.CellBorderType.None;
            //style.Borders[BorderType.BottomBorder].LineStyle = Aspose.Cells.CellBorderType.None;
            //style.Borders[BorderType.LeftBorder].LineStyle = Aspose.Cells.CellBorderType.None;
            //style.Borders[BorderType.RightBorder].LineStyle = Aspose.Cells.CellBorderType.None;
            //ws.Cells[0, 0].Value = "Report Properties";
            //ws.Cells[0, 0].SetStyle(style);

            //AddClassification(ws);
            //ws.AutoFitColumns();
            //wb.Save(Response, "AMCOS_ReportData.xlsx", Aspose.Cells.ContentDisposition.Attachment, new Aspose.Cells.OoxmlSaveOptions(Aspose.Cells.SaveFormat.Xlsx));
            //Response.End();

        }
        public void DeleteProject(int projectId)
        {
            string sqlStatement = "web.DeleteProject";
            using (NpgsqlConnection connection = new NpgsqlConnection(AppConfiguration.GetConnectionString()))
            {
                connection.Open();
                using (NpgsqlCommand command = new NpgsqlCommand(sqlStatement, connection))
                {
                    command.Parameters.AddWithValue("@ProjectId", projectId);
                    command.CommandType = CommandType.StoredProcedure;
                    command.ExecuteNonQuery();
                }
            }
        }
        public DiscountFactor GetDiscountFactors(int amcosVersionId)
        {
            DiscountFactor returnValue = new DiscountFactor
            {
                DiscountFactorYear3 = SingleValue.Get("ALL", "projectReport_DiscountFactor_Year3", amcosVersionId),
                DiscountFactorYear5 = SingleValue.Get("ALL", "projectReport_DiscountFactor_Year5", amcosVersionId),
                DiscountFactorYear7 = SingleValue.Get("ALL", "projectReport_DiscountFactor_Year7", amcosVersionId),
                DiscountFactorYear10 = SingleValue.Get("ALL", "projectReport_DiscountFactor_Year10", amcosVersionId),
                DiscountFactorYear20 = SingleValue.Get("ALL", "projectReport_DiscountFactor_Year20", amcosVersionId),
                DiscountFactorYear30 = SingleValue.Get("ALL", "projectReport_DiscountFactor_Year30", amcosVersionId)
            };
            return returnValue;
        }
        public List<PMProject> GetAllProjectsForUserId(string userId)
        {
            using (var context = new ApplicationDbContext())
            {
                return context.PMProject.AsNoTracking()
                    .Where(c => c.UserId == userId)
                    .OrderByDescending(c => c.LastUpdate)
                    .ToList();
            }
        }
        private string LocationDisplay(string payPlan, string locationName)
        {
            _ = payPlan ?? throw new ArgumentNullException(nameof(payPlan));
            _ = locationName ?? throw new ArgumentNullException(nameof(locationName));

            string[] payPlansThatDoNotRequireLocation = { "NE", "NO", "NWO", "RE", "RO", "RWO" };
            if (Array.Exists(payPlansThatDoNotRequireLocation, element => element == payPlan))
            {
                return "N/A";
            }
            else
            {
                if (locationName == "")
                {
                    return "All";
                }
                else
                {
                    return locationName;
                }
            }
        }
        //public bool PMCategorySkillExists(string payPlan)
        //{
        //    int count = 0;
        //    string[] gfebsPayPlans = {"DB","DE","DJ","DK","GP","NH","NJ","NK" };
        //    if (gfebsPayPlans.Contains(payPlan)) {
        //        count = CType(DataAccessUtility.GetScalarByDynamicSql("select count(*) from webuser.PMCategorySkill where 1=1",
        //                                                            { True, True, True, True, True, True},
        //                                                            { "UserID", "ProjectID", "CategoryID", "PayPlan", "CategorySubgroupCode", "GradeLevel"},
        //                                                            { currentUser.UserId, ProjectID, CategoryID, selectedPayPlan.Value, selectedCategorySubgroupCode.Value, selectedGradeLevel.Value}), Integer)
        //    } else {
        //        count = CType(DataAccessUtility.GetScalarByDynamicSql("select count(*) from webuser.PMCategorySkill where 1=1",
        //                                                            { True, True, True, True, True, True, selectedLocationId.Value <> "", True},
        //                                                            { "UserID", "ProjectID", "CategoryID", "PayPlan", "CategoryGroupCode", "CategorySubGroupCode", "LocalityId", "GradeLevel"},
        //                                                            { currentUser.UserId, ProjectID, CategoryID, selectedPayPlan.Value, selectedCategoryGroupCode.Value, selectedCategorySubgroupCode.Value, selectedLocationId.Value, selectedGradeLevel.Value}), Integer)
        //    }

        //    if (count > 0) {
        //        lblInsertMsg.Text = "Can't insert because this project already has a Skill record with the same key field values as selected"
        //        Exit Sub
        //    }
        //}                
        public void UpdateCategoryName(int projectId, string categoryNameNew, string categoryNameOld)
        {
            using (var context = new ApplicationDbContext())
            {
                var pmCategory = context.PMCategory
                    .Where(c => c.ProjectId == projectId)
                    .Where(c => c.CategoryName == categoryNameOld)
                    .First();
                pmCategory.CategoryName = categoryNameNew;
                context.SaveChanges();
            }
        }
        public DataTable UpdateLocationDisplay(DataTable dataTable)
        {
            _ = dataTable ?? throw new ArgumentNullException(nameof(dataTable));

            foreach (DataRow dr in dataTable.Rows)
            {
                dr["Location"] = LocationDisplay(dr["PayPlan"].ToString(), dr["Location"].ToString());
            }
            return dataTable;
        }
    }
}