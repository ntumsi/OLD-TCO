using System.Globalization;
using AMCOS.Data.ViewModels;
using AMCOS.Logic;
using AMCOS.Web.Core.Models;
using Microsoft.AspNetCore.Mvc;

namespace AMCOS.Web.Core.Controllers;

[ApiController]
[Route("api/lite")]
public class LiteApiController : ControllerBase
{
    private readonly IConfiguration _configuration;

    public LiteApiController(IConfiguration configuration)
    {
        _configuration = configuration;
    }

    [HttpGet("LogChoices")]
    public IActionResult LogChoicesGet([FromQuery] AmcosLiteRequest request)
    {
        LogChoicesInternal(request);
        return Ok(new { d = (object?)null });
    }

    [HttpPost("LogChoices")]
    public IActionResult LogChoicesPost([FromBody] AmcosLiteRequest request)
    {
        LogChoicesInternal(request);
        return Ok(new { d = (object?)null });
    }

    private void LogChoicesInternal(AmcosLiteRequest request)
    {
        var loggingMode = _configuration["AmcosLiteLogging"] ?? "None";
        if (!string.Equals(loggingMode, "Both", StringComparison.OrdinalIgnoreCase)
            && !string.Equals(loggingMode, "FilterValue", StringComparison.OrdinalIgnoreCase))
        {
            return;
        }

        var model = new AmcosLiteViewModel
        {
            UserId = request.UserId ?? string.Empty,
            PayPlan = request.PayPlan ?? string.Empty,
            CostSummaryName = request.CostSummaryName ?? string.Empty,
            CategoryGroupCode = request.CategoryGroupCode ?? string.Empty,
            CategorySubgroupCode = request.CategorySubgroupCode ?? string.Empty,
            CareerProgramNumber = request.CareerProgramNumber ?? string.Empty,
            LocationId = request.LocationId,
            LocationText = request.LocationText ?? string.Empty,
            ScienceTechnologyReinventionLaboratory = request.ScienceTechnologyReinventionLaboratory ?? string.Empty,
            DependentStatus = request.DependentStatus ?? string.Empty,
            NumberOfDependents = request.NumberOfDependents,
            OverheadPercent = TryParseSingle(request.OverheadPercent),
            InflationConversionType = request.InflationConversionType ?? string.Empty,
            InflationYear = request.InflationYear ?? string.Empty
        };

        try
        {
            new Lite().LogSelections("Filter", request.PageElement ?? string.Empty, model);
        }
        catch
        {
        }
    }

    private static float? TryParseSingle(string? value)
    {
        return float.TryParse(value, NumberStyles.Float, CultureInfo.InvariantCulture, out var parsedValue)
            ? parsedValue
            : null;
    }
}
