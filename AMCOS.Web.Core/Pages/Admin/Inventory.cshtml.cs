using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;
using Npgsql;

namespace AMCOS.Web.Core.Pages.Admin;

[Authorize(Roles = "Admin")]
public class InventoryModel : PageModel
{
    private readonly IConfiguration _configuration;

    [BindProperty(SupportsGet = true)] public string PayPlan { get; set; } = string.Empty;
    [BindProperty(SupportsGet = true)] public string Group { get; set; } = string.Empty;
    [BindProperty(SupportsGet = true)] public string SubGroup { get; set; } = string.Empty;

    public List<InventoryRow> Rows { get; private set; } = new();
    public InventoryRow? Totals { get; private set; }
    public string? LoadError { get; private set; }

    public InventoryModel(IConfiguration configuration) => _configuration = configuration;

    public void OnGet()
    {
        if (string.IsNullOrWhiteSpace(PayPlan)) return;

        try
        {
            var devSql = new System.Text.StringBuilder(
                "SELECT gradelevel, SUM(inventory) AS development FROM data.inventory WHERE payplan = @p");
            if (!Group.Contains("ALL", StringComparison.OrdinalIgnoreCase))
                devSql.Append(" AND categorygroupcode = @g");
            if (!SubGroup.Contains("ALL", StringComparison.OrdinalIgnoreCase))
                devSql.Append(" AND categorysubgroupcode = @s");
            devSql.Append(" GROUP BY gradelevel ORDER BY gradelevel");

            var prodSql = new System.Text.StringBuilder(
                "SELECT gradelevel, SUM(inventory) AS production FROM load_inventory.inventory_production WHERE payplan = @p");
            if (!Group.Contains("ALL", StringComparison.OrdinalIgnoreCase))
                prodSql.Append(" AND categorygroupcode = @g");
            if (!SubGroup.Contains("ALL", StringComparison.OrdinalIgnoreCase))
                prodSql.Append(" AND categorysubgroupcode = @s");
            prodSql.Append(" GROUP BY gradelevel ORDER BY gradelevel");

            using var conn = OpenConnection();

            var devMap = RunGradeSumQuery(conn, devSql.ToString(), PayPlan, Group, SubGroup);
            var prodMap = RunGradeSumQuery(conn, prodSql.ToString(), PayPlan, Group, SubGroup);

            var allGrades = devMap.Keys.Union(prodMap.Keys).OrderBy(g => g).ToList();

            foreach (var grade in allGrades)
            {
                devMap.TryGetValue(grade, out var dev);
                prodMap.TryGetValue(grade, out var prod);
                var diff = dev - prod;
                var diffPct = prod == 0 ? null : (double?)((double)diff / (double)prod);
                Rows.Add(new InventoryRow(FormatGradeLabel(grade), dev, prod, diff, diffPct));
            }

            var totalDev = Rows.Sum(r => r.Development);
            var totalProd = Rows.Sum(r => r.Production);
            var totalDiff = totalDev - totalProd;
            var totalPct = totalProd == 0 ? null : (double?)((double)totalDiff / (double)totalProd);
            Totals = new InventoryRow("Total", totalDev, totalProd, totalDiff, totalPct);
        }
        catch (Exception ex)
        {
            LoadError = ex.Message;
        }
    }

    private string FormatGradeLabel(int grade)
    {
        return PayPlan switch
        {
            "AE" or "RE" or "NE" => $"E{grade}",
            "AO" or "RO" or "NO" => $"O{grade}",
            "AWO" or "RWO" or "NWO" => $"W{grade}",
            "SES" => grade switch { 1 => "MIN", 2 => "AVG", 3 => "MAX", _ => "Error" },
            "CCE" => grade.ToString(),
            _ => $"{PayPlan}{grade}"
        };
    }

    private static Dictionary<int, decimal> RunGradeSumQuery(NpgsqlConnection conn, string sql, string payPlan, string group, string subGroup)
    {
        using var cmd = new NpgsqlCommand(sql, conn);
        cmd.Parameters.AddWithValue("@p", payPlan);
        if (!group.Contains("ALL", StringComparison.OrdinalIgnoreCase))
            cmd.Parameters.AddWithValue("@g", group);
        if (!subGroup.Contains("ALL", StringComparison.OrdinalIgnoreCase))
            cmd.Parameters.AddWithValue("@s", subGroup);
        using var reader = cmd.ExecuteReader();
        var result = new Dictionary<int, decimal>();
        while (reader.Read())
            result[reader.GetInt32(0)] = reader.GetDecimal(1);
        return result;
    }

    private NpgsqlConnection OpenConnection()
    {
        var connStr = _configuration.GetConnectionString("AmcosPostgres")
            ?? _configuration.GetConnectionString("AmcosEF")
            ?? string.Empty;
        var conn = new NpgsqlConnection(connStr);
        conn.Open();
        return conn;
    }

    public record InventoryRow(string GradeLabel, decimal Development, decimal Production, decimal Diff, double? DiffPct);
}
