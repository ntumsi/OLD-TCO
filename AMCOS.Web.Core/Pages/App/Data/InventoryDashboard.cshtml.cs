using System.Data;
using AMCOS.Logic;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;

namespace AMCOS.Web.Core.Pages.App.Data;

// Local Inventory dashboard (replaces the QuickSight "inventory" embed).
// Compares total inventory head-count by grade level between TWO AMCOS versions for a
// chosen pay plan. Source data.inventory (empty until inventory ETL -> empty state).
// Grade level is a string (data.inventory.gradelevel is varchar / can be non-numeric).
[Authorize]
public class InventoryDashboardModel : PageModel
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
            Versions = ReadInts(LocalDashboards.GetAmcosVersions(), "amcosversionid");
            VersionA = versionA ?? Versions.ElementAtOrDefault(0);
            VersionB = versionB ?? (Versions.Count > 1 ? Versions[1] : VersionA);

            PayPlans = ReadStrings(LocalDashboards.GetAllInventoryPayPlans(), "payplan");
            SelectedPayPlan = !string.IsNullOrEmpty(payPlan) && PayPlans.Contains(payPlan)
                ? payPlan
                : PayPlans.FirstOrDefault();
        }
        catch (Exception ex)
        {
            LoadError = $"Inventory data could not be loaded: {ex.Message}";
        }
    }

    // JSON: { grades:[...strings], versionA, versionB, a:[...], b:[...] }.
    public IActionResult OnGetData(string payPlan, int versionA, int versionB)
    {
        try
        {
            var a = SumByGrade(LocalDashboards.GetInventoryTotalByGrade(payPlan ?? string.Empty, versionA));
            var b = SumByGrade(LocalDashboards.GetInventoryTotalByGrade(payPlan ?? string.Empty, versionB));

            var grades = a.Keys.Union(b.Keys).OrderBy(g => g, StringComparer.OrdinalIgnoreCase).ToList();

            return new JsonResult(new
            {
                grades,
                versionA,
                versionB,
                a = grades.Select(g => a.TryGetValue(g, out var v) ? v : 0L).ToList(),
                b = grades.Select(g => b.TryGetValue(g, out var v) ? v : 0L).ToList()
            });
        }
        catch (Exception ex)
        {
            return new ObjectResult(new { error = ex.Message }) { StatusCode = 500 };
        }
    }

    private static Dictionary<string, long> SumByGrade(DataTable table)
    {
        var map = new Dictionary<string, long>();
        foreach (DataRow row in table.Rows)
        {
            var grade = row["gradelevel"]?.ToString() ?? "";
            var value = row["inventory"] == DBNull.Value ? 0L : Convert.ToInt64(row["inventory"]);
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
