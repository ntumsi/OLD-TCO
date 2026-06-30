using System.Security.Claims;
using System.Text.Json;
using AMCOS.Data.DataTransferObjects;
using AMCOS.Logic;
using AMCOS.Logic.Helpers;
using AMCOS.Logic.ViewModels;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;

namespace AMCOS.Web.Core.Pages.App.CivilianPcs;

[Authorize]
[IgnoreAntiforgeryToken]
public class IndexModel : PageModel
{
    private static readonly JsonSerializerOptions JsonOpts = new() { PropertyNamingPolicy = null };

    public int AmcosVersionId { get; private set; }
    public List<(string Name, string SaveDate)> InitialProjects { get; private set; } = new();

    public void OnGet()
    {
        try { AmcosVersionId = PcsPropertyHelper.GetMaxReleaseVersion(); }
        catch { AmcosVersionId = 0; }

        try
        {
            var uid = UserId();
            if (uid != null)
            {
                InitialProjects = PcsPropertyHelper.GetProjects(uid, "projectSaveDate", "desc")
                    .Select(t => (t.Item1, t.Item2.ToString("g")))
                    .ToList();
            }
        }
        catch { /* non-critical: project list loads empty if DB unavailable */ }    }

    public IActionResult OnGetGetLocations(int amcosVersionId, string q)
    {
        var query = string.IsNullOrWhiteSpace(q) ? "A" : q;
        return new JsonResult(PcsPropertyHelper.GetCivPCSLocations(amcosVersionId, query), JsonOpts);
    }

    public IActionResult OnGetGetSpecificLocations(int amcosVersionId, int originationId, int destinationId)
    {
        var locations = new List<LocationDto>();
        if (originationId > 0)
        {
            var origin = PcsPropertyHelper.GetCivPCSLocationById(originationId, amcosVersionId);
            if (origin != null) locations.Add(origin);
        }
        if (destinationId > 0)
        {
            var dest = PcsPropertyHelper.GetCivPCSLocationById(destinationId, amcosVersionId);
            if (dest != null) locations.Add(dest);
        }
        return new JsonResult(locations, JsonOpts);
    }

    public IActionResult OnGetGetAllLocations(int amcosVersionId)
        => new JsonResult(PcsPropertyHelper.GetAllCivPCSLocations(amcosVersionId), JsonOpts);

    public IActionResult OnGetGetYearList(int amcosVersionId, string conversionType, string appropriation)
        => new JsonResult(
            PcsPropertyHelper.GetJicInflationRateYears(conversionType, appropriation, amcosVersionId),
            JsonOpts);

    public IActionResult OnPostCalculateAll(CivPcsJson json)
    {
        PcsPropertyHelper.ProcessJsonInput(json);
        return new JsonResult(json, JsonOpts);
    }

    public IActionResult OnPostSaveProject(CivPcsJson json)
    {
        var uid = UserId();
        if (uid == null) return new JsonResult(new List<object>());
        PcsPropertyHelper.SaveProject(PcsPropertyHelper.ProcessJsonInput(json).ConvertToPCSProject(), uid);
        return new JsonResult(
            PcsPropertyHelper.GetProjects(uid, json.ViewProjectsSortColumn, json.ViewProjectsSortOrder)
                .Select(t => new { Item1 = t.Item1, Item2 = t.Item2.ToString("g") })
                .ToList(),
            JsonOpts);
    }

    public IActionResult OnPostOpenProject(string projectName)
    {
        var uid = UserId();
        if (uid == null) return new JsonResult(new { });
        return new JsonResult(PcsPropertyHelper.OpenProject(projectName, uid), JsonOpts);
    }

    public IActionResult OnGetExport(string projectName)
    {
        var uid = UserId();
        if (uid == null) return NotFound();
        var json = PcsPropertyHelper.OpenProject(projectName, uid);
        if (json == null) return NotFound();

        // Reuse the shared, attribute-driven exporter so the spreadsheet matches the legacy report:
        // one worksheet per [ForExport] section, with per-component breakdowns and styling — not just
        // the grand totals the previous hand-rolled sheet produced.
        using var ms = new MemoryStream();
        CivPcsExportHelper.ExportToExcel(ms, json, "Civilian Permanent Change of Station");
        return File(ms.ToArray(),
            "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
            projectName + ".xlsx");
    }

    public IActionResult OnPostDeleteProject(string projectName, string sortColumn, string sortOrder)
    {
        var uid = UserId();
        if (uid == null) return new JsonResult(new List<object>());
        PcsPropertyHelper.SetProjectDeleted(projectName, uid);
        return new JsonResult(
            PcsPropertyHelper.GetProjects(uid, sortColumn, sortOrder)
                .Select(t => new { Item1 = t.Item1, Item2 = t.Item2.ToString("g") })
                .ToList(),
            JsonOpts);
    }

    public IActionResult OnPostSortProjects(string sortColumn, string sortOrder)
    {
        var uid = UserId();
        if (uid == null) return new JsonResult(new List<object>());
        return new JsonResult(
            PcsPropertyHelper.GetProjects(uid, sortColumn, sortOrder)
                .Select(t => new { Item1 = t.Item1, Item2 = t.Item2.ToString("g") })
                .ToList(),
            JsonOpts);
    }

    private string? UserId()
    {
        try
        {
            var identity = (ClaimsIdentity)User.Identity!;
            return UserAdministration.GetCurrentUser(identity)?.UserId;
        }
        catch { return null; }
    }
}
