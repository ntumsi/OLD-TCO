using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;
using Npgsql;

namespace AMCOS.Web.Core.Pages.Admin;

[Authorize]
public class SponsorActionModel : PageModel
{
    private readonly IConfiguration _configuration;

    public SponsorActionModel(IConfiguration configuration)
    {
        _configuration = configuration;
    }

    public List<PendingSponsorUser> PendingUsers { get; private set; } = new();
    public string? LoadError { get; private set; }

    [TempData]
    public string? StatusMessage { get; set; }

    public void OnGet()
    {
        var sponsorId = User.FindFirst(ClaimTypes.NameIdentifier)?.Value
                     ?? User.Identity?.Name;

        if (string.IsNullOrWhiteSpace(sponsorId))
        {
            LoadError = "Unable to resolve current user identity. Please sign in again.";
            return;
        }

        try
        {
            using var conn = OpenConnection();
            using var cmd = new NpgsqlCommand(
                "SELECT userid, firstname || ' ' || lastname AS fullname, email, comphone, " +
                "officename, macom, selfaccounttype, armyrank, companyname, lastlogin " +
                "FROM webuser.amcosuser " +
                "WHERE userstatus = 'PendingSponsor' AND sponsoruserid = @sid",
                conn);
            cmd.Parameters.AddWithValue("@sid", sponsorId);

            using var reader = cmd.ExecuteReader();
            while (reader.Read())
            {
                PendingUsers.Add(new PendingSponsorUser(
                    UserId:          reader.GetString(0),
                    FullName:        reader.IsDBNull(1)  ? null : reader.GetString(1),
                    Email:           reader.IsDBNull(2)  ? null : reader.GetString(2),
                    Phone:           reader.IsDBNull(3)  ? null : reader.GetString(3),
                    OfficeName:      reader.IsDBNull(4)  ? null : reader.GetString(4),
                    Macom:           reader.IsDBNull(5)  ? null : reader.GetString(5),
                    AccountType:     reader.IsDBNull(6)  ? null : reader.GetString(6),
                    ArmyRank:        reader.IsDBNull(7)  ? null : reader.GetString(7),
                    CompanyName:     reader.IsDBNull(8)  ? null : reader.GetString(8),
                    LastLogin:       reader.IsDBNull(9)  ? null : reader.GetDateTime(9)
                ));
            }
        }
        catch (Exception ex)
        {
            LoadError = ex.Message;
        }
    }

    public IActionResult OnPostApprove(string userId, string userName)
    {
        try
        {
            using var conn = OpenConnection();
            using var cmd = new NpgsqlCommand(
                "UPDATE webuser.amcosuser SET userstatus = 'PendingAdmin' WHERE userid = @uid",
                conn);
            cmd.Parameters.AddWithValue("@uid", userId);
            cmd.ExecuteNonQuery();

            StatusMessage = $"User {userName} approved and moved to admin review.";
        }
        catch (Exception ex)
        {
            StatusMessage = $"Error approving user: {ex.Message}";
        }

        return RedirectToPage();
    }

    public IActionResult OnPostDeny(string userId, string userName)
    {
        try
        {
            using var conn = OpenConnection();
            using var cmd = new NpgsqlCommand(
                "UPDATE webuser.amcosuser SET userstatus = 'Denied' WHERE userid = @uid",
                conn);
            cmd.Parameters.AddWithValue("@uid", userId);
            cmd.ExecuteNonQuery();

            StatusMessage = $"User {userName} denied.";
        }
        catch (Exception ex)
        {
            StatusMessage = $"Error denying user: {ex.Message}";
        }

        return RedirectToPage();
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

    public record PendingSponsorUser(
        string  UserId,
        string? FullName,
        string? Email,
        string? Phone,
        string? OfficeName,
        string? Macom,
        string? AccountType,
        string? ArmyRank,
        string? CompanyName,
        DateTime? LastLogin
    );
}
