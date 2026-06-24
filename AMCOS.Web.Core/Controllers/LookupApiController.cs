using AMCOS.Logic;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace AMCOS.Web.Core.Controllers;

[Authorize]
[ApiController]
[Route("api")]
public class LookupApiController : ControllerBase
{
    // GET /api/payplans
    [HttpGet("payplans")]
    public IActionResult GetPayPlans()
    {
        try { return Ok(new Lite().GetOptionListPayPlan()); }
        catch (Exception ex) { return StatusCode(500, ex.Message); }
    }

    // GET /api/categories/{payplan}
    [HttpGet("categories/{payplan}")]
    public IActionResult GetCategories(string payplan)
    {
        try { return Ok(new Lite().GetOptionListCategory(payplan)); }
        catch (Exception ex) { return StatusCode(500, ex.Message); }
    }

    // GET /api/grades/{payPlan}/{categoryGroupCode}/{categorySubgroupCode}/{careerProgramNumber}/{locationId}
    [HttpGet("grades/{payPlan}/{categoryGroupCode}/{categorySubgroupCode}/{careerProgramNumber}/{locationId:int}")]
    public IActionResult GetGrades(string payPlan, string categoryGroupCode, string categorySubgroupCode,
        string careerProgramNumber, int locationId, [FromQuery] int amcosVersionId = 0)
    {
        try
        {
            return Ok(new Lite().GetOptionListGradeLevel(payPlan, categoryGroupCode, categorySubgroupCode,
                careerProgramNumber, locationId, amcosVersionId));
        }
        catch (Exception ex) { return StatusCode(500, ex.Message); }
    }

    // GET /api/locations/{payplan}/{categoryGroupCode}/{categorySubgroupCode}/{careerProgramNumber}
    [HttpGet("locations/{payplan}/{categoryGroupCode}/{categorySubgroupCode}/{careerProgramNumber}")]
    public IActionResult GetLocations(string payplan, string categoryGroupCode, string categorySubgroupCode,
        string careerProgramNumber)
    {
        try
        {
            return Ok(new Lite().GetOptionListLocation(payplan, categoryGroupCode, categorySubgroupCode,
                careerProgramNumber));
        }
        catch (Exception ex) { return StatusCode(500, ex.Message); }
    }

    // GET /api/locations/installations
    [HttpGet("locations/installations")]
    public IActionResult GetMilitaryInstallations()
    {
        try { return Ok(new Lite().GetMilitaryInstallations()); }
        catch (Exception ex) { return StatusCode(500, ex.Message); }
    }

    // GET /api/strls/{payplan}/{categoryGroupCode}/{categorySubgroupCode}/{careerProgramNumber}/{locationId}
    [HttpGet("strls/{payplan}/{categoryGroupCode}/{categorySubgroupCode}/{careerProgramNumber}/{locationId:int}")]
    public IActionResult GetStrls(string payplan, string categoryGroupCode, string categorySubgroupCode,
        string careerProgramNumber, int locationId)
    {
        try
        {
            return Ok(new Lite().GetOptionListScienceTechnologyReinventionLaboratory(payplan,
                categoryGroupCode, categorySubgroupCode, careerProgramNumber, locationId));
        }
        catch (Exception ex) { return StatusCode(500, ex.Message); }
    }

    // GET /api/units
    [HttpGet("units")]
    public IActionResult GetUnits()
    {
        try { return Ok(OptionList.GetUnitList()); }
        catch (Exception ex) { return StatusCode(500, ex.Message); }
    }

    // GET /api/units/{uic}/location
    [HttpGet("units/{uic}/location")]
    public IActionResult GetUnitLocations(string uic)
    {
        try { return Ok(new Project().GetUnitLocations(uic)); }
        catch (Exception ex) { return StatusCode(500, ex.Message); }
    }

    // GET /api/units/{uic}/{projectStartYear}/personnel
    [HttpGet("units/{uic}/{projectStartYear:int}/personnel")]
    public IActionResult GetUnitPersonnel(string uic, int projectStartYear)
    {
        try { return Ok(new Project().GetUnitPersonnelAndLocation(uic, projectStartYear)); }
        catch (Exception ex) { return StatusCode(500, ex.Message); }
    }

    // GET /api/units/{uic}/mtoeyears
    [HttpGet("units/{uic}/mtoeyears")]
    public IActionResult GetMtoeUnitYears(string uic)
    {
        try { return Ok(new Project().GetMtoeUnitYears(uic)); }
        catch (Exception ex) { return StatusCode(500, ex.Message); }
    }
}
