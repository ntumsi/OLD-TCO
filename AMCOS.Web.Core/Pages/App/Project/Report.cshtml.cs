using System.Data;
using System.Drawing;
using System.Globalization;
using System.Security.Claims;
using Aspose.Cells;
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
    private readonly IWebHostEnvironment _environment;

    public ReportModel(IConfiguration configuration, IWebHostEnvironment environment)
    {
        _configuration = configuration;
        _environment = environment;
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

        ApplyAsposeLicense(_environment);

        var workbook = new Workbook();
        workbook.Worksheets.Clear();
        var sheet = workbook.Worksheets[workbook.Worksheets.Add()];
        sheet.Name = "AMCOS Report";

        BuildExportSheet(sheet);

        sheet.AutoFitColumns();

        using var stream = new MemoryStream();
        workbook.Save(stream, SaveFormat.Xlsx);
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

    // Applies the Aspose.Cells license if present and valid. An expired/mismatched license
    // (e.g. the bundled .lic predates the Aspose DLL build) must NOT abort the export — Aspose
    // simply runs in evaluation mode, which still produces a usable workbook.
    internal static void ApplyAsposeLicense(IWebHostEnvironment environment)
    {
        try
        {
            var licensePath = Path.Combine(environment.ContentRootPath, "Licenses", "Aspose.Cells.lic");
            if (System.IO.File.Exists(licensePath))
            {
                new License().SetLicense(licensePath);
            }
        }
        catch
        {
            // Fall back to Aspose evaluation mode rather than failing the export.
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

    private void BuildExportSheet(Worksheet ws)
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

    private static void WriteBanner(Worksheet ws, int row, string text)
    {
        var cell = ws.Cells[row, 0];
        cell.PutValue(text);
        var style = cell.GetStyle();
        style.Font.IsBold = true;
        style.HorizontalAlignment = TextAlignmentType.Center;
        cell.SetStyle(style);
        ws.Cells.Merge(row, 0, 1, 10);
    }

    private static int WriteSectionTitle(Worksheet ws, int row, string title)
    {
        var cell = ws.Cells[row, 0];
        cell.PutValue(title);
        var style = cell.GetStyle();
        style.Font.IsBold = true;
        style.Font.Size = 14;
        cell.SetStyle(style);
        return row + 1;
    }

    private static int WriteKeyValue(Worksheet ws, int row, string key, string? value)
    {
        var keyCell = ws.Cells[row, 0];
        keyCell.PutValue(key);
        var keyStyle = keyCell.GetStyle();
        keyStyle.Font.IsBold = true;
        keyStyle.Font.Color = Color.White;
        keyStyle.ForegroundColor = Color.Navy;
        keyStyle.Pattern = BackgroundType.Solid;
        keyCell.SetStyle(keyStyle);
        ws.Cells[row, 1].PutValue(value ?? "");
        return row + 1;
    }

    private static int WriteNote(Worksheet ws, int row, string text)
    {
        var cell = ws.Cells[row, 0];
        cell.PutValue(text);
        var style = cell.GetStyle();
        style.IsTextWrapped = true;
        cell.SetStyle(style);
        ws.Cells.Merge(row, 0, 1, 10);
        return row + 1;
    }

    private static int WriteTableBlock(Worksheet ws, int row, string title, DataTable? table)
    {
        row = WriteSectionTitle(ws, row, title);
        if (table is null || table.Columns.Count == 0)
        {
            ws.Cells[row, 0].PutValue("No data available.");
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
                var cell = ws.Cells[row, c];
                cell.PutValue(value == DBNull.Value ? "" : value.ToString());
                var style = cell.GetStyle();
                ApplyThinBorders(style);
                cell.SetStyle(style);
            }
            row++;
        }
        return row + 1;
    }

    private int WriteCostBlock(Worksheet ws, int row, string title, DataTable table, List<string> yearColumns)
    {
        row = WriteSectionTitle(ws, row, title);
        if (table.Columns.Count == 0)
        {
            ws.Cells[row, 0].PutValue("No data available.");
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
                var bcell = ws.Cells[row, 0];
                bcell.PutValue(label);
                var bstyle = bcell.GetStyle();
                bstyle.Font.IsBold = true;
                bstyle.Font.Color = Color.White;
                bstyle.ForegroundColor = Color.Black;
                bstyle.Pattern = BackgroundType.Solid;
                bcell.SetStyle(bstyle);
                ws.Cells.Merge(row, 0, 1, visible.Count);
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
                var cell = ws.Cells[row, c];
                var isYear = yearSet.Contains(col.ColumnName);

                if (isYear && decimal.TryParse(value?.ToString(), NumberStyles.Any, CultureInfo.InvariantCulture, out var num))
                {
                    cell.PutValue((double)num);
                }
                else
                {
                    cell.PutValue(value == DBNull.Value ? "" : value?.ToString());
                }

                var style = cell.GetStyle();
                if (isYear) style.Number = 7; // $#,##0.00;($#,##0.00)
                ApplyThinBorders(style);

                // Total/subtotal rows: color only the Cost Element column and those to its right;
                // the columns to the left are left unfilled (legacy report.aspx.vb).
                if (kindColor is { } kc && c >= costElementIndex)
                {
                    style.ForegroundColor = ColorTranslator.FromHtml(kc.Bg);
                    style.Pattern = BackgroundType.Solid;
                    style.Font.IsBold = true;
                    if (kc.White) style.Font.Color = Color.White;
                }
                else if (kindColor is null && col.ColumnName == "APPN" && value != DBNull.Value)
                {
                    var apColor = appropriation.GetAppropriationColor(value?.ToString() ?? "");
                    if (apColor != Color.White)
                    {
                        style.ForegroundColor = apColor;
                        style.Pattern = BackgroundType.Solid;
                        style.Font.Color = Color.White;
                    }
                }
                else if (isYear && overLimit)
                {
                    style.ForegroundColor = Color.Yellow;
                    style.Pattern = BackgroundType.Solid;
                }

                cell.SetStyle(style);
            }
            row++;
        }
        return row + 1;
    }

    private static void WriteHeaderCell(Worksheet ws, int row, int col, string text, bool black = false)
    {
        var cell = ws.Cells[row, col];
        cell.PutValue(text);
        var style = cell.GetStyle();
        style.Font.IsBold = true;
        style.Font.Color = Color.White;
        style.ForegroundColor = black ? Color.Black : Color.Navy; // legacy cost header is black
        style.Pattern = BackgroundType.Solid;
        ApplyThinBorders(style);
        cell.SetStyle(style);
    }

    // Thin box border on all four sides (legacy report.aspx.vb export cell styling).
    private static void ApplyThinBorders(Style style)
    {
        style.Borders[BorderType.TopBorder].LineStyle = CellBorderType.Thin;
        style.Borders[BorderType.BottomBorder].LineStyle = CellBorderType.Thin;
        style.Borders[BorderType.LeftBorder].LineStyle = CellBorderType.Thin;
        style.Borders[BorderType.RightBorder].LineStyle = CellBorderType.Thin;
        style.Borders[BorderType.TopBorder].Color = Color.Black;
        style.Borders[BorderType.BottomBorder].Color = Color.Black;
        style.Borders[BorderType.LeftBorder].Color = Color.Black;
        style.Borders[BorderType.RightBorder].Color = Color.Black;
    }
}