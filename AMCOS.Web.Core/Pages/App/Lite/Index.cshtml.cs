using System.Data;
using AMCOS.Data.DataTransferObjects;
using AMCOS.Data.ViewModels;
using AMCOS.Logic;
using AMCOS.Web.Core.Models;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;

namespace AMCOS.Web.Core.Pages.App.Lite;

public class IndexModel : PageModel
{
    private readonly IConfiguration _configuration;

    public IndexModel(IConfiguration configuration)
    {
        _configuration = configuration;
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
                    ScienceTechnologyReinventionLaboratory = request.ScienceTechnologyReinventionLaboratory ?? string.Empty,
                    DependentStatus = request.DependentStatus ?? "-1",
                    NumberOfDependents = request.NumberOfDependents,
                    OverheadPercent = request.OverheadPercent ?? 0,
                    InflationConversionType = request.InflationConversionType ?? "ThenToThen",
                    InflationYear = request.InflationYear ?? DefaultYear.ToString(),
                    AmcosVersionId = amcosVersionId
                };

                dataSet = lite.GetCosts(User.Identity?.Name ?? "migration-user");
            }

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
