using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;
using Npgsql;

namespace AMCOS.Web.Core.Pages.App.Data;

[Authorize]
public class SkillsModel : PageModel
{
    private readonly IConfiguration _configuration;

    public SkillsModel(IConfiguration configuration)
    {
        _configuration = configuration;
    }

    public List<(string Value, string Text)> PayPlans { get; private set; } = new();
    public string? LoadError { get; private set; }

    public void OnGet()
    {
        try
        {
            using var conn = OpenConnection();
            PayPlans = Query(conn,
                "SELECT DISTINCT payplan, description FROM lookup.payplan ORDER BY payplan",
                r => (r.GetString(0), r.GetString(1)));
        }
        catch (Exception ex)
        {
            LoadError = ex.Message;
        }
    }

    public IActionResult OnGetGroups(string payPlan)
    {
        using var conn = OpenConnection();
        var items = Query(conn,
            "SELECT DISTINCT categorygroupcode FROM data.groupbypayplan WHERE payplan = @p ORDER BY categorygroupcode",
            r => r.GetString(0), ("@p", payPlan));
        return new JsonResult(items);
    }

    public IActionResult OnGetSubgroups(string payPlan, string group)
    {
        using var conn = OpenConnection();
        var items = Query(conn,
            "SELECT categorysubgroupcode FROM data.groupsubgroupbypayplan WHERE payplan = @p AND categorygroupcode = @g ORDER BY categorysubgroupcode",
            r => r.GetString(0), ("@p", payPlan), ("@g", group));
        return new JsonResult(items);
    }

    public IActionResult OnGetDetails(string payPlan, string group, string subgroup)
    {
        using var conn = OpenConnection();
        var rows = Query(conn,
            "SELECT categorygroupcode, categorygroupdescription, categorysubgroupcode, categorysubgroupdescription " +
            "FROM data.groupsubgroupbypayplan WHERE payplan = @p AND categorygroupcode = @g AND categorysubgroupcode = @s",
            r => new
            {
                groupCode = r.IsDBNull(0) ? null : r.GetString(0),
                groupDescription = r.IsDBNull(1) ? null : r.GetString(1),
                subgroupCode = r.IsDBNull(2) ? null : r.GetString(2),
                subgroupDescription = r.IsDBNull(3) ? null : r.GetString(3)
            },
            ("@p", payPlan), ("@g", group), ("@s", subgroup));
        return new JsonResult(rows.FirstOrDefault());
    }

    private NpgsqlConnection OpenConnection()
    {
        var connStr = _configuration.GetConnectionString("AmcosPostgres")
            ?? _configuration.GetConnectionString("AmcosEF")
            ?? _configuration.GetConnectionString("AmcosAdo")
            ?? string.Empty;
        var conn = new NpgsqlConnection(connStr);
        conn.Open();
        return conn;
    }

    private static List<T> Query<T>(NpgsqlConnection conn, string sql, Func<NpgsqlDataReader, T> map, params (string Name, object? Value)[] parameters)
    {
        using var cmd = new NpgsqlCommand(sql, conn);
        foreach (var (name, value) in parameters)
            cmd.Parameters.AddWithValue(name, value ?? DBNull.Value);
        using var reader = cmd.ExecuteReader();
        var results = new List<T>();
        while (reader.Read())
            results.Add(map(reader));
        return results;
    }
}
