using System.Xml.Linq;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc.RazorPages;

namespace AMCOS.Web.Core.Pages;

// Port of the legacy Public/note.aspx RSS news viewer. Reads wwwroot/Public/rss.xml and shows
// either a single item (?noteId=, matched against the item's <guid>) or all items.
[AllowAnonymous]
public class NoteModel : PageModel
{
    private readonly IWebHostEnvironment _environment;

    public NoteModel(IWebHostEnvironment environment) => _environment = environment;

    public record NewsItem(string? Title, string? Description, string? Category, string? Content, string? PubDate, string? Link);

    public List<NewsItem> Items { get; private set; } = new();
    public string? Notice { get; private set; }

    public void OnGet(int? noteId)
    {
        // The /Public assets (incl. rss.xml) are served from the legacy AMCOS.Web/Public folder
        // (Program.cs maps ../AMCOS.Web/Public -> /Public). Read the feed from there, matching where
        // the RSS <link rel="alternate"> points; fall back to the Core wwwroot/Public copy if present.
        var legacyPublic = Path.GetFullPath(Path.Combine(_environment.ContentRootPath, "..", "AMCOS.Web", "Public", "rss.xml"));
        var wwwrootPublic = Path.Combine(_environment.WebRootPath ?? string.Empty, "Public", "rss.xml");
        var path = System.IO.File.Exists(legacyPublic) ? legacyPublic : wwwrootPublic;
        if (!System.IO.File.Exists(path))
        {
            Notice = "No news feed is currently available.";
            return;
        }

        try
        {
            var doc = XDocument.Load(path);
            var items = doc.Descendants("item");
            if (noteId.HasValue)
            {
                var key = noteId.Value.ToString();
                items = items.Where(i => (i.Element("guid")?.Value ?? string.Empty).Contains(key));
            }

            Items = items.Select(i => new NewsItem(
                Title: i.Element("title")?.Value,
                Description: i.Element("description")?.Value,
                Category: i.Element("category")?.Value,
                Content: i.Element("content")?.Value,
                PubDate: i.Element("pubDate")?.Value,
                Link: i.Element("link")?.Value)).ToList();

            if (Items.Count == 0)
                Notice = noteId.HasValue ? "The requested news item was not found." : "No news items are available.";
        }
        catch (Exception ex)
        {
            Notice = $"Could not read the news feed: {ex.Message}";
        }
    }
}