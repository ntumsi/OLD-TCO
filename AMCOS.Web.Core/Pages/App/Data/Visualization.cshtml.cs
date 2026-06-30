using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;

namespace AMCOS.Web.Core.Pages.App.Data;

// User-facing QuickSight data visualizations (legacy "Visualization/*" routes:
// Inventory, Pay Schedule, GS Locality Rates by ZIP). Distinct from the admin
// dashboards (Pages/Admin/Dashboard) which are role-restricted.
[Authorize]
public class VisualizationModel : PageModel
{
    private readonly IConfiguration _config;

    public string DashboardTitle { get; private set; } = string.Empty;
    public string? EmbedUrl { get; private set; }
    public string? ErrorMessage { get; private set; }

    private static readonly Dictionary<string, (string ConfigKey, string Title)> Dashboards = new(StringComparer.OrdinalIgnoreCase)
    {
        ["inventory"]      = ("QuickSight:VisualizationDashboardId", "Inventory"),
        ["pay-schedule"]   = ("QuickSight:PayScheduleDashboardId",   "Pay Schedule"),
        ["locality-rates"] = ("QuickSight:LocalityRateDashboardId",  "GS Locality Rates by ZIP Code"),
    };

    public VisualizationModel(IConfiguration config) => _config = config;

    public IActionResult OnGet(string slug)
    {
        if (string.IsNullOrWhiteSpace(slug) || !Dashboards.TryGetValue(slug, out var info))
            return NotFound();

        DashboardTitle = info.Title;

        var dashboardId = _config[info.ConfigKey];
        var awsAccountId = _config["AwsAccountId"];
        var awsRegionCode = _config["AwsRegionCode"] ?? "us-gov-west-1";

        if (string.IsNullOrWhiteSpace(dashboardId) || string.IsNullOrWhiteSpace(awsAccountId))
        {
            ErrorMessage = $"The {info.Title} visualization is not yet configured. Set AwsAccountId and {info.ConfigKey} in appsettings.";
            return Page();
        }

        try
        {
            EmbedUrl = new AMCOS.Logic.QuickSight(awsAccountId, awsRegionCode).EmbedDashboard(dashboardId);
        }
        catch (Exception ex)
        {
            ErrorMessage = $"Could not load the {info.Title} visualization: {ex.Message}";
        }

        return Page();
    }
}