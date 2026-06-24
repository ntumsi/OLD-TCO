using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;

namespace AMCOS.Web.Core.Pages.App.Xwalk;

[Authorize]
public class IndexModel : PageModel
{
    private readonly IConfiguration _config;

    public string? EmbedUrl { get; private set; }
    public string? ErrorMessage { get; private set; }

    public IndexModel(IConfiguration config) => _config = config;

    public void OnGet()
    {
        var dashboardId = _config["QuickSight:XwalkDashboardId"];
        var awsAccountId = _config["AwsAccountId"];
        var awsRegionCode = _config["AwsRegionCode"] ?? "us-gov-west-1";

        if (string.IsNullOrWhiteSpace(dashboardId) || string.IsNullOrWhiteSpace(awsAccountId))
        {
            ErrorMessage = "The Xwalk dashboard is not yet configured. Set AwsAccountId and QuickSight:XwalkDashboardId in appsettings.";
            return;
        }

        try
        {
            EmbedUrl = new AMCOS.Logic.QuickSight(awsAccountId, awsRegionCode).EmbedDashboard(dashboardId);
        }
        catch (Exception ex)
        {
            ErrorMessage = $"Could not load Xwalk dashboard: {ex.Message}";
        }
    }
}
