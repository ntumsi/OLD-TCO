using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;

namespace AMCOS.Web.Core.Pages.Admin;

[Authorize(Roles = "Admin")]
public class DashboardModel : PageModel
{
    private readonly IConfiguration _config;

    public string DashboardTitle { get; private set; } = string.Empty;
    public string? EmbedUrl { get; private set; }
    public string? ErrorMessage { get; private set; }

    // Maps route slug → (config key, display title)
    private static readonly Dictionary<string, (string ConfigKey, string Title)> Dashboards = new(StringComparer.OrdinalIgnoreCase)
    {
        ["lite-usage"]       = ("QuickSight:AmcosLiteUsageDashboardId",          "AMCOS Lite Usage"),
        ["user-logins"]      = ("QuickSight:AmcosUserLoginsDashboardId",          "User Logins"),
        ["user-approvals"]   = ("QuickSight:AmcosUserApprovalsDashboardId",       "User Approvals"),
        ["active-users"]     = ("QuickSight:CurrentActiveAmcosUsersDashboardId",  "Active Users"),
        ["cost-compare"]     = ("QuickSight:CostCompareDashboardId",              "Cost Compare"),
        ["helpspot"]         = ("QuickSight:HelpSpotDashboardId",                 "HelpSpot Data"),
        ["visualization"]    = ("QuickSight:VisualizationDashboardId",            "Visualization"),
        ["locality-rates"]   = ("QuickSight:LocalityRateDashboardId",             "Locality Rates"),
        ["pay-schedule"]     = ("QuickSight:PayScheduleDashboardId",              "Pay Schedule"),
    };

    public DashboardModel(IConfiguration config) => _config = config;

    public IActionResult OnGet(string slug)
    {
        if (!Dashboards.TryGetValue(slug, out var info))
            return NotFound();

        DashboardTitle = info.Title;

        var dashboardId = _config[info.ConfigKey];
        var awsAccountId = _config["AwsAccountId"];
        var awsRegionCode = _config["AwsRegionCode"] ?? "us-gov-west-1";

        if (string.IsNullOrWhiteSpace(dashboardId) || string.IsNullOrWhiteSpace(awsAccountId))
        {
            ErrorMessage = "QuickSight dashboard is not configured. Set AwsAccountId and the dashboard ID in appsettings.";
            return Page();
        }

        try
        {
            EmbedUrl = new AMCOS.Logic.QuickSight(awsAccountId, awsRegionCode).EmbedDashboard(dashboardId);
        }
        catch (Exception ex)
        {
            ErrorMessage = $"Could not generate embed URL: {ex.Message}";
        }

        return Page();
    }
}
