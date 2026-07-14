using System.Security.Claims;
using AMCOS.Logic;
using AMCOS.Logic.Helpers;
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
        // amcosuser.sponsoruserid references amcosuser.userid — NOT the OIDC DoD-ID claim.
        // Resolve the current app user (by DoD id / email) and use its UserId, mirroring the
        // legacy SponsorAction, which keyed the queue on the sponsor's amcosuser.UserId.
        var sponsorId = (User.Identity as ClaimsIdentity) is { IsAuthenticated: true } id
            ? UserAdministration.GetCurrentUser(id)?.UserId
            : null;

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

            // Notify the admin queue that a sponsor approved this applicant (legacy SponsorAction).
            var sponsor = CurrentSponsor();
            var body =
                $"<p>Dear DASA-CE Representative,</p> <p>{userName}'s application for access to the AMCOS " +
                "was approved by sponsor and is now pending your action.</p> " +
                SponsorLines(sponsor);
            SendWorkflowEmail(
                new[] { _configuration["AmcosAdminEmail"] ?? string.Empty },
                "AMCOS Access Request - Sponsor Approved", body, sponsor?.Email);

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

            // Notify the applicant that their sponsor disapproved the request (legacy SponsorAction).
            var sponsor = CurrentSponsor();
            var body =
                $"<p>Dear {userName}, </p> <p>Your application for access to the AMCOS was disapproved by " +
                "your sponsor.  Please contact your sponsor for further information.</p> " +
                SponsorLines(sponsor);
            SendWorkflowEmail(
                new[] { UserAdministration.GetUserEmail(userId) },
                "AMCOS Access Request - Sponsor Disapproved", body, sponsor?.Email);

            StatusMessage = $"User {userName} denied.";
        }
        catch (Exception ex)
        {
            StatusMessage = $"Error denying user: {ex.Message}";
        }

        return RedirectToPage();
    }

    private AMCOS.Data.Entities.AMCOSUser? CurrentSponsor() =>
        (User.Identity as ClaimsIdentity) is { IsAuthenticated: true } id
            ? UserAdministration.GetCurrentUser(id) : null;

    // The sponsor contact block appended to both sponsor emails (legacy {1}..{5}).
    private static string SponsorLines(AMCOS.Data.Entities.AMCOSUser? s)
    {
        if (s == null) return string.Empty;
        var fullName = $"{s.FirstName} {s.LastName}".Trim();
        return $"<p>{fullName} <br /><p>{s.Email} <br /><p>{s.ComPhone} <br /><p>{s.ArmyAccountType} <br /><p>{s.Macom} </p>";
    }

    private void SendWorkflowEmail(string[] to, string subject, string body, string? from)
    {
        var host = _configuration["Smtp:Host"] ?? string.Empty;
        var port = int.TryParse(_configuration["Smtp:Port"], out var p) ? p : 25;
        CoreEmailHelper.Send(host, port, from ?? (_configuration["AmcosAdminEmail"] ?? string.Empty), to, subject, body);
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
