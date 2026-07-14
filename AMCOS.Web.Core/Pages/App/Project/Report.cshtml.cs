using System.Data;
using System.Drawing;
using System.Globalization;
using System.Security.Claims;
using ClosedXML.Excel;
using AMCOS.Data.Entities;
using AMCOS.Logic;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;
using NpgsqlTypes;

namespace AMCOS.Web.Core.Pages.App.Project;

[Authorize]
public class ReportModel : PageModel
{
    private readonly IConfiguration _configuration;

    public ReportModel(IConfiguration configuration)
    {
        _configuration = configuration;
    }

    [BindProperty(SupportsGet = true)]
    public int? ProjectId { get; set; }

    public string? LoadError { get; private set; }
    public PMProject? ProjectDetails { get; private set; }
    public DataTable? ReportSelections { get; private set; }
    public DataTable? InflationFactors { get; private set; }
    public DataTable? DiscountTable { get; private set; }
    public DataTable? InventoryTable { get; private set; }

    /// <summary>Selected OMB discount-rate heading (legacy showed the rate as a label, not a grid row).</summary>
    public string? DiscountRateHeading { get; private set; }

    /// <summary>Shaped cost report (undiscounted + discounted summaries, sub-totals, labels).</summary>
    public CostReportBuilder.Result? Cost { get; private set; }

    /// <summary>CCE per-grade salary threshold; cost cells above it are highlighted (legacy yellow).</summary>
    public decimal CceSalaryLimit { get; private set; }

    public void OnGet(int? projectId)
    {
        ProjectId = projectId ?? ProjectId;
        LoadReport();
    }

    public IActionResult OnPostExport(int projectId)
    {
        ProjectId = projectId;
        LoadReport();
        if (!string.IsNullOrWhiteSpace(LoadError) || ProjectDetails is null)
        {
            return RedirectToPage(new { projectId });
        }

        using var workbook = new XLWorkbook();
        var sheet = workbook.Worksheets.Add("AMCOS Report");

        BuildExportSheet(sheet);

        sheet.Columns().AdjustToContents();

        using var stream = new MemoryStream();
        workbook.SaveAs(stream);
        stream.Position = 0;
        return File(stream.ToArray(), "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet", $"AMCOSReportData_{DateTime.UtcNow:yyyyMMdd-HHmmss}.xlsx");
    }

    private void LoadReport()
    {
        if (!ProjectId.HasValue)
        {
            return;
        }

        try
        {
            var amcosVersionId = GetIntSetting("AmcosVersionId", 202501);
            var projectLogic = new AMCOS.Logic.Project();
            ProjectDetails = projectLogic.GetProject(ProjectId.Value);

            // Owner check (parity with the legacy report query's `WHERE PMProject.UserID = @uid`):
            // only the project's owner (or an admin) may view its report — prevents reading another
            // user's report by guessing the projectId.
            var currentUser = (User.Identity as ClaimsIdentity) is { IsAuthenticated: true } id
                ? UserAdministration.GetCurrentUser(id) : null;
            if (ProjectDetails == null ||
                (!User.IsInRole("Admin") &&
                 !string.Equals(ProjectDetails.UserId, currentUser?.UserId, StringComparison.OrdinalIgnoreCase)))
            {
                ProjectDetails = null;
                LoadError = "This report is not available.";
                return;
            }

            CceSalaryLimit = SingleValue.Get("CCE", "MaxPayFootnote", amcosVersionId);
            ReportSelections = DataAccessUtility.GetDataTableByStaticSql(
                // PostgreSQL folds unquoted identifiers to lowercase; the migrated tables are
                // all lowercase, so do NOT quote them (quoting would make them case-sensitive
                // and fail to resolve webuser.pmreport / pmcategory).
                """
                SELECT DISTINCT pmcategory.categoryname AS category, pmreport.payplan
                FROM webuser.pmreport pmreport
                INNER JOIN webuser.pmcategory pmcategory ON pmreport.categoryid = pmcategory.categoryid
                WHERE pmcategory.projectid = @ProjectId;
                """,
                new[] { "@ProjectId" },
                new object[] { ProjectId.Value });
            InflationFactors = DataAccessUtility.GetDataTableByStaticSql(
                "SELECT * FROM web.GetPMReportInflationRateHeader(@ProjectId, @AmcosVersionId);",
                new[] { "@ProjectId", "@AmcosVersionId" },
                new object[] { ProjectId.Value, amcosVersionId });
            InventoryTable = DataAccessUtility.ExecuteStoredProcDataSet(
                "web.PMProjectInventory",
                new[] { "@ProjectId" },
                new[] { NpgsqlDbType.Integer },
                new object[] { ProjectId.Value }).Tables[0];
            RelabelInventoryYears(InventoryTable, ProjectDetails?.YearStart ?? 0);

            var rawCost = DataAccessUtility.ExecuteStoredProcDataSet(
                "web.PMReport",
                new[] { "@ProjectId", "@AmcosVersionId" },
                new[] { NpgsqlDbType.Integer, NpgsqlDbType.Integer },
                new object[] { ProjectId.Value, amcosVersionId }).Tables[0];
            rawCost = projectLogic.UpdateLocationDisplay(rawCost.Copy());

            DiscountTable = BuildDiscountTable(ProjectDetails!, projectLogic.GetDiscountFactors(amcosVersionId));

            // Legacy showed the OMB discount rate as a heading ("Discount Rates Based on N Years
            // Securities"), not as a grid row. Lift the rate row out into the heading and drop it
            // from the grid so only the Present Value Factor row remains (matches legacy).
            var rateRow = DiscountTable.Rows.Cast<DataRow>()
                .FirstOrDefault(r => (r[0]?.ToString() ?? "").StartsWith("OMB Discount Rate", StringComparison.OrdinalIgnoreCase));
            if (rateRow != null)
            {
                var rateText = DiscountTable.Columns.Count > 1 ? rateRow[1]?.ToString() : null;
                DiscountRateHeading = decimal.TryParse(rateText, NumberStyles.Any, CultureInfo.InvariantCulture, out var rv)
                    ? $"{rateRow[0]}: {rv:0.##}%"
                    : rateRow[0]?.ToString();
                DiscountTable.Rows.Remove(rateRow);
            }
            Cost = CostReportBuilder.Build(rawCost, BuildPvfByYear(DiscountTable));
        }
        catch (Exception ex)
        {
            LoadError = ex.Message;
        }
    }

    private int GetIntSetting(string key, int defaultValue)
    {
        var value = _configuration[key] ?? _configuration[$"AppSettings:{key}"];
        return int.TryParse(value, out var parsedValue) ? parsedValue : defaultValue;
    }

    /// <summary>Inventory year columns are 0-based project-year indexes; show calendar years.</summary>
    private static void RelabelInventoryYears(DataTable? table, int yearStart)
    {
        if (table is null || yearStart <= 0) return;
        foreach (DataColumn column in table.Columns)
        {
            if (int.TryParse(column.ColumnName, NumberStyles.Integer, CultureInfo.InvariantCulture, out var index))
            {
                var calendar = (yearStart + index).ToString(CultureInfo.InvariantCulture);
                if (!table.Columns.Contains(calendar)) column.ColumnName = calendar;
            }
        }
    }

    /// <summary>Extracts the present-value factor per calendar-year column from the discount table.</summary>
    private static Dictionary<string, decimal> BuildPvfByYear(DataTable discountTable)
    {
        var map = new Dictionary<string, decimal>();
        var pvfRow = discountTable.Rows.Cast<DataRow>()
            .FirstOrDefault(r => (r[0]?.ToString() ?? "").StartsWith("Present Value", StringComparison.OrdinalIgnoreCase));
        if (pvfRow is null) return map;

        foreach (DataColumn column in discountTable.Columns)
        {
            if (int.TryParse(column.ColumnName, NumberStyles.Integer, CultureInfo.InvariantCulture, out _)
                && decimal.TryParse(pvfRow[column]?.ToString(), NumberStyles.Any, CultureInfo.InvariantCulture, out var pvf))
            {
                map[column.ColumnName] = pvf;
            }
        }
        return map;
    }

    private static DataTable BuildDiscountTable(PMProject project, DiscountFactor factor)
    {
        var discountTable = new DataTable("Discount");
        discountTable.Columns.Add("Metric");
        for (var i = 0; i < project.YearDuration; i++)
        {
            discountTable.Columns.Add((project.YearStart + i).ToString());
        }

        var rate = factor.DiscountFactorYear30;
        var selectedDuration = 30;
        foreach (var pair in new[]
        {
            (Years: 3, Value: factor.DiscountFactorYear3),
            (Years: 5, Value: factor.DiscountFactorYear5),
            (Years: 7, Value: factor.DiscountFactorYear7),
            (Years: 10, Value: factor.DiscountFactorYear10),
            (Years: 20, Value: factor.DiscountFactorYear20),
            (Years: 30, Value: factor.DiscountFactorYear30)
        })
        {
            if (project.YearDuration <= pair.Years)
            {
                rate = pair.Value;
                selectedDuration = pair.Years;
                break;
            }
        }

        var rateRow = discountTable.NewRow();
        rateRow[0] = $"OMB Discount Rate ({selectedDuration} Year)";
        for (var i = 1; i < discountTable.Columns.Count; i++)
        {
            rateRow[i] = rate;
        }
        discountTable.Rows.Add(rateRow);

        var pvfRow = discountTable.NewRow();
        pvfRow[0] = "Present Value Factor";
        for (var year = 1; year < discountTable.Columns.Count; year++)
        {
            var value = 1.0 / Math.Pow(1 + (double)rate / 100, year - 0.5);
            pvfRow[year] = value.ToString("0.#####");
        }
        discountTable.Rows.Add(pvfRow);

        return discountTable;
    }

    // ── Excel export ────────────────────────────────────────────────────────────

    // Aspose built-in Number = 7 (currency) → ClosedXML format string.
    private const string CurrencyFormat = "$#,##0.00;($#,##0.00)";

    private void BuildExportSheet(IXLWorksheet ws)
    {
        var row = 0;

        // Report properties
        row = WriteSectionTitle(ws, row, "Report Properties");
        row = WriteKeyValue(ws, row, "Project Creator", ProjectDetails!.ProjectCreator);
        row = WriteKeyValue(ws, row, "Create Date", ProjectDetails.CreateDate.ToString(CultureInfo.InvariantCulture));
        row = WriteKeyValue(ws, row, "Last Update", ProjectDetails.LastUpdate.ToString(CultureInfo.InvariantCulture));
        row = WriteKeyValue(ws, row, "Project Name", ProjectDetails.ProjectName);
        row = WriteKeyValue(ws, row, "Description", ProjectDetails.Description);
        row = WriteKeyValue(ws, row, "Start Year", ProjectDetails.YearStart.ToString());
        row = WriteKeyValue(ws, row, "Project Duration", ProjectDetails.YearDuration.ToString());
        row += 1;
        row = WriteTableBlock(ws, row, "Report Selection", ReportSelections);

        // Inflation factors
        row = WriteTableBlock(ws, row, "Inflation Factors", InflationFactors);

        // Discount / PVF
        row = WriteTableBlock(ws, row, "Discounting and Present Value Factor (PVF)", DiscountTable);

        // Inventory
        row = WriteTableBlock(ws, row, "Inventory", InventoryTable);

        // Cost summaries (undiscounted + discounted), with appropriation colouring.
        if (Cost is not null)
        {
            row = WriteCostBlock(ws, row, "Default Summary", Cost.Undiscounted, Cost.YearColumns);
            row = WriteCostBlock(ws, row, "Discounted Default Summary", Cost.Discounted, Cost.YearColumns);

            row += 1;
            if (Cost.HasSpecialPay)
                row = WriteNote(ws, row, "**NOTE - Cost values are not inflated for the \"Average Cost of Special Pays\".");
            if (Cost.CceOverSalaryLimit)
                row = WriteNote(ws, row, $"NOTE: The highlighted field(s) indicate a value based on CCE salary greater than {CceSalaryLimit:C0} per year.  The Contractor APPN Total sums the displayed CCE values but may be greater if your report includes highlighted cells.");
            row = WriteNote(ws, row, "The costing reports are produced both with and without the discount rate the analyst inputs to the cost estimate.");

            // Regulatory explanatory notes (legacy report.aspx.vb export).
            row = WriteNote(ws, row, "NOTE: The current Joint Inflation Calculator (JIC) found on the OASA (FM&C) website is the source for the fourteen (14) inflation factors built into Project Manager (PM).");
            row = WriteNote(ws, row, "Discount rates are prepared annually by the Office of Management and Budget (OMB). OMB Circular A-94 and Department of Defense Instruction (DoDI) 7041.3 require the use of a discount rate based on the Treasury Department cost of borrowing funds, and reflect the expected cost of borrowing for 3, 5, 7, 10, 20, and 30 years securities.");
            row = WriteNote(ws, row, "NOTE: For analysts costing overseas positions, consider adding Civilian \"Discount Groceries (OCONUS Only)\" costs, if required: for the AMCOS base year, add Discount Groceries (OCONUS Only) costs found on the Full Cost of Manpower (FCoM) web site http://fcom.cape.osd.mil/. For future year \"Default Summary\" cost element projections, multiply the Discount Groceries Factor by the \"Civilian DoD OMA\" inflation factor for the desired year; for future year \"Discounted Default Summary\" projections, additionally apply the Present Value Factor (PVF).");
        }

        // Classification banner at the bottom, plain/unfilled (legacy CommonModule.AddClassification).
        WriteBanner(ws, row + 3, "UNCLASSIFIED//FOR OFFICIAL USE ONLY");
    }

    private static void WriteBanner(IXLWorksheet ws, int row, string text)
    {
        var cell = Cell0(ws, row, 0);
        cell.Value = text;
        cell.Style.Font.Bold = true;
        cell.Style.Alignment.Horizontal = XLAlignmentHorizontalValues.Center;
        Range0(ws, row, 0, 1, 10).Merge();
    }

    private static int WriteSectionTitle(IXLWorksheet ws, int row, string title)
    {
        var cell = Cell0(ws, row, 0);
        cell.Value = title;
        cell.Style.Font.Bold = true;
        cell.Style.Font.FontSize = 14;
        return row + 1;
    }

    private static int WriteKeyValue(IXLWorksheet ws, int row, string key, string? value)
    {
        var keyCell = Cell0(ws, row, 0);
        keyCell.Value = key;
        keyCell.Style.Font.Bold = true;
        keyCell.Style.Font.FontColor = XLColor.White;
        keyCell.Style.Fill.BackgroundColor = XLColor.Navy;
        Cell0(ws, row, 1).Value = value ?? "";
        return row + 1;
    }

    private static int WriteNote(IXLWorksheet ws, int row, string text)
    {
        var cell = Cell0(ws, row, 0);
        cell.Value = text;
        cell.Style.Alignment.WrapText = true;
        Range0(ws, row, 0, 1, 10).Merge();
        return row + 1;
    }

    private static int WriteTableBlock(IXLWorksheet ws, int row, string title, DataTable? table)
    {
        row = WriteSectionTitle(ws, row, title);
        if (table is null || table.Columns.Count == 0)
        {
            Cell0(ws, row, 0).Value = "No data available.";
            return row + 2;
        }

        var visible = table.Columns.Cast<DataColumn>()
            .Where(c => !CostReportBuilder.HiddenColumns.Contains(c.ColumnName))
            .ToList();

        for (var c = 0; c < visible.Count; c++)
        {
            WriteHeaderCell(ws, row, c, visible[c].ColumnName);
        }
        row++;

        foreach (DataRow dataRow in table.Rows)
        {
            for (var c = 0; c < visible.Count; c++)
            {
                var value = dataRow[visible[c]];
                var cell = Cell0(ws, row, c);
                cell.Value = value == DBNull.Value ? "" : value.ToString() ?? "";
                ApplyThinBorders(cell);
            }
            row++;
        }
        return row + 1;
    }

    private int WriteCostBlock(IXLWorksheet ws, int row, string title, DataTable table, List<string> yearColumns)
    {
        row = WriteSectionTitle(ws, row, title);
        if (table.Columns.Count == 0)
        {
            Cell0(ws, row, 0).Value = "No data available.";
            return row + 2;
        }

        var appropriation = new Appropriation();
        var yearSet = new HashSet<string>(yearColumns);
        var visible = table.Columns.Cast<DataColumn>()
            .Where(c => !CostReportBuilder.HiddenColumns.Contains(c.ColumnName))
            .ToList();
        var costElementIndex = Math.Max(0, visible.FindIndex(c => c.ColumnName == "Cost Element"));

        for (var c = 0; c < visible.Count; c++)
        {
            WriteHeaderCell(ws, row, c, visible[c].ColumnName, black: true);
        }
        row++;

        foreach (DataRow dataRow in table.Rows)
        {
            var kind = dataRow.Table.Columns.Contains("RowKind") ? dataRow["RowKind"]?.ToString() : null;

            // Full-width black "BEGINNING OF SUB-PROJECT:" divider banner (legacy report.aspx.vb).
            if (kind == CostReportBuilder.KindBanner)
            {
                var label = table.Columns.Contains("Cost Element") ? dataRow["Cost Element"]?.ToString() : "";
                var bcell = Cell0(ws, row, 0);
                bcell.Value = label ?? "";
                bcell.Style.Font.Bold = true;
                bcell.Style.Font.FontColor = XLColor.White;
                bcell.Style.Fill.BackgroundColor = XLColor.Black;
                Range0(ws, row, 0, 1, visible.Count).Merge();
                row++;
                continue;
            }

            var kindColor = CostReportBuilder.RowKindColor(kind);
            var overLimit = dataRow.Table.Columns.Contains("ExceedsSalaryLimit")
                && (dataRow["ExceedsSalaryLimit"]?.ToString() == "1"
                    || string.Equals(dataRow["ExceedsSalaryLimit"]?.ToString(), "true", StringComparison.OrdinalIgnoreCase));

            for (var c = 0; c < visible.Count; c++)
            {
                var col = visible[c];
                var value = dataRow[col];
                var cell = Cell0(ws, row, c);
                var isYear = yearSet.Contains(col.ColumnName);

                if (isYear && decimal.TryParse(value?.ToString(), NumberStyles.Any, CultureInfo.InvariantCulture, out var num))
                {
                    cell.Value = (double)num;
                }
                else
                {
                    cell.Value = value == DBNull.Value ? "" : value?.ToString() ?? "";
                }

                if (isYear) cell.Style.NumberFormat.Format = CurrencyFormat; // $#,##0.00;($#,##0.00)
                ApplyThinBorders(cell);

                // Total/subtotal rows: color only the Cost Element column and those to its right;
                // the columns to the left are left unfilled (legacy report.aspx.vb).
                if (kindColor is { } kc && c >= costElementIndex)
                {
                    cell.Style.Fill.BackgroundColor = XLColor.FromHtml(kc.Bg);
                    cell.Style.Font.Bold = true;
                    if (kc.White) cell.Style.Font.FontColor = XLColor.White;
                }
                else if (kindColor is null && col.ColumnName == "APPN" && value != DBNull.Value)
                {
                    var apColor = appropriation.GetAppropriationColor(value?.ToString() ?? "");
                    if (apColor != Color.White)
                    {
                        cell.Style.Fill.BackgroundColor = XLColor.FromColor(apColor);
                        cell.Style.Font.FontColor = XLColor.White;
                    }
                }
                else if (isYear && overLimit)
                {
                    cell.Style.Fill.BackgroundColor = XLColor.Yellow;
                }
            }
            row++;
        }
        return row + 1;
    }

    private static void WriteHeaderCell(IXLWorksheet ws, int row, int col, string text, bool black = false)
    {
        var cell = Cell0(ws, row, col);
        cell.Value = text;
        cell.Style.Font.Bold = true;
        cell.Style.Font.FontColor = XLColor.White;
        cell.Style.Fill.BackgroundColor = black ? XLColor.Black : XLColor.Navy; // legacy cost header is black
        ApplyThinBorders(cell);
    }

    // Thin box border on all four sides (legacy report.aspx.vb export cell styling).
    private static void ApplyThinBorders(IXLCell cell)
    {
        cell.Style.Border.TopBorder = XLBorderStyleValues.Thin;
        cell.Style.Border.BottomBorder = XLBorderStyleValues.Thin;
        cell.Style.Border.LeftBorder = XLBorderStyleValues.Thin;
        cell.Style.Border.RightBorder = XLBorderStyleValues.Thin;
        cell.Style.Border.TopBorderColor = XLColor.Black;
        cell.Style.Border.BottomBorderColor = XLColor.Black;
        cell.Style.Border.LeftBorderColor = XLColor.Black;
        cell.Style.Border.RightBorderColor = XLColor.Black;
    }

    // ---- ClosedXML addressing helpers (0-based in, 1-based ClosedXML out) -------

    private static IXLCell Cell0(IXLWorksheet ws, int row, int col) => ws.Cell(row + 1, col + 1);

    private static IXLRange Range0(IXLWorksheet ws, int firstRow, int firstCol, int totalRows, int totalCols)
        => ws.Range(firstRow + 1, firstCol + 1, firstRow + totalRows, firstCol + totalCols);
}