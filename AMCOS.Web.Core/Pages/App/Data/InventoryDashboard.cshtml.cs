using System.Data;
using AMCOS.Logic;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;

namespace AMCOS.Web.Core.Pages.App.Data;

// Local Inventory dashboard (replaces the QuickSight "inventory" embed).
// Stacked bar of inventory head-count by grade level, split by category group, for a
// chosen pay plan + AMCOS version. Source data.inventory (empty until inventory ETL
// runs, in which case the page shows an empty state). Grade level is a string here
// (data.inventory.gradelevel is varchar and can be non-numeric).
[Authorize]
public class InventoryDashboardModel : PageModel
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
            // Versions come from lookup.amcosversion so the selector is populated even
            // when data.inventory has no rows yet.
            Versions = ReadInts(LocalDashboards.GetAmcosVersions(), "amcosversionid");
            SelectedVersion = version ?? Versions.FirstOrDefault();

            PayPlans = ReadStrings(LocalDashboards.GetInventoryPayPlans(SelectedVersion), "payplan");
            SelectedPayPlan = !string.IsNullOrEmpty(payPlan) && PayPlans.Contains(payPlan)
                ? payPlan
                : PayPlans.FirstOrDefault();
        }
        catch (Exception ex)
        {
            LoadError = $"Inventory data could not be loaded: {ex.Message}";
        }
    }

    // JSON for the chart: { grades:[...strings], series:[{ name, values:[...] }] }.
    public IActionResult OnGetData(string payPlan, int version)
    {
        try
        {
            var table = LocalDashboards.GetInventoryByGrade(payPlan ?? string.Empty, version);

            var grades = new List<string>();
            var groups = new List<string>();
            var cells = new Dictionary<(string, string), long>();

            foreach (DataRow row in table.Rows)
            {
                var grade = row["gradelevel"]?.ToString() ?? "";
                var group = row["categorygroupcode"]?.ToString() ?? "Other";
                var count = row["inventory"] == DBNull.Value ? 0L : Convert.ToInt64(row["inventory"]);

                if (!grades.Contains(grade)) grades.Add(grade);
                if (!groups.Contains(group)) groups.Add(group);
                cells[(grade, group)] = count;
            }

            grades.Sort(StringComparer.OrdinalIgnoreCase);
            groups.Sort(StringComparer.OrdinalIgnoreCase);

            var series = groups.Select(group => new
            {
                name = group,
                values = grades.Select(grade => cells.TryGetValue((grade, group), out var v) ? v : 0L).ToList()
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
