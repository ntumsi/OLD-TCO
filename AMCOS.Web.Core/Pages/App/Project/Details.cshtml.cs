using AMCOS.Data;
using AMCOS.Data.DataTransferObjects;
using AMCOS.Data.Entities;
using AMCOS.Logic;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;
using Microsoft.EntityFrameworkCore;

namespace AMCOS.Web.Core.Pages.App.Project;

[Authorize]
public class DetailsModel : PageModel
{
    private readonly IConfiguration _configuration;

    public DetailsModel(IConfiguration configuration)
    {
        _configuration = configuration;
    }

    // ── Page-state properties ────────────────────────────────────────────────

    [BindProperty(SupportsGet = true)]
    public int ProjectId { get; set; }

    public PMProject? CurrentProject { get; private set; }
    public List<PMCategory> Categories { get; private set; } = new();
    public string? LoadError { get; private set; }
    public int MinimumStartYear { get; private set; }
    public int MaximumStartYear { get; private set; }

    [TempData]
    public string? StatusMessage { get; set; }

    // ── Properties-tab form bindings ─────────────────────────────────────────

    [BindProperty]
    public string EditProjectName { get; set; } = string.Empty;

    [BindProperty]
    public string EditProjectDescription { get; set; } = string.Empty;

    [BindProperty]
    public int EditYearStart { get; set; }

    [BindProperty]
    public int EditYearDuration { get; set; }

    // ── OnGet ────────────────────────────────────────────────────────────────

    public void OnGet()
    {
        LoadPageData();
    }

    // ── POST: Update project properties ─────────────────────────────────────

    public IActionResult OnPostUpdateProperties()
    {
        try
        {
            var proj = new AMCOS.Logic.Project();
            var existing = proj.GetProject(ProjectId);

            if (existing is null)
            {
                StatusMessage = "Project not found.";
                return RedirectToPage(new { projectId = ProjectId });
            }

            var newName = string.IsNullOrWhiteSpace(EditProjectName)
                ? existing.ProjectName
                : EditProjectName.Trim();

            if (newName != existing.ProjectName)
                proj.UpdateCategoryName(ProjectId, newName, existing.ProjectName);

            proj.UpdateProjectProperties(
                newName,
                EditProjectDescription ?? existing.Description ?? string.Empty,
                EditYearStart > 0 ? EditYearStart : existing.YearStart,
                EditYearDuration is >= 1 and <= 30 ? EditYearDuration : existing.YearDuration,
                ProjectId);

            StatusMessage = "Project properties updated.";
        }
        catch (Exception ex)
        {
            StatusMessage = ex.Message;
        }

        return RedirectToPage(new { projectId = ProjectId });
    }

    // ── GET handlers (JSON) ───────────────────────────────────────────────────

    /// <summary>Returns all categories (sub-projects) for this project as JSON.</summary>
    public JsonResult OnGetCategories()
    {
        try
        {
            var categories = new ProjectRequirement().GetRequirements(ProjectId)
                .Select(c => new { c.CategoryId, c.CategoryName })
                .ToList();
            return new JsonResult(categories);
        }
        catch (Exception ex)
        {
            Response.StatusCode = 500;
            return new JsonResult(new { error = ex.Message });
        }
    }

    /// <summary>Returns skills + per-year inventory for a category as JSON.</summary>
    public JsonResult OnGetSkills([FromQuery] int categoryId)
    {
        try
        {
            var pr = new ProjectRequirement();
            var skills = pr.GetRequirementsAndInventory(categoryId);

            var result = skills.Select(s => new
            {
                s.SkillId,
                s.CategoryId,
                s.Uic,
                s.PayPlan,
                s.CategoryGroupCode,
                s.CategorySubgroupCode,
                s.CareerProgramNumber,
                s.Location,
                s.STRL,
                s.Grade,
                s.DependentStatus,
                s.NumberOfDependents,
                s.ActiveDutyDays,
                s.OverheadPercent,
                Inventory = pr.GetCategorySkillInventory(s.SkillId)
                              .Select(i => new { i.Year, i.Amount })
                              .ToArray()
            }).ToList();

            return new JsonResult(result);
        }
        catch (Exception ex)
        {
            Response.StatusCode = 500;
            return new JsonResult(new { error = ex.Message });
        }
    }

    /// <summary>Returns unit personnel + location data for a UIC as JSON.</summary>
    public JsonResult OnGetUnitPersonnel([FromQuery] string uic, [FromQuery] int projectStartYear = 0)
    {
        try
        {
            if (string.IsNullOrWhiteSpace(uic))
            {
                Response.StatusCode = 400;
                return new JsonResult(new { error = "UIC is required." });
            }

            if (projectStartYear <= 0)
            {
                var proj = new AMCOS.Logic.Project().GetProject(ProjectId);
                projectStartYear = proj?.YearStart ?? DateTime.UtcNow.Year;
            }

            var personnel = new AMCOS.Logic.Project()
                .GetUnitPersonnelAndLocation(uic.Trim().ToUpper(), projectStartYear);

            return new JsonResult(personnel);
        }
        catch (Exception ex)
        {
            Response.StatusCode = 500;
            return new JsonResult(new { error = ex.Message });
        }
    }

    /// <summary>Returns available MTOE inventory years for a UIC as JSON.</summary>
    public JsonResult OnGetUnitYears([FromQuery] string uic)
    {
        try
        {
            if (string.IsNullOrWhiteSpace(uic))
            {
                Response.StatusCode = 400;
                return new JsonResult(new { error = "UIC is required." });
            }

            var years = new AMCOS.Logic.Project()
                .GetMtoeUnitYears(uic.Trim().ToUpper());

            return new JsonResult(years);
        }
        catch (Exception ex)
        {
            Response.StatusCode = 500;
            return new JsonResult(new { error = ex.Message });
        }
    }

    /// <summary>Returns unique locations for a UIC as JSON.</summary>
    public JsonResult OnGetUnitLocations([FromQuery] string uic)
    {
        try
        {
            if (string.IsNullOrWhiteSpace(uic))
            {
                Response.StatusCode = 400;
                return new JsonResult(new { error = "UIC is required." });
            }

            var locations = new AMCOS.Logic.Project()
                .GetUnitLocations(uic.Trim().ToUpper());

            return new JsonResult(locations);
        }
        catch (Exception ex)
        {
            Response.StatusCode = 500;
            return new JsonResult(new { error = ex.Message });
        }
    }

    /// <summary>Returns the PayPlan/Category combinations for the Output tab as JSON.</summary>
    public JsonResult OnGetOutputs()
    {
        try
        {
            var outputs = new AMCOS.Logic.Project().GetProjectOutputs(ProjectId);
            return new JsonResult(outputs);
        }
        catch (Exception ex)
        {
            Response.StatusCode = 500;
            return new JsonResult(new { error = ex.Message });
        }
    }

    // ── POST handlers (JSON) ──────────────────────────────────────────────────

    /// <summary>Adds a unit to the project (Replace, Append, or as new Subproject).</summary>
    public JsonResult OnPostAddUnit([FromBody] AddUnitRequest req)
    {
        try
        {
            if (string.IsNullOrWhiteSpace(req.Uic))
                return new JsonResult(new { success = false, message = "UIC is required." });

            var amcosVersionId = GetAmcosVersionId();
            var project = new AMCOS.Logic.Project();

            switch (req.Operation)
            {
                case "Subproject":
                    if (string.IsNullOrWhiteSpace(req.NewSubprojectName))
                        return new JsonResult(new { success = false, message = "Sub-project name is required." });

                    var subId = project.CreateProjectCategory(ProjectId, req.NewSubprojectName.Trim());
                    if (subId != 0)
                        project.AddUnit(
                            subId,
                            req.Uic.Trim().ToUpper(),
                            req.ExcludedPayPlans ?? string.Empty,
                            req.UnitLocation ?? "Unchanged",
                            req.MtoeInventoryYear ?? string.Empty,
                            req.ProjectExtendsSacsYears ?? "Last MTOE",
                            req.ContractorOverheadPercent,
                            amcosVersionId);
                    break;

                case "Replace":
                    project.ReplaceProject(
                        ProjectId,
                        req.Uic.Trim().ToUpper(),
                        req.ExcludedPayPlans ?? string.Empty,
                        req.UnitLocation ?? "Unchanged",
                        req.MtoeInventoryYear ?? string.Empty,
                        req.ProjectExtendsSacsYears ?? "Last MTOE",
                        req.ContractorOverheadPercent,
                        amcosVersionId);
                    break;

                default: // Append
                    project.AddUnit(
                        req.CategoryId,
                        req.Uic.Trim().ToUpper(),
                        req.ExcludedPayPlans ?? string.Empty,
                        req.UnitLocation ?? "Unchanged",
                        req.MtoeInventoryYear ?? string.Empty,
                        req.ProjectExtendsSacsYears ?? "Last MTOE",
                        req.ContractorOverheadPercent,
                        amcosVersionId);
                    break;
            }

            return new JsonResult(new { success = true });
        }
        catch (Exception ex)
        {
            Response.StatusCode = 500;
            return new JsonResult(new { error = ex.Message });
        }
    }

    /// <summary>Inserts a new skill (PMCategorySkill) with per-year inventory.</summary>
    public JsonResult OnPostAddRequirement([FromBody] AddRequirementRequest req)
    {
        try
        {
            if (req.Inventory is null || req.Inventory.Length == 0 || req.Inventory.All(v => v == 0))
                return new JsonResult(new { success = false, message = "The sum of inventory for all years must be greater than zero." });

            var pr = new ProjectRequirement
            {
                CategoryId = req.CategoryId,
                PayPlan = req.PayPlan,
                CategoryGroupCode = req.CategoryGroupCode,
                CategorySubgroupCode = req.CategorySubgroupCode,
                CareerProgramNumber = req.CareerProgramNumber,
                LocationId = req.LocationId,
                LocationText = req.LocationText,
                STRL = req.STRL,
                GradeLevel = (byte)Math.Max(0, Math.Min(255, req.GradeLevel)),
                DependentStatus = req.DependentStatus,
                NumberOfDependents = req.NumberOfDependents,
                ActiveDutyDays = (short)Math.Max(0, Math.Min(365, req.ActiveDutyDays)),
                OverheadPercent = req.OverheadPercent,
                Inventory = req.Inventory
            };

            var skillId = pr.CreatePMCategorySkill();

            if (skillId == 0)
                return new JsonResult(new
                {
                    success = false,
                    message = "This record is already in your project. Please delete the record before adding another or adjust the inventory in the matrix above."
                });

            return new JsonResult(new { success = true, skillId });
        }
        catch (Exception ex)
        {
            Response.StatusCode = 500;
            return new JsonResult(new { error = ex.Message });
        }
    }

    /// <summary>Replaces all inventory rows for a single skill with the supplied values.</summary>
    public JsonResult OnPostUpdateInventory([FromBody] UpdateInventoryRequest req)
    {
        try
        {
            var pr = new ProjectRequirement();
            pr.DeletePMCategorySkillInventoryAll(req.SkillId);

            for (var i = 0; i < req.Inventory.Length; i++)
            {
                if (req.Inventory[i] > 0)
                    pr.CreatePMCategorySkillInventory(req.SkillId, i, req.Inventory[i]);
            }

            return new JsonResult(new { success = true });
        }
        catch (Exception ex)
        {
            Response.StatusCode = 500;
            return new JsonResult(new { error = ex.Message });
        }
    }

    /// <summary>Updates inventory for every skill row in a category at once (bulk save).</summary>
    public JsonResult OnPostBulkUpdateInventory([FromBody] BulkUpdateInventoryRequest req)
    {
        try
        {
            var pr = new ProjectRequirement();
            foreach (var row in req.Rows)
            {
                pr.DeletePMCategorySkillInventoryAll(row.SkillId);
                for (var i = 0; i < row.Inventory.Length; i++)
                {
                    if (row.Inventory[i] > 0)
                        pr.CreatePMCategorySkillInventory(row.SkillId, i, row.Inventory[i]);
                }
            }

            return new JsonResult(new { success = true });
        }
        catch (Exception ex)
        {
            Response.StatusCode = 500;
            return new JsonResult(new { error = ex.Message });
        }
    }

    /// <summary>Deletes a PMCategorySkill row and its inventory.</summary>
    public JsonResult OnPostDeleteSkill([FromBody] DeleteSkillRequest req)
    {
        try
        {
            new ProjectRequirement().DeletePMCategorySkill(req.SkillId);
            return new JsonResult(new { success = true });
        }
        catch (Exception ex)
        {
            Response.StatusCode = 500;
            return new JsonResult(new { error = ex.Message });
        }
    }

    /// <summary>Creates a new sub-project (PMCategory) under this project.</summary>
    public JsonResult OnPostAddSubproject([FromBody] NameRequest req)
    {
        try
        {
            if (string.IsNullOrWhiteSpace(req.Name))
                return new JsonResult(new { success = false, message = "Sub-project name is required." });

            var categoryId = new AMCOS.Logic.Project().CreateProjectCategory(ProjectId, req.Name.Trim());

            if (categoryId == 0)
                return new JsonResult(new { success = false, message = "A category with that name already exists." });

            return new JsonResult(new { success = true, categoryId, name = req.Name.Trim() });
        }
        catch (Exception ex)
        {
            Response.StatusCode = 500;
            return new JsonResult(new { error = ex.Message });
        }
    }

    /// <summary>Deletes a sub-project and all its skills/inventory/report rows.</summary>
    public JsonResult OnPostDeleteSubproject([FromBody] CategoryIdRequest req)
    {
        try
        {
            new AMCOS.Logic.Project().DeleteSubProject(req.CategoryId);
            return new JsonResult(new { success = true });
        }
        catch (Exception ex)
        {
            Response.StatusCode = 500;
            return new JsonResult(new { error = ex.Message });
        }
    }

    /// <summary>Renames an existing sub-project category.</summary>
    public JsonResult OnPostRenameSubproject([FromBody] RenameRequest req)
    {
        try
        {
            if (string.IsNullOrWhiteSpace(req.NewName))
                return new JsonResult(new { success = false, message = "New name is required." });

            var proj = new AMCOS.Logic.Project();

            if (proj.SubprojectNameExists(ProjectId, req.NewName.Trim()))
                return new JsonResult(new { success = false, message = "A category with that name already exists." });

            proj.UpdateCategoryName(ProjectId, req.NewName.Trim(), req.OldName);
            return new JsonResult(new { success = true });
        }
        catch (Exception ex)
        {
            Response.StatusCode = 500;
            return new JsonResult(new { error = ex.Message });
        }
    }

    /// <summary>Copies all skill rows from one category into another (stored-proc).</summary>
    public JsonResult OnPostCopyCategory([FromBody] CopyCategoryRequest req)
    {
        try
        {
            using var context = new ApplicationDbContext();

            // Guard against duplicates — uses the same DB function as the legacy page
            int canCopy;
            using (var conn = new Npgsql.NpgsqlConnection(
                       AppConfiguration.GetConnectionString()))
            {
                conn.Open();
                using var cmd = new Npgsql.NpgsqlCommand(
                    "SELECT web.\"ProjectCategoryCount\"(@ProjectId, @FromCategoryId, @ToCategoryId)",
                    conn);
                cmd.Parameters.AddWithValue("@ProjectId", ProjectId);
                cmd.Parameters.AddWithValue("@FromCategoryId", req.FromCategoryId);
                cmd.Parameters.AddWithValue("@ToCategoryId", req.ToCategoryId);
                canCopy = Convert.ToInt32(cmd.ExecuteScalar());
            }

            if (canCopy == 0)
                return new JsonResult(new
                {
                    success = false,
                    message = "Your copy attempt could not be executed because it would duplicate data. " +
                              "If you need to change inventory values please do so using the inventory table above."
                });

            context.Database.ExecuteSqlRaw(
                "CALL web.pmcopyprojectcategory(@p0, @p1)",
                req.FromCategoryId, req.ToCategoryId);

            return new JsonResult(new { success = true });
        }
        catch (Exception ex)
        {
            Response.StatusCode = 500;
            return new JsonResult(new { error = ex.Message });
        }
    }

    /// <summary>
    /// Saves report output selections: clears old PMReport rows for the project,
    /// then inserts the checked category/pay-plan combinations.
    /// Returns { success, reportUrl } so JS can navigate to the report.
    /// </summary>
    public JsonResult OnPostBuildReport([FromBody] BuildReportRequest req)
    {
        try
        {
            if (req.OutputItems is null || req.OutputItems.Length == 0)
                return new JsonResult(new { success = false, message = "Please select at least one Pay Plan / Sub-Project Name combination." });

            var project = new AMCOS.Logic.Project();
            project.DeleteReportByProject(ProjectId);

            foreach (var item in req.OutputItems)
                project.InsertReport(item.CategoryId, item.PayPlan);

            return new JsonResult(new
            {
                success = true,
                reportUrl = $"/App/Project/Report?projectId={ProjectId}"
            });
        }
        catch (Exception ex)
        {
            Response.StatusCode = 500;
            return new JsonResult(new { error = ex.Message });
        }
    }

    // ── Private helpers ───────────────────────────────────────────────────────

    private void LoadPageData()
    {
        try
        {
            var amcosVersionId = GetAmcosVersionId();

            try
            {
                MinimumStartYear = (int)SingleValue.Get("ALL", "ProjectManager_StartYear", amcosVersionId);
            }
            catch
            {
                MinimumStartYear = DateTime.UtcNow.Year;
            }
            MaximumStartYear = MinimumStartYear + 29;

            CurrentProject = new AMCOS.Logic.Project().GetProject(ProjectId);

            if (CurrentProject is null)
            {
                LoadError = $"Project {ProjectId} was not found.";
                return;
            }

            EditProjectName = CurrentProject.ProjectName;
            EditProjectDescription = CurrentProject.Description ?? string.Empty;
            EditYearStart = CurrentProject.YearStart;
            EditYearDuration = CurrentProject.YearDuration;

            Categories = new ProjectRequirement()
                .GetRequirements(ProjectId)
                .ToList();
        }
        catch (Exception ex)
        {
            LoadError = ex.Message;
        }
    }

    private int GetAmcosVersionId()
        => int.TryParse(_configuration["AmcosVersionId"], out var v) ? v : 202501;
}

// ── Request / Response DTOs used only by this page ───────────────────────────

/// <summary>Body for OnPostAddUnit.</summary>
public sealed record AddUnitRequest(
    string Uic,
    string Operation,
    string? NewSubprojectName,
    int CategoryId,
    string? ExcludedPayPlans,
    string? UnitLocation,
    string? MtoeInventoryYear,
    string? ProjectExtendsSacsYears,
    decimal ContractorOverheadPercent);

/// <summary>Body for OnPostAddRequirement.</summary>
public sealed record AddRequirementRequest(
    int CategoryId,
    string PayPlan,
    string CategoryGroupCode,
    string CategorySubgroupCode,
    string CareerProgramNumber,
    int LocationId,
    string LocationText,
    string STRL,
    int GradeLevel,
    string DependentStatus,
    int NumberOfDependents,
    int ActiveDutyDays,
    double OverheadPercent,
    int[] Inventory);

/// <summary>Body for OnPostUpdateInventory (single skill).</summary>
public sealed record UpdateInventoryRequest(int SkillId, int[] Inventory);

/// <summary>One row in OnPostBulkUpdateInventory.</summary>
public sealed record InventoryRow(int SkillId, int[] Inventory);

/// <summary>Body for OnPostBulkUpdateInventory (all rows at once).</summary>
public sealed record BulkUpdateInventoryRequest(InventoryRow[] Rows);

/// <summary>Body for OnPostDeleteSkill.</summary>
public sealed record DeleteSkillRequest(int SkillId);

/// <summary>Generic body carrying a single name string.</summary>
public sealed record NameRequest(string Name);

/// <summary>Generic body carrying a single category id.</summary>
public sealed record CategoryIdRequest(int CategoryId);

/// <summary>Body for OnPostRenameSubproject.</summary>
public sealed record RenameRequest(string OldName, string NewName);

/// <summary>Body for OnPostCopyCategory.</summary>
public sealed record CopyCategoryRequest(int FromCategoryId, int ToCategoryId);

/// <summary>One checked row in the Output tab.</summary>
public sealed record BuildReportOutputItem(int CategoryId, string PayPlan);

/// <summary>Body for OnPostBuildReport.</summary>
public sealed record BuildReportRequest(BuildReportOutputItem[] OutputItems);
