using System.Data;
using Aspose.Cells;
using AMCOS.Data.Entities;
using AMCOS.Logic;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;
using NpgsqlTypes;

namespace AMCOS.Web.Core.Pages.App.Project;

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
    public DataTable? CostReport { get; private set; }

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

        var licensePath = Path.Combine(_environment.ContentRootPath, "Licenses", "Aspose.Cells.lic");
        if (System.IO.File.Exists(licensePath))
        {
            var license = new License();
            license.SetLicense(licensePath);
        }

        var workbook = new Workbook();
        workbook.Worksheets.Clear();

        AddWorksheet(workbook, "Project", ToProjectTable(ProjectDetails));
        AddWorksheet(workbook, "Selection", ReportSelections);
        AddWorksheet(workbook, "Inflation", InflationFactors);
        AddWorksheet(workbook, "Discount", DiscountTable);
        AddWorksheet(workbook, "Inventory", InventoryTable);
        AddWorksheet(workbook, "Cost Report", CostReport);

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
            ReportSelections = DataAccessUtility.GetDataTableByStaticSql(
                """
                SELECT DISTINCT PMCategory.CategoryName AS Category, PMReport.PayPlan
                FROM webuser."PMReport" PMReport
                INNER JOIN webuser."PMCategory" PMCategory ON PMReport."CategoryId" = PMCategory."CategoryId"
                WHERE PMCategory."ProjectId" = @ProjectId;
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
            CostReport = DataAccessUtility.ExecuteStoredProcDataSet(
                "web.PMReport",
                new[] { "@ProjectId", "@AmcosVersionId" },
                new[] { NpgsqlDbType.Integer, NpgsqlDbType.Integer },
                new object[] { ProjectId.Value, amcosVersionId }).Tables[0];
            CostReport = projectLogic.UpdateLocationDisplay(CostReport.Copy());
            DiscountTable = BuildDiscountTable(ProjectDetails, projectLogic.GetDiscountFactors(amcosVersionId));
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

    private static DataTable ToProjectTable(PMProject project)
    {
        var table = new DataTable("Project");
        table.Columns.Add("Field");
        table.Columns.Add("Value");
        table.Rows.Add("ProjectId", project.ProjectId);
        table.Rows.Add("ProjectName", project.ProjectName);
        table.Rows.Add("Description", project.Description);
        table.Rows.Add("ProjectCreator", project.ProjectCreator);
        table.Rows.Add("YearStart", project.YearStart);
        table.Rows.Add("YearDuration", project.YearDuration);
        table.Rows.Add("CreateDate", project.CreateDate);
        table.Rows.Add("LastUpdate", project.LastUpdate);
        return table;
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

    private static void AddWorksheet(Workbook workbook, string name, DataTable? table)
    {
        var worksheetIndex = workbook.Worksheets.Add();
        var worksheet = workbook.Worksheets[worksheetIndex];
        worksheet.Name = name;
        if (table is null)
        {
            worksheet.Cells[0, 0].PutValue("No data available.");
            return;
        }

        for (var columnIndex = 0; columnIndex < table.Columns.Count; columnIndex++)
        {
            worksheet.Cells[0, columnIndex].PutValue(table.Columns[columnIndex].ColumnName);
        }

        for (var rowIndex = 0; rowIndex < table.Rows.Count; rowIndex++)
        {
            for (var columnIndex = 0; columnIndex < table.Columns.Count; columnIndex++)
            {
                var value = table.Rows[rowIndex][columnIndex];
                worksheet.Cells[rowIndex + 1, columnIndex].PutValue(value == DBNull.Value ? string.Empty : value.ToString());
            }
        }

        worksheet.AutoFitColumns();
    }
}
