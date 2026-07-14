using System.Data;
using AMCOS.Logic;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;

namespace AMCOS.Web.Core.Pages.App.Data;

// Local Cost Compare dashboard (replaces the QuickSight "cost-compare" embed).
// Grouped bar of total cost amount by grade level, split by cost-element category,
// for a chosen pay plan + AMCOS version. Data from data.costs via LocalDashboards.
[Authorize]
public class CostCompareModel : PageModel
{
    public List<int> Versions { get; private set; } = new();
    public int SelectedVersion { get; private set; }
    public List<string> PayPlans { get; private set; } = new();
    public string? SelectedPayPlan { get; private set; }
    public string? LoadError { get; private set; }

    public void OnGet(int? version, string? payPlan)
    {
        try
        {
            Versions = ReadInts(LocalDashboards.GetCostVersions(), "amcosversionid");
            SelectedVersion = version ?? Versions.FirstOrDefault();

            PayPlans = ReadStrings(LocalDashboards.GetCostPayPlans(SelectedVersion), "payplan");
            SelectedPayPlan = !string.IsNullOrEmpty(payPlan) && PayPlans.Contains(payPlan)
                ? payPlan
                : PayPlans.FirstOrDefault();
        }
        catch (Exception ex)
        {
            LoadError = $"Cost data could not be loaded: {ex.Message}";
        }
    }

    // JSON for the chart: { grades:[...], series:[{ name, values:[...] }] }.
    // Missing (grade, category) combinations are filled with 0 so every series aligns
    // to the same grade axis.
    public IActionResult OnGetData(string payPlan, int version)
    {
        try
        {
            var table = LocalDashboards.GetCostCompare(payPlan ?? string.Empty, version);

            var grades = new List<int>();
            var categories = new List<string>();
            var cells = new Dictionary<(int, string), decimal>();

            foreach (DataRow row in table.Rows)
            {
                var grade = Convert.ToInt32(row["gradelevel"]);
                var category = row["costelementcategory"]?.ToString() ?? "Other";
                var amount = row["amount"] == DBNull.Value ? 0m : Convert.ToDecimal(row["amount"]);

                if (!grades.Contains(grade)) grades.Add(grade);
                if (!categories.Contains(category)) categories.Add(category);
                cells[(grade, category)] = amount;
            }

            grades.Sort();
            categories.Sort(StringComparer.OrdinalIgnoreCase);

            var series = categories.Select(category => new
            {
                name = category,
                values = grades.Select(grade => cells.TryGetValue((grade, category), out var v) ? v : 0m).ToList()
            });

            return new JsonResult(new { grades, series });
        }
        catch (Exception ex)
        {
            return new ObjectResult(new { error = ex.Message }) { StatusCode = 500 };
        }
    }

    private static List<int> ReadInts(DataTable table, string column)
    {
        var list = new List<int>();
        foreach (DataRow row in table.Rows)
            if (row[column] != DBNull.Value) list.Add(Convert.ToInt32(row[column]));
        return list;
    }

    private static List<string> ReadStrings(DataTable table, string column)
    {
        var list = new List<string>();
        foreach (DataRow row in table.Rows)
            if (row[column] != DBNull.Value) list.Add(row[column].ToString()!);
        return list;
    }
}
