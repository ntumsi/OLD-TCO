using AMCOS.Data.ViewModels;
using AMCOS.Logic;
using AMCOS.Web.Core.Models;
using Microsoft.AspNetCore.Mvc;

namespace AMCOS.Web.Core.Controllers;

[ApiController]
[Route("api/project")]
public class ProjectApiController : ControllerBase
{
    private readonly IConfiguration _configuration;

    public ProjectApiController(IConfiguration configuration)
    {
        _configuration = configuration;
    }

    [HttpGet("LogAddUnit")]
    public IActionResult LogAddUnitGet([FromQuery] ProjectAddUnitRequest request)
    {
        LogAddUnitInternal(request);
        return Ok(new { d = (object?)null });
    }

    [HttpPost("LogAddUnit")]
    public IActionResult LogAddUnitPost([FromBody] ProjectAddUnitRequest request)
    {
        LogAddUnitInternal(request);
        return Ok(new { d = (object?)null });
    }

    private void LogAddUnitInternal(ProjectAddUnitRequest request)
    {
        var loggingMode = _configuration["AmcosLiteLogging"] ?? "None";
        if (!string.Equals(loggingMode, "Both", StringComparison.OrdinalIgnoreCase)
            && !string.Equals(loggingMode, "FilterValue", StringComparison.OrdinalIgnoreCase))
        {
            return;
        }

        var model = new ProjectAddUnitViewModel
        {
            UserId = request.UserId ?? string.Empty,
            CategoryId = request.CategoryId ?? string.Empty,
            UIC = request.Uic ?? string.Empty,
            ExcludedPayPlans = request.ExcludedPayPlans ?? string.Empty,
            DataAction = request.DataAction ?? request.UnitDataAction ?? string.Empty,
            NewSubprojectName = request.NewSubprojectName ?? string.Empty,
            UnitLocation = request.UnitLocation ?? string.Empty,
            MtoeProjectInventoryYear = request.MtoeProjectInventoryYear ?? string.Empty,
            ProjectExtendsSacsYears = request.ProjectExtendsSacsYears ?? string.Empty,
            ContractorOverheadPercent = request.ContractorOverheadPercent ?? request.UnitContractorOverheadPercent ?? string.Empty
        };

        try
        {
            new Project().LogAddUnit(model);
        }
        catch
        {
        }
    }
}
