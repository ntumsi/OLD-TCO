using System.ComponentModel.DataAnnotations;
using System.Security.Claims;
using AMCOS.Data.Entities;
using AMCOS.Logic;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;

namespace AMCOS.Web.Core.Pages.App.Project;

[Authorize]
public class IndexModel : PageModel
{
    private readonly IConfiguration _configuration;

    public IndexModel(IConfiguration configuration)
    {
        _configuration = configuration;
    }

    public List<PMProject> Projects { get; private set; } = new();
    public string? LoadError { get; private set; }

    [BindProperty(SupportsGet = true)]
    public string? Sort { get; set; }

    [BindProperty(SupportsGet = true)]
    public string? Dir { get; set; }

    [TempData]
    public string? StatusMessage { get; set; }

    [BindProperty, Display(Name = "Project Name")]
    public string? NewProjectName { get; set; }

    [BindProperty, Display(Name = "Description")]
    public string? NewProjectDescription { get; set; }

    [BindProperty, Display(Name = "Start Year")]
    public int NewProjectYearStart { get; set; }

    [BindProperty, Display(Name = "Source Project")]
    public int? CopySourceProjectId { get; set; }

    [BindProperty, Display(Name = "Copied Project Name")]
    public string? CopyProjectName { get; set; }

    [BindProperty, Display(Name = "Copied Description")]
    public string? CopyProjectDescription { get; set; }

    public void OnGet()
    {
        NewProjectYearStart = GetDefaultStartYear();
        LoadProjects();
    }

    public IActionResult OnPostCreate()
    {
        if (string.IsNullOrWhiteSpace(NewProjectName))
        {
            StatusMessage = "Project name is required.";
            return RedirectToPage();
        }

        var currentUser = ResolveCurrentUser();
        if (currentUser is null)
        {
            StatusMessage = "Sign in is required before creating a project.";
            return RedirectToPage();
        }

        try
        {
            var project = new AMCOS.Logic.Project
            {
                UserId = currentUser.UserId,
                ProjectName = NewProjectName.Trim(),
                Description = NewProjectDescription ?? string.Empty,
                YearStart = NewProjectYearStart == 0 ? GetDefaultStartYear() : NewProjectYearStart
            };

            project.AddProject();
            StatusMessage = $"Created project '{project.ProjectName}'.";
        }
        catch (Exception ex)
        {
            StatusMessage = ex.Message;
        }

        return RedirectToPage();
    }

    public IActionResult OnPostCopy()
    {
        if (!CopySourceProjectId.HasValue || string.IsNullOrWhiteSpace(CopyProjectName))
        {
            StatusMessage = "Select a source project and provide a destination name.";
            return RedirectToPage();
        }

        try
        {
            new AMCOS.Logic.Project().Copy(CopySourceProjectId.Value, CopyProjectName.Trim(), CopyProjectDescription ?? string.Empty);
            StatusMessage = $"Copied project to '{CopyProjectName}'.";
        }
        catch (Exception ex)
        {
            StatusMessage = ex.Message;
        }

        return RedirectToPage();
    }

    public IActionResult OnPostDelete(int projectId)
    {
        try
        {
            new AMCOS.Logic.Project().DeleteProject(projectId);
            StatusMessage = "Project deleted.";
        }
        catch (Exception ex)
        {
            StatusMessage = ex.Message;
        }

        return RedirectToPage();
    }

    private void LoadProjects()
    {
        try
        {
            var currentUser = ResolveCurrentUser();
            if (currentUser is null)
            {
                LoadError = "No authenticated AMCOS user is available. Project data will remain empty until authentication is configured.";
                return;
            }

            Projects = new AMCOS.Logic.Project().GetAllProjectsForUserId(currentUser.UserId);
            Projects = SortProjects(Projects);
        }
        catch (Exception ex)
        {
            LoadError = ex.Message;
        }
    }

    // In-memory sort backing the clickable list headers (legacy default.aspx AllowSorting).
    private List<PMProject> SortProjects(List<PMProject> projects)
    {
        var desc = string.Equals(Dir, "desc", StringComparison.OrdinalIgnoreCase);
        Func<PMProject, object?> key = (Sort ?? "").ToLowerInvariant() switch
        {
            "description" => p => p.Description,
            "startyear" => p => p.YearStart,
            "duration" => p => p.YearDuration,
            "updated" => p => p.LastUpdate,
            "created" => p => p.CreateDate,
            "name" => p => p.ProjectName,
            _ => null!
        };
        if (key is null) return projects; // default: keep the source order
        var ordered = desc ? projects.OrderByDescending(key) : projects.OrderBy(key);
        return ordered.ToList();
    }

    // Returns the opposite direction for a header link (toggles asc/desc for the active column).
    public string NextDir(string column) =>
        string.Equals(Sort, column, StringComparison.OrdinalIgnoreCase) && !string.Equals(Dir, "desc", StringComparison.OrdinalIgnoreCase)
            ? "desc" : "asc";

    private AMCOSUser? ResolveCurrentUser()
    {
        var identity = User.Identity as ClaimsIdentity;
        if (identity?.IsAuthenticated != true)
        {
            return null;
        }

        return UserAdministration.GetCurrentUser(identity);
    }

    private int GetDefaultStartYear()
    {
        try
        {
            var amcosVersionId = int.TryParse(_configuration["AmcosVersionId"], out var parsedValue) ? parsedValue : 202501;
            return (int)SingleValue.Get("ALL", "ProjectManager_StartYear", amcosVersionId);
        }
        catch
        {
            return DateTime.UtcNow.Year;
        }
    }
}
