using System.Data;
using AMCOS.Data.DataTransferObjects;
using AMCOS.Data.ViewModels;
using AMCOS.Logic;
using AMCOS.Web.Core.Models;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;

namespace AMCOS.Web.Core.Pages.App.Lite;

[Authorize]
public class IndexModel : PageModel
{
    private readonly IConfiguration _configuration;
    private readonly IWebHostEnvironment _environment;

    public IndexModel(IConfiguration configuration, IWebHostEnvironment environment)
    {
        _configuration = configuration;
        _environment = environment;
    }

    public List<PayPlanDto> PayPlans { get; private set; } = new();
    public string? LoadError { get; private set; }
    public int DefaultYear { get; private set; }
    public decimal CceMaxPayFootnote { get; private set; }
    public string CceWagesAndSalaries { get; private set; } = "0%";
    public string CceBenefitsAll { get; private set; } = "0%";

    public void OnGet()
    {
        DefaultYear = GetIntSetting("DefaultYear", DateTime.UtcNow.Year);

        try
        {
            var amcosVersionId = GetIntSetting("AmcosVersionId", 202501);
            var lite = new AMCOS.Logic.Lite();
            PayPlans = lite.GetOptionListPayPlan();

            var cceCosts = new Costs().GetCceCosts(amcosVersionId);
            CceMaxPayFootnote = SingleValue.Get("CCE", "MaxPayFootnote", amcosVersionId);
            CceWagesAndSalaries = cceCosts.WagesAndSalaries;
            CceBenefitsAll = cceCosts.BenefitsAll;
        }
        catch (Exception ex)
        {
            LoadError = $"Legacy data services could not be loaded: {ex.Message}";
        }
    }

    public IActionResult OnGetCostData([FromQuery] LiteCostRequest request)
    {
        try
        {
            var amcosVersionId = GetIntSetting("AmcosVersionId", 202501);
            DataSet dataSet;

            if (string.Equals(request.PayPlan, "CCE", StringComparison.OrdinalIgnoreCase))
            {
                dataSet = new AMCOS.Logic.Lite("CCE").Costs(
                    request.CategoryGroupCode ?? string.Empty,
                    request.CategorySubgroupCode ?? string.Empty,
                    request.LocationId,
                    request.OverheadPercent ?? 0,
                    request.InflationConversionType ?? "ThenToThen",
                    request.InflationYear ?? DefaultYear.ToString(),
                    amcosVersionId);
            }
            else
            {
                var lite = new AMCOS.Logic.Lite
                {
                    PayPlan = request.PayPlan ?? string.Empty,
                    CostSummaryName = request.CostSummaryName ?? "Default",
                    CategoryGroupCode = request.CategoryGroupCode ?? string.Empty,
                    CategorySubgroupCode = request.CategorySubgroupCode ?? string.Empty,
                    CareerProgramNumber = request.CareerProgramNumber ?? "-1",
                    LocationId = request.LocationId,
                    ScienceTechnologyReinventionLaboratory = string.IsNullOrEmpty(request.ScienceTechnologyReinventionLaboratory) ? "-1" : request.ScienceTechnologyReinventionLaboratory,
                    DependentStatus = request.DependentStatus ?? "-1",
                    NumberOfDependents = request.NumberOfDependents,
                    OverheadPercent = request.OverheadPercent ?? 0,
                    InflationConversionType = request.InflationConversionType ?? "ThenToThen",
                    InflationYear = request.InflationYear ?? DefaultYear.ToString(),
                    AmcosVersionId = amcosVersionId
                };

                dataSet = lite.GetCosts(User.Identity?.Name ?? "migration-user");
            }

            // DataAccessUtility.ExecuteStoredProcDataSet already expands the
            // (result_set_name, row_data jsonb) payload into one DataTable per result set
            // (e.g. "costs"), so the tables here are the display-ready cost grids.
            return new JsonResult(new
            {
                tables = dataSet.Tables.Cast<DataTable>().Select((table, index) => new
                {
                    name = string.IsNullOrWhiteSpace(table.TableName) ? $"Table{index}" : table.TableName,
                    rows = ToRows(table)
                })
            });
        }
        catch (Exception ex)
        {
            return new ObjectResult(new { error = ex.Message }) { StatusCode = 500 };
        }
    }

    // Active-component pay-plan families (mirrors the hardcoded arrays in amcos-lite.js). Used to
    // pick the inflation-rate header column set, matching legacy default.aspx.vb PopulateRateHeader.
    // The migrated payplantags table only carries coarse tags, so we do NOT rely on PayPlan.GetTags.
    private static readonly string[] ActiveMilitaryPayPlans = { "AE", "AO", "AWO" };
    private static readonly string[] NationalGuardPayPlans = { "NE", "NO", "NWO" };
    private static readonly string[] ReservePayPlans = { "RE", "RO", "RWO" };

    // Returns the AMCOS Lite inflation-rate header row for the chosen pay-plan family, as JSON
    // { headers:[...], row:{col:value} }. Values are fractional inflation rates (formatted client-side).
    public IActionResult OnGetInflationHeader(string payPlan, string conversionType, string year)
    {
        try
        {
            var amcosVersionId = GetIntSetting("AmcosVersionId", 202501);
            var dt = InflationHeaderTable(payPlan, conversionType, year, amcosVersionId);
            var headers = dt.Columns.Cast<DataColumn>().Select(c => c.ColumnName).ToList();
            Dictionary<string, object?>? row = dt.Rows.Count > 0
                ? headers.ToDictionary(h => h, h => dt.Rows[0][h] == DBNull.Value ? null : dt.Rows[0][h])
                : null;
            return new JsonResult(new { headers, row });
        }
        catch (Exception ex)
        {
            return new ObjectResult(new { error = ex.Message }) { StatusCode = 500 };
        }
    }

    // Shared by OnGetInflationHeader and the Excel export. Column list per pay-plan family, aliased
    // to legacy display labels; names must match web.getinflationrateheader output casing exactly.
    private DataTable InflationHeaderTable(string payPlan, string conversionType, string year, int amcosVersionId)
    {
        var pp = (payPlan ?? string.Empty).ToUpperInvariant();
        string cols;
        if (ActiveMilitaryPayPlans.Contains(pp))
            cols = "appropriation AS \"Appropriation\", mpa AS \"MPA\", \"MPA Non-Pay\", oma AS \"OMA\", oma_1 AS \"OMA_1\", omdw AS \"OMDW\", \"Federal OM\"";
        else if (NationalGuardPayPlans.Contains(pp))
            cols = "appropriation AS \"Appropriation\", ngpa AS \"NGPA\", mpa AS \"MPA\", omng AS \"OMNG\", oma AS \"OMA\", oma_1 AS \"OMA_1\", omng_1 AS \"OMNG_1\"";
        else if (ReservePayPlans.Contains(pp))
            cols = "appropriation AS \"Appropriation\", rpa AS \"RPA\", mpa AS \"MPA\", omar AS \"OMAR\", oma AS \"OMA\", oma_1 AS \"OMA_1\", omar_1 AS \"OMAR_1\"";
        else if (pp == "CCE")
            cols = "appropriation AS \"Appropriation\", oma AS \"OMA\"";
        else // Civilian / GFEBS / Wage
            cols = "appropriation AS \"Appropriation\", \"Army CivPay\", oma AS \"OMA\", \"Federal OM\"";

        return DataAccessUtility.GetDataTableByStaticSql(
            $"SELECT {cols} FROM web.GetInflationRateHeader(@ConversionType,@Year,@AmcosVersionId);",
            new[] { "@ConversionType", "@Year", "@AmcosVersionId" },
            new object[] { conversionType ?? "ThenToThen", year ?? DefaultYear.ToString(), amcosVersionId });
    }

    // Downloads the current AMCOS Lite view as a formatted .xlsx (legacy default.aspx IbDownloadExcel):
    // classification banner, inflation-rate header, filter selections, and the cost detail grid.
    public IActionResult OnGetExport([FromQuery] LiteCostRequest request)
    {
        try
        {
            var amcosVersionId = GetIntSetting("AmcosVersionId", 202501);
            DataSet dataSet;
            if (string.Equals(request.PayPlan, "CCE", StringComparison.OrdinalIgnoreCase))
            {
                dataSet = new AMCOS.Logic.Lite("CCE").Costs(
                    request.CategoryGroupCode ?? string.Empty, request.CategorySubgroupCode ?? string.Empty,
                    request.LocationId, request.OverheadPercent ?? 0,
                    request.InflationConversionType ?? "ThenToThen",
                    request.InflationYear ?? DefaultYear.ToString(), amcosVersionId);
            }
            else
            {
                var lite = new AMCOS.Logic.Lite
                {
                    PayPlan = request.PayPlan ?? string.Empty,
                    CostSummaryName = request.CostSummaryName ?? "Default",
                    CategoryGroupCode = request.CategoryGroupCode ?? string.Empty,
                    CategorySubgroupCode = request.CategorySubgroupCode ?? string.Empty,
                    CareerProgramNumber = request.CareerProgramNumber ?? "-1",
                    LocationId = request.LocationId,
                    ScienceTechnologyReinventionLaboratory = string.IsNullOrEmpty(request.ScienceTechnologyReinventionLaboratory) ? "-1" : request.ScienceTechnologyReinventionLaboratory,
                    DependentStatus = request.DependentStatus ?? "-1",
                    NumberOfDependents = request.NumberOfDependents,
                    OverheadPercent = request.OverheadPercent ?? 0,
                    InflationConversionType = request.InflationConversionType ?? "ThenToThen",
                    InflationYear = request.InflationYear ?? DefaultYear.ToString(),
                    AmcosVersionId = amcosVersionId
                };
                dataSet = lite.GetCosts(User.Identity?.Name ?? "migration-user");
            }

            var costs = dataSet.Tables.Contains("costs") ? dataSet.Tables["costs"]!
                : (dataSet.Tables.Count > 0 ? dataSet.Tables[0] : new DataTable("costs"));
            var inflation = InflationHeaderTable(request.PayPlan ?? string.Empty,
                request.InflationConversionType ?? "ThenToThen",
                request.InflationYear ?? DefaultYear.ToString(), amcosVersionId);
            var cceMaxPay = SingleValue.Get("CCE", "MaxPayFootnote", amcosVersionId);

            var bytes = LiteExportHelper.Build(request, costs, inflation, cceMaxPay, DefaultYear);
            return File(bytes, "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
                $"AMCOSLiteData_{DateTime.UtcNow:yyyyMMdd-HHmmss}.xlsx");
        }
        catch (Exception ex)
        {
            return new ObjectResult(new { error = ex.Message }) { StatusCode = 500 };
        }
    }

    private int GetIntSetting(string key, int defaultValue)
    {
        var value = _configuration[key] ?? _configuration[$"AppSettings:{key}"];
        return int.TryParse(value, out var parsedValue) ? parsedValue : defaultValue;
    }

    private static List<Dictionary<string, object?>> ToRows(DataTable table)
    {
        var rows = new List<Dictionary<string, object?>>();
        foreach (DataRow row in table.Rows)
        {
            var values = new Dictionary<string, object?>();
            foreach (DataColumn column in table.Columns)
            {
                values[column.ColumnName] = row[column] == DBNull.Value ? null : row[column];
            }

            rows.Add(values);
        }

        return rows;
    }
}
