using System.Security.Claims;
using AMCOS.Data.Entities;
using AMCOS.Logic;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;
using Npgsql;

namespace AMCOS.Web.Core.Pages.App.Profile;

[Authorize]
public class IndexModel : PageModel
{
    private readonly IConfiguration _configuration;

    public IndexModel(IConfiguration configuration) => _configuration = configuration;

    // Read-only display
    public string? DisplayUserId { get; private set; }
    public string? FirstName { get; private set; }
    public string? LastName { get; private set; }
    public string? ArmyAccountType { get; private set; }

    // Editable fields
    [BindProperty] public string Email { get; set; } = string.Empty;
    [BindProperty] public string Macom { get; set; } = string.Empty;
    [BindProperty] public string OfficeName { get; set; } = string.Empty;
    [BindProperty] public string? CompanyName { get; set; }
    [BindProperty] public string? ComPhone { get; set; }
    [BindProperty] public string? InternationalNo { get; set; }
    [BindProperty] public string ArmyRank { get; set; } = string.Empty;
    [BindProperty] public string? ArmyRankOther { get; set; }
    [BindProperty] public string Prefix { get; set; } = string.Empty;

    public List<(string Value, string Text)> Organizations { get; private set; } = new();
    public string? LoadError { get; private set; }

    [TempData] public string? StatusMessage { get; set; }

    public static readonly string[] MilitaryRanks =
        "E1,E2,E3,E4,E5,E6,E7,E8,E9,O1,O2,O3,O4,O5,O6,O7,O8,O9,O10,W1,W2,W3,W4,W5,Other (Specify)"
        .Split(',');

    public static readonly string[] CivilianRanks =
        ("GS1,GS2,GS3,GS4,GS5,GS6,GS7,GS8,GS9,GS10,GS11,GS12,GS13,GS14,GS15," +
        "WG1,WG2,WG3,WG4,WG5,WG6,WG7,WG8,WG9,WG10,WG11,WG12,WG13,WG14,WG15," +
        "WL1,WL2,WL3,WL4,WL5,WL6,WL7,WL8,WL9,WL10,WL11,WL12,WL13,WL14,WL15," +
        "WS1,WS2,WS3,WS4,WS5,WS6,WS7,WS8,WS9,WS10,WS11,WS12,WS13,WS14,WS15,WS16,WS17,WS18,WS19," +
        "SES,Other (Specify)").Split(',');

    public void OnGet()
    {
        LoadOrganizations();
        try
        {
            var identity = (ClaimsIdentity)User.Identity!;
            var user = UserAdministration.GetCurrentUser(identity);
            if (user == null) { LoadError = "Could not load your profile."; return; }
            PopulateFromUser(user);
        }
        catch (Exception ex) { LoadError = ex.Message; }
    }

    public IActionResult OnPost()
    {
        if (string.IsNullOrWhiteSpace(ComPhone) && string.IsNullOrWhiteSpace(InternationalNo))
            ModelState.AddModelError(string.Empty, "At least one phone number is required.");

        LoadOrganizations();

        try
        {
            var identity = (ClaimsIdentity)User.Identity!;
            var user = UserAdministration.GetCurrentUser(identity);
            if (user == null) { LoadError = "Could not load your profile."; return Page(); }

            DisplayUserId = user.UserId;
            FirstName = user.FirstName;
            LastName = user.LastName;
            ArmyAccountType = user.ArmyAccountType;

            if (!ModelState.IsValid) return Page();

            var effectiveRank = ArmyRank == "Other (Specify)"
                ? (ArmyRankOther?.Trim() ?? string.Empty)
                : ArmyRank;

            user.Email = Email.Trim();
            user.Macom = Macom;
            user.OfficeName = string.IsNullOrWhiteSpace(OfficeName) ? null : OfficeName.Trim();
            user.CompanyName = effectiveRank.EndsWith("CTR", StringComparison.OrdinalIgnoreCase)
                ? (string.IsNullOrWhiteSpace(CompanyName) ? null : CompanyName.Trim())
                : null;
            user.ComPhone = string.IsNullOrWhiteSpace(ComPhone) ? null : ComPhone.Trim();
            user.InternationalNo = string.IsNullOrWhiteSpace(InternationalNo) ? null : InternationalNo.Trim();
            user.ArmyRank = effectiveRank;
            user.Prefix = Prefix;
            user.LastUpdate = DateTime.Now;

            UserAdministration.UpdateAmcosUser(user);
            StatusMessage = "Profile updated successfully.";
            return RedirectToPage();
        }
        catch (Exception ex) { LoadError = ex.Message; return Page(); }
    }

    private void PopulateFromUser(AMCOSUser user)
    {
        DisplayUserId = user.UserId;
        FirstName = user.FirstName;
        LastName = user.LastName;
        ArmyAccountType = user.ArmyAccountType;
        Email = user.Email ?? string.Empty;
        Macom = user.Macom ?? string.Empty;
        OfficeName = user.OfficeName ?? string.Empty;
        CompanyName = user.CompanyName;
        ComPhone = user.ComPhone;
        InternationalNo = user.InternationalNo;
        Prefix = user.Prefix ?? string.Empty;

        var ranks = (user.ArmyAccountType ?? string.Empty).Equals("MILITARY", StringComparison.OrdinalIgnoreCase)
            ? MilitaryRanks : CivilianRanks;
        var rank = user.ArmyRank ?? string.Empty;
        if (ranks.Contains(rank) && rank != "Other (Specify)")
            ArmyRank = rank;
        else
        {
            ArmyRank = "Other (Specify)";
            ArmyRankOther = rank;
        }
    }

    private void LoadOrganizations()
    {
        try
        {
            using var conn = OpenConnection();
            using var cmd = new NpgsqlCommand(
                "SELECT organizationname, organizationdescription FROM lookup.organization ORDER BY organizationname",
                conn);
            using var reader = cmd.ExecuteReader();
            while (reader.Read())
            {
                var name = reader.GetString(0);
                var desc = reader.IsDBNull(1) ? name : $"{name} : {reader.GetString(1)}";
                Organizations.Add((name, desc));
            }
        }
        catch { /* non-critical */ }
    }

    private NpgsqlConnection OpenConnection()
    {
        var connStr = _configuration.GetConnectionString("AmcosPostgres")
            ?? _configuration.GetConnectionString("AmcosEF")
            ?? string.Empty;
        var conn = new NpgsqlConnection(connStr);
        conn.Open();
        return conn;
    }
}
