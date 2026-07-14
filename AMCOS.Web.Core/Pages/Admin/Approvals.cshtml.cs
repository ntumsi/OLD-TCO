using AMCOS.Data.Entities;
using AMCOS.Logic;
using AMCOS.Logic.Helpers;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;

namespace AMCOS.Web.Core.Pages.Admin;

[Authorize(Roles = "Admin")]
public class ApprovalsModel : PageModel
{
    private readonly IConfiguration _configuration;
    private readonly IWebHostEnvironment _environment;

    public ApprovalsModel(IConfiguration configuration, IWebHostEnvironment environment)
    {
        _configuration = configuration;
        _environment = environment;
    }

    public List<PendingUsers> PendingUsers { get; private set; } = new();
    public string? LoadError { get; private set; }

    [TempData]
    public string? StatusMessage { get; set; }

    [TempData]
    public string? EmailPreview { get; set; }

    public void OnGet()
    {
        try
        {
            PendingUsers = UserAdministration.GetPendingUsers();
        }
        catch (Exception ex)
        {
            LoadError = ex.Message;
        }
    }

    public IActionResult OnPostApprove(string userId, string userName, string email)
    {
        try
        {
            UserAdministration.ApproveUser(userId);

            var adminEmail = _configuration["AmcosAdminEmail"] ?? string.Empty;
            var amcosUrl = _configuration["AmcosUrl"] ?? string.Empty;
            var subject = "AMCOS Access Request Approved";
            var body =
                $"<p>Dear {userName}, </p>" +
                "<p>Congratulations.  Your application for access to the AMCOS is approved.  " +
                $"You can now access the website, {amcosUrl}.</p>" +
                "<p>For your reference a User Access AMCOS Login Process document has been attached to this email.</p>" +
                "<p>Thank you for using AMCOS.</p>" +
                $"<p>DASA-CE <br/> {adminEmail}</p>";

            SendWorkflowEmail(Recipients(userId, email), subject, body, LoginGuideAttachment());

            if (_environment.IsDevelopment())
                EmailPreview = $"[Dev preview] To: {email} | Subject: {subject}";

            StatusMessage = $"User {userName} approved.";
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
            UserAdministration.DenyUser(userId);

            var adminEmail = _configuration["AmcosAdminEmail"] ?? string.Empty;
            var subject = "AMCOS Access Request Denied";
            var body =
                $"<p>Dear {userName}, </p>" +
                "<p>Your application for access to the AMCOS has been denied.  For further information, " +
                $"please contact DASA-CE, at {adminEmail}. You may reapply for access when your issue " +
                "has been resolved.</p>" +
                "<p>Respectfully, <br/> DASA-CE</p>";

            SendWorkflowEmail(Recipients(userId, null), subject, body);

            if (_environment.IsDevelopment())
                EmailPreview = $"[Dev preview] To: {UserAdministration.GetUserEmail(userId)} | Subject: {subject}";

            StatusMessage = $"User {userName} denied.";
        }
        catch (Exception ex)
        {
            StatusMessage = $"Error denying user: {ex.Message}";
        }

        return RedirectToPage();
    }

    // Recipient = the applicant plus their sponsor (if any), mirroring the legacy AdminApproval flow.
    private string[] Recipients(string userId, string? applicantEmail)
    {
        var list = new List<string>();
        var email = string.IsNullOrWhiteSpace(applicantEmail) ? UserAdministration.GetUserEmail(userId) : applicantEmail;
        if (!string.IsNullOrWhiteSpace(email)) list.Add(email);
        try
        {
            var sponsorId = UserAdministration.GetUserById(userId)?.SponsorUserId;
            if (!string.IsNullOrWhiteSpace(sponsorId))
            {
                var sponsorEmail = UserAdministration.GetUserEmail(sponsorId);
                if (!string.IsNullOrWhiteSpace(sponsorEmail)) list.Add(sponsorEmail);
            }
        }
        catch { /* sponsor lookup is best-effort */ }
        return list.ToArray();
    }

    private void SendWorkflowEmail(string[] to, string subject, string body, string[]? attachments = null)
    {
        var host = _configuration["Smtp:Host"] ?? string.Empty;
        var port = int.TryParse(_configuration["Smtp:Port"], out var p) ? p : 25;
        var from = _configuration["AmcosAdminEmail"] ?? string.Empty;
        CoreEmailHelper.Send(host, port, from, to, subject, body, attachments);
    }

    // Resolves the configured login-guide document from the served /Public folder, if present.
    private string[]? LoginGuideAttachment()
    {
        var guide = _configuration["AmcosUserLoginGuideFile"];
        if (string.IsNullOrWhiteSpace(guide)) return null;
        var path = Path.GetFullPath(Path.Combine(_environment.ContentRootPath, "..", "AMCOS.Web", "Public", guide));
        return System.IO.File.Exists(path) ? new[] { path } : null;
    }
}
