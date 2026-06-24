using System.Security.Claims;
using System.Text.Json;
using Aspose.Cells;
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

    public IActionResult OnGetExport(string projectName, [FromServices] IWebHostEnvironment env)
    {
        var uid = UserId();
        if (uid == null) return NotFound();
        var json = PcsPropertyHelper.OpenProject(projectName, uid);
        if (json == null) return NotFound();

        var licensePath = Path.Combine(env.ContentRootPath, "Licenses", "Aspose.Cells.lic");
        if (System.IO.File.Exists(licensePath))
        {
            var lic = new License();
            lic.SetLicense(licensePath);
        }

        var workbook = new Workbook();
        var ws = workbook.Worksheets[0];
        ws.Name = "Civilian PCS";
        int row = 0;

        ws.Cells[row, 0].PutValue("Civilian Permanent Change of Station");
        ws.Cells[row, 0].GetStyle().Font.IsBold = true;
        row += 2;

        void AddRow(string label, decimal value)
        {
            ws.Cells[row, 0].PutValue(label);
            ws.Cells[row, 1].PutValue((double)value);
            row++;
        }

        AddRow("Origination ID", json.OriginationId);
        AddRow("Destination ID", json.DestinationId);
        AddRow("Distance (Miles)", json.CalculatedDistance);
        row++;
        AddRow("House Hunting Total", json.HouseHuntingTotal);
        AddRow("Transportation Subtotal", json.TransportationSubTotal);
        AddRow("TQSE Total", json.TQSETotal);
        AddRow("GH Transportation Total", json.GHTransportationTotal);
        AddRow("MEA Subtotal", json.MEASubtotal);
        AddRow("Real Estate/Lease Total", json.RealEstateLeaseTotal);
        AddRow("NTS Subtotal", json.NTSSubtotal);
        AddRow("RITA Subtotal", json.RITASubtotal);
        row++;
        ws.Cells[row, 0].PutValue("Grand Total");
        ws.Cells[row, 0].GetStyle().Font.IsBold = true;
        ws.Cells[row, 1].PutValue((double)json.GrandTotal);
        ws.Cells[row, 1].GetStyle().Font.IsBold = true;

        ws.AutoFitColumns();

        using var ms = new MemoryStream();
        workbook.Save(ms, SaveFormat.Xlsx);
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
