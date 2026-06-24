using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc.RazorPages;
using Npgsql;

namespace AMCOS.Web.Core.Pages.Admin;

[Authorize(Roles = "Admin")]
public class LogModel : PageModel
{
    private readonly IConfiguration _configuration;

    public List<ErrorLogEntry> Entries { get; private set; } = new();
    public ErrorLogEntry? SelectedEntry { get; private set; }
    public string? LoadError { get; private set; }

    public LogModel(IConfiguration configuration) => _configuration = configuration;

    public void OnGet(int? errorId)
    {
        try
        {
            using var conn = OpenConnection();

            using var listCmd = new NpgsqlCommand(
                "SELECT errorid, errortime, userid, errorpage, errordetail FROM web.applicationerrorlog ORDER BY errortime DESC LIMIT 200",
                conn);
            using var reader = listCmd.ExecuteReader();
            while (reader.Read())
                Entries.Add(new ErrorLogEntry(
                    reader.GetInt32(0),
                    reader.IsDBNull(1) ? null : reader.GetDateTime(1),
                    reader.IsDBNull(2) ? null : reader.GetString(2),
                    reader.IsDBNull(3) ? null : reader.GetString(3),
                    reader.IsDBNull(4) ? null : reader.GetString(4)));
            reader.Close();

            if (errorId.HasValue)
            {
                using var detailCmd = new NpgsqlCommand(
                    "SELECT errorid, errortime, userid, errorpage, errordetail FROM web.applicationerrorlog WHERE errorid = @id",
                    conn);
                detailCmd.Parameters.AddWithValue("@id", errorId.Value);
                using var dr = detailCmd.ExecuteReader();
                if (dr.Read())
                    SelectedEntry = new ErrorLogEntry(
                        dr.GetInt32(0),
                        dr.IsDBNull(1) ? null : dr.GetDateTime(1),
                        dr.IsDBNull(2) ? null : dr.GetString(2),
                        dr.IsDBNull(3) ? null : dr.GetString(3),
                        dr.IsDBNull(4) ? null : dr.GetString(4));
            }
        }
        catch (Exception ex)
        {
            LoadError = ex.Message;
        }
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

    public record ErrorLogEntry(int ErrorId, DateTime? ErrorTime, string? UserId, string? ErrorPage, string? ErrorDetail);
}
