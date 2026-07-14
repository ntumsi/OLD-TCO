using System.Data;
using AMCOS.Logic;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;

namespace AMCOS.Web.Core.Pages.App.Data;

// Local Cost Compare dashboard (replaces the QuickSight "cost-compare" embed).
// Compares total cost by grade level between TWO AMCOS versions for a chosen pay plan.
// Data from data.costs via LocalDashboards. Admin-only (was an Administration dashboard).
[Authorize(Roles = "Admin")]
public class CostCompareModel : PageModel
{
    public List<int> Versions { get; private set; } = new();
    public int VersionA { get; private set; }
    public int VersionB { get; private set; }
    public List<string> PayPlans { get; private set; } = new();
    public string? SelectedPayPlan { get; private set; }
    public string? LoadError { get; private set; }

    public void OnGet(int? versionA, int? versionB, string? payPlan)
    {
        try
        {
            // Both defined versions, so either can be picked even if only one has data.
            Versions = ReadInts(LocalDashboards.GetAmcosVersions(), "amcosversionid");
            VersionA = versionA ?? Versions.ElementAtOrDefault(0);
            VersionB = versionB ?? (Versions.Count > 1 ? Versions[1] : VersionA);

            PayPlans = ReadStrings(LocalDashboards.GetAllCostPayPlans(), "payplan");
            SelectedPayPlan = !string.IsNullOrEmpty(payPlan) && PayPlans.Contains(payPlan)
                ? payPlan
                : PayPlans.FirstOrDefault();
        }
        catch (Exception ex)
        {
            LoadError = $"Cost data could not be loaded: {ex.Message}";
        }
    }

    // JSON: { grades:[...], versionA, versionB, a:[...], b:[...] } aligned to the union
    // of grade levels present in either version.
    public IActionResult OnGetData(string payPlan, int versionA, int versionB)
    {
        try
        {
            var a = SumByGrade(LocalDashboards.GetCostTotalByGrade(payPlan ?? string.Empty, versionA), "amount");
            var b = SumByGrade(LocalDashboards.GetCostTotalByGrade(payPlan ?? string.Empty, versionB), "amount");

            var grades = a.Keys.Union(b.Keys).OrderBy(g => g).ToList();

            return new JsonResult(new
            {
                grades,
                versionA,
                versionB,
                a = grades.Select(g => a.TryGetValue(g, out var v) ? v : 0m).ToList(),
                b = grades.Select(g => b.TryGetValue(g, out var v) ? v : 0m).ToList()
            });
        }
        catch (Exception ex)
        {
            return new ObjectResult(new { error = ex.Message }) { StatusCode = 500 };
        }
    }

    private static Dictionary<int, decimal> SumByGrade(DataTable table, string valueColumn)
    {
        var map = new Dictionary<int, decimal>();
        foreach (DataRow row in table.Rows)
        {
            if (row["gradelevel"] == DBNull.Value) continue;
            var grade = Convert.ToInt32(row["gradelevel"]);
            var value = row[valueColumn] == DBNull.Value ? 0m : Convert.ToDecimal(row[valueColumn]);
            map[grade] = value;
        }
        return map;
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
