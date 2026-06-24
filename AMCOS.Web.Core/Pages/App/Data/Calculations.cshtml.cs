using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;
using Npgsql;

namespace AMCOS.Web.Core.Pages.App.Data;

[Authorize]
public class CalculationsModel : PageModel
{
    private readonly IConfiguration _configuration;

    public CalculationsModel(IConfiguration configuration)
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
                "SELECT a.payplan, b.description FROM data.costelement a " +
                "INNER JOIN lookup.payplan b ON a.payplan = b.payplan " +
                "GROUP BY a.payplan, b.description ORDER BY b.description",
                r => (r.GetString(0), r.GetString(1)));
        }
        catch (Exception ex)
        {
            LoadError = ex.Message;
        }
    }

    public IActionResult OnGetAppns(string payPlan)
    {
        using var conn = OpenConnection();
        var items = Query(conn,
            "SELECT appn FROM data.costelement WHERE payplan = @p GROUP BY appn ORDER BY appn",
            r => r.GetString(0), ("@p", payPlan));
        return new JsonResult(items);
    }

    public IActionResult OnGetCategories(string payPlan, string appn)
    {
        using var conn = OpenConnection();
        var items = Query(conn,
            "SELECT costelementcategory FROM data.costelement WHERE payplan = @p AND appn = @a GROUP BY costelementcategory ORDER BY costelementcategory",
            r => r.GetString(0), ("@p", payPlan), ("@a", appn));
        return new JsonResult(items);
    }

    public IActionResult OnGetElements(string payPlan, string appn, string category)
    {
        using var conn = OpenConnection();
        var items = Query(conn,
            "SELECT costelementname FROM data.costelement WHERE payplan = @p AND appn = @a AND costelementcategory = @c GROUP BY costelementname ORDER BY costelementname",
            r => r.GetString(0), ("@p", payPlan), ("@a", appn), ("@c", category));
        return new JsonResult(items);
    }

    public IActionResult OnGetDetails(string payPlan, string appn, string category, string element)
    {
        using var conn = OpenConnection();
        var rows = Query(conn,
            "SELECT costelementname, description, businesslogic, basisofcomputation, source " +
            "FROM data.costelement WHERE payplan = @p AND appn = @a AND costelementcategory = @c AND costelementname = @e",
            r => new
            {
                name = r.IsDBNull(0) ? null : r.GetString(0),
                description = r.IsDBNull(1) ? null : r.GetString(1),
                businessLogic = r.IsDBNull(2) ? null : r.GetString(2),
                basisOfComputation = r.IsDBNull(3) ? null : r.GetString(3),
                source = r.IsDBNull(4) ? null : r.GetString(4)
            },
            ("@p", payPlan), ("@a", appn), ("@c", category), ("@e", element));
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
