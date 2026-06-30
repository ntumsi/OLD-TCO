using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc.RazorPages;

namespace AMCOS.Web.Core.Pages;

[Authorize]
public class IndexModel : PageModel
{
    private readonly IWebHostEnvironment _environment;

    public IndexModel(IWebHostEnvironment environment)
    {
        _environment = environment;
    }

    /// <summary>Rotating background image for the home banner (legacy HomeController behaviour).</summary>
    public string BackgroundImageUrl { get; private set; } = string.Empty;

    public void OnGet()
    {
        // The home page is the post-login landing page. Do NOT redirect authenticated users away
        // (the previous redirect to AMCOS Lite is why the home page was never seen).
        BackgroundImageUrl = PickRandomBackground();
    }

    // Mirrors the legacy HomeController: choose a random background PNG from dist/img/backgrounds.
    private string PickRandomBackground()
    {
        try
        {
            var directory = Path.Combine(_environment.WebRootPath, "dist", "img", "backgrounds");
            if (Directory.Exists(directory))
            {
                var files = Directory.GetFiles(directory, "*.png", SearchOption.TopDirectoryOnly);
                if (files.Length > 0)
                {
                    var fileName = Path.GetFileName(files[Random.Shared.Next(files.Length)]);
                    return "/dist/img/backgrounds/" + Uri.EscapeDataString(fileName);
                }
            }
        }
        catch
        {
            // A missing backgrounds folder must not break the landing page.
        }
        return string.Empty;
    }
}