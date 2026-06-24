using AMCOS.Data.Entities;
using AMCOS.Logic;
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

            if (_environment.IsDevelopment())
            {
                EmailPreview =
                    $"[Dev — no email sent] To: {email} | Subject: AMCOS Account Approved | " +
                    $"Body: Hello {userName}, your AMCOS account registration has been approved. " +
                    "You may now sign in at the AMCOS portal.";
            }

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
            StatusMessage = $"User {userName} denied.";
        }
        catch (Exception ex)
        {
            StatusMessage = $"Error denying user: {ex.Message}";
        }

        return RedirectToPage();
    }
}
