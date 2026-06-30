using System.Security.Claims;
using System.Text;
using Aspose.Cells;
using AMCOS.Data.Entities;
using AMCOS.Logic;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;
using Npgsql;

namespace AMCOS.Web.Core.Pages.Admin;

[Authorize(Roles = "Admin")]
public class UsersModel : PageModel
{
    private readonly IConfiguration _configuration;
    private readonly IWebHostEnvironment _environment;

    public UsersModel(IConfiguration configuration, IWebHostEnvironment environment)
    {
        _configuration = configuration;
        _environment = environment;
    }

    // ── Filter bind-properties (GET + POST) ──────────────────────────────────

    [BindProperty(SupportsGet = true)]
    public string? FirstName { get; set; }

    [BindProperty(SupportsGet = true)]
    public string? LastName { get; set; }

    [BindProperty(SupportsGet = true)]
    public string? ArmyRank { get; set; }

    [BindProperty(SupportsGet = true)]
    public string? Macom { get; set; }

    [BindProperty(SupportsGet = true)]
    public string? OfficeName { get; set; }

    [BindProperty(SupportsGet = true)]
    public string? CompanyName { get; set; }

    [BindProperty(SupportsGet = true)]
    public DateTime? CreatedFrom { get; set; }

    [BindProperty(SupportsGet = true)]
    public DateTime? CreatedTo { get; set; }

    [BindProperty(SupportsGet = true)]
    public DateTime? LastLoginFrom { get; set; }

    [BindProperty(SupportsGet = true)]
    public DateTime? LastLoginTo { get; set; }

    [BindProperty(SupportsGet = true)]
    public DateTime? ApprovedFrom { get; set; }

    [BindProperty(SupportsGet = true)]
    public DateTime? ApprovedTo { get; set; }

    [BindProperty(SupportsGet = true)]
    public DateTime? DeniedFrom { get; set; }

    [BindProperty(SupportsGet = true)]
    public DateTime? DeniedTo { get; set; }

    // ── Page-state properties ────────────────────────────────────────────────

    public List<UserRow> Users { get; private set; } = new();
    public List<(string Value, string Text)> Organizations { get; private set; } = new();

    [TempData]
    public string? StatusMessage { get; set; }

    public string? LoadError { get; private set; }

    /// <summary>UserId of the currently authenticated AMCOS user — used to disable self-role-toggle.</summary>
    public string? CurrentUserId { get; private set; }

    // ── Result row DTO ────────────────────────────────────────────────────────

    public record UserRow(
        string UserId,
        string Name,
        string Email,
        string? ArmyRank,
        string? Macom,
        string? CompanyName,
        string? OfficeName,
        string? Phone,
        string? AccountType,
        DateTime? DateCreated,
        DateTime? LastUpdate,
        DateTime? LastLogin,
        string? Role,
        int LoginCount);

    // ── Handlers ─────────────────────────────────────────────────────────────

    public void OnGet()
    {
        CurrentUserId = ResolveCurrentUser()?.UserId;
        LoadOrganizations();
        RunSearch();
    }

    /// <summary>Toggles the UserRole between "Admin" and "User" for the given userId.</summary>
    public IActionResult OnPostToggleRole(string userId)
    {
        try
        {
            var user = UserAdministration.GetUserById(userId);
            if (user is null)
            {
                StatusMessage = $"User '{userId}' was not found.";
                return RedirectToPage(BuildFilterRouteValues());
            }

            user.UserRole = string.Equals(user.UserRole, "Admin", StringComparison.OrdinalIgnoreCase)
                ? "User"
                : "Admin";

            UserAdministration.UpdateAmcosUser(user);
            StatusMessage = $"Role for {user.LastName}, {user.FirstName} updated to '{user.UserRole}'.";
        }
        catch (Exception ex)
        {
            StatusMessage = ex.Message;
        }

        return RedirectToPage(BuildFilterRouteValues());
    }

    /// <summary>Exports the current filtered user list to an Excel workbook.</summary>
    public IActionResult OnPostExport()
    {
        // Re-run the search using the filter values posted via the export form's hidden fields.
        LoadOrganizations();
        RunSearch();

        try
        {
            var licensePath = Path.Combine(_environment.ContentRootPath, "Licenses", "Aspose.Cells.lic");
            if (System.IO.File.Exists(licensePath))
            {
                new License().SetLicense(licensePath);
            }
        }
        catch { /* expired/mismatched Aspose license -> evaluation mode, still exports */ }

        var workbook = new Workbook();
        workbook.Worksheets.Clear();
        workbook.Worksheets.Add("Users");
        var sheet = workbook.Worksheets[0];

        // Header row
        string[] headers =
        {
            "Name", "Email", "Rank", "Organization", "Company", "Office", "Phone",
            "Account Type", "Login Count", "Date Created", "Last Update", "Last Login", "Role"
        };
        for (var c = 0; c < headers.Length; c++)
            sheet.Cells[0, c].PutValue(headers[c]);

        // Data rows
        for (var r = 0; r < Users.Count; r++)
        {
            var u = Users[r];
            sheet.Cells[r + 1, 0].PutValue(u.Name);
            sheet.Cells[r + 1, 1].PutValue(u.Email);
            sheet.Cells[r + 1, 2].PutValue(u.ArmyRank);
            sheet.Cells[r + 1, 3].PutValue(u.Macom);
            sheet.Cells[r + 1, 4].PutValue(u.CompanyName);
            sheet.Cells[r + 1, 5].PutValue(u.OfficeName);
            sheet.Cells[r + 1, 6].PutValue(u.Phone);
            sheet.Cells[r + 1, 7].PutValue(u.AccountType);
            sheet.Cells[r + 1, 8].PutValue(u.LoginCount);
            sheet.Cells[r + 1, 9].PutValue(u.DateCreated?.ToString("g"));
            sheet.Cells[r + 1, 10].PutValue(u.LastUpdate?.ToString("g"));
            sheet.Cells[r + 1, 11].PutValue(u.LastLogin?.ToString("g"));
            sheet.Cells[r + 1, 12].PutValue(u.Role);
        }

        sheet.AutoFitColumns();

        using var stream = new MemoryStream();
        workbook.Save(stream, SaveFormat.Xlsx);
        stream.Position = 0;

        return File(
            stream.ToArray(),
            "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
            $"AMCOS_Users_{DateTime.UtcNow:yyyyMMdd-HHmmss}.xlsx");
    }

    // ── Private helpers ───────────────────────────────────────────────────────

    private void LoadOrganizations()
    {
        try
        {
            Organizations = UserAdministration.GetOrganizations()
                .Select(o => (Value: o.Value, Text: o.Text))
                .ToList();
        }
        catch
        {
            // Leave Organizations empty; the dropdown will still render without options.
            Organizations = new();
        }
    }

    private void RunSearch()
    {
        try
        {
            // Mirrors the legacy VB.NET query: left-join login history, group + count, order by name.
            var sql = new StringBuilder(
                "SELECT u.userid," +
                " u.lastname || ', ' || u.firstname AS name," +
                " u.email," +
                " u.armyrank," +
                " u.macom," +
                " u.companyname," +
                " u.officename," +
                " u.comphone," +
                " u.armyaccounttype," +
                " u.datecreated," +
                " u.lastupdate," +
                " u.lastlogin," +
                " u.userrole AS role," +
                " COUNT(h.logindatetime) AS logincount" +
                " FROM webuser.amcosuser u" +
                " LEFT JOIN webuser.user_login_history h ON u.userid = h.userid" +
                " WHERE 1=1");

            var parameters = new List<NpgsqlParameter>();

            if (!string.IsNullOrWhiteSpace(FirstName))
            {
                sql.Append(" AND u.firstname ILIKE @firstName");
                parameters.Add(new NpgsqlParameter("@firstName", $"%{FirstName.Trim()}%"));
            }
            if (!string.IsNullOrWhiteSpace(LastName))
            {
                sql.Append(" AND u.lastname ILIKE @lastName");
                parameters.Add(new NpgsqlParameter("@lastName", $"%{LastName.Trim()}%"));
            }
            if (!string.IsNullOrWhiteSpace(ArmyRank))
            {
                sql.Append(" AND u.armyrank ILIKE @armyRank");
                parameters.Add(new NpgsqlParameter("@armyRank", $"%{ArmyRank.Trim()}%"));
            }
            if (!string.IsNullOrWhiteSpace(Macom))
            {
                // MACOM comes from a dropdown — exact match is appropriate.
                sql.Append(" AND u.macom = @macom");
                parameters.Add(new NpgsqlParameter("@macom", Macom.Trim()));
            }
            if (!string.IsNullOrWhiteSpace(OfficeName))
            {
                sql.Append(" AND u.officename ILIKE @officeName");
                parameters.Add(new NpgsqlParameter("@officeName", $"%{OfficeName.Trim()}%"));
            }
            if (!string.IsNullOrWhiteSpace(CompanyName))
            {
                sql.Append(" AND u.companyname ILIKE @companyName");
                parameters.Add(new NpgsqlParameter("@companyName", $"%{CompanyName.Trim()}%"));
            }
            // Date-range filters (To is inclusive of the whole day). Mirrors the legacy userlist filters.
            void AddDateRange(string col, DateTime? from, DateTime? to, string key)
            {
                if (from.HasValue)
                {
                    sql.Append($" AND {col} >= @{key}From");
                    parameters.Add(new NpgsqlParameter($"@{key}From", from.Value));
                }
                if (to.HasValue)
                {
                    sql.Append($" AND {col} < @{key}To + interval '1 day'");
                    parameters.Add(new NpgsqlParameter($"@{key}To", to.Value.Date));
                }
            }
            AddDateRange("u.datecreated", CreatedFrom, CreatedTo, "created");
            AddDateRange("u.lastlogin", LastLoginFrom, LastLoginTo, "lastlogin");
            AddDateRange("u.lastapproveddate", ApprovedFrom, ApprovedTo, "approved");
            AddDateRange("u.lastdenieddate", DeniedFrom, DeniedTo, "denied");

            sql.Append(
                " GROUP BY u.userid, name, u.email, u.armyrank, u.macom, u.companyname," +
                " u.officename, u.comphone, u.armyaccounttype, u.datecreated, u.lastupdate," +
                " u.lastlogin, u.userrole" +
                " ORDER BY name");

            using var conn = OpenConnection();
            using var cmd = new NpgsqlCommand(sql.ToString(), conn);
            foreach (var p in parameters)
                cmd.Parameters.Add(p);

            using var reader = cmd.ExecuteReader();
            while (reader.Read())
            {
                Users.Add(new UserRow(
                    UserId:      reader.GetString(0),
                    Name:        reader.IsDBNull(1)  ? string.Empty : reader.GetString(1),
                    Email:       reader.IsDBNull(2)  ? string.Empty : reader.GetString(2),
                    ArmyRank:    reader.IsDBNull(3)  ? null : reader.GetString(3),
                    Macom:       reader.IsDBNull(4)  ? null : reader.GetString(4),
                    CompanyName: reader.IsDBNull(5)  ? null : reader.GetString(5),
                    OfficeName:  reader.IsDBNull(6)  ? null : reader.GetString(6),
                    Phone:       reader.IsDBNull(7)  ? null : reader.GetString(7),
                    AccountType: reader.IsDBNull(8)  ? null : reader.GetString(8),
                    DateCreated: reader.IsDBNull(9)  ? null : (DateTime?)reader.GetDateTime(9),
                    LastUpdate:  reader.IsDBNull(10) ? null : (DateTime?)reader.GetDateTime(10),
                    LastLogin:   reader.IsDBNull(11) ? null : (DateTime?)reader.GetDateTime(11),
                    Role:        reader.IsDBNull(12) ? null : reader.GetString(12),
                    // COUNT() returns bigint in PostgreSQL; safe-cast to int.
                    LoginCount:  reader.IsDBNull(13) ? 0 : Convert.ToInt32(reader.GetValue(13))
                ));
            }
        }
        catch (Exception ex)
        {
            LoadError = ex.Message;
        }
    }

    /// <summary>Returns current filter values as an anonymous route-value object for RedirectToPage.</summary>
    private object BuildFilterRouteValues() => new
    {
        FirstName,
        LastName,
        ArmyRank,
        Macom,
        OfficeName,
        CompanyName,
        CreatedFrom,
        CreatedTo,
        LastLoginFrom,
        LastLoginTo,
        ApprovedFrom,
        ApprovedTo,
        DeniedFrom,
        DeniedTo
    };

    /// <summary>
    /// Permanently deletes a user and all of their dependent data (projects and their
    /// categories/skills/inventory/reports, PCS projects, and login history), in dependency
    /// order within a transaction. Mirrors the legacy admin "Delete user" capability
    /// (UpdateMyProfile.aspx btnDelete). There are no ON DELETE CASCADE FKs, so children
    /// must be removed first.
    /// </summary>
    public IActionResult OnPostDelete(string userId)
    {
        if (string.IsNullOrWhiteSpace(userId))
        {
            StatusMessage = "No user specified.";
            return RedirectToPage(BuildFilterRouteValues());
        }

        // Guard: an admin cannot delete their own account.
        if (string.Equals(userId, ResolveCurrentUser()?.UserId, StringComparison.OrdinalIgnoreCase))
        {
            StatusMessage = "You cannot delete your own account.";
            return RedirectToPage(BuildFilterRouteValues());
        }

        try
        {
            using var conn = OpenConnection();
            using var tx = conn.BeginTransaction();

            void Exec(string sql)
            {
                using var cmd = new NpgsqlCommand(sql, conn, tx);
                cmd.Parameters.Add(new NpgsqlParameter("@uid", userId));
                cmd.ExecuteNonQuery();
            }

            // Children first (FK order), then the user.
            Exec(@"DELETE FROM webuser.pmcategoryskillinventory WHERE skillid IN (
                       SELECT sk.skillid FROM webuser.pmcategoryskill sk
                       JOIN webuser.pmcategory c ON c.categoryid = sk.categoryid
                       JOIN webuser.pmproject p ON p.projectid = c.projectid
                       WHERE p.userid = @uid)");
            Exec(@"DELETE FROM webuser.pmreport WHERE categoryid IN (
                       SELECT c.categoryid FROM webuser.pmcategory c
                       JOIN webuser.pmproject p ON p.projectid = c.projectid
                       WHERE p.userid = @uid)");
            Exec(@"DELETE FROM webuser.pmcategoryskill WHERE categoryid IN (
                       SELECT c.categoryid FROM webuser.pmcategory c
                       JOIN webuser.pmproject p ON p.projectid = c.projectid
                       WHERE p.userid = @uid)");
            Exec(@"DELETE FROM webuser.pmcategory WHERE projectid IN (
                       SELECT projectid FROM webuser.pmproject WHERE userid = @uid)");
            Exec("DELETE FROM webuser.pmproject WHERE userid = @uid");
            Exec("DELETE FROM webuser.pcsproject WHERE userid = @uid");
            Exec("DELETE FROM webuser.user_login_history WHERE userid = @uid");
            Exec("DELETE FROM webuser.amcosuser WHERE userid = @uid");

            tx.Commit();
            StatusMessage = $"User '{userId}' and all associated data were deleted.";
        }
        catch (Exception ex)
        {
            StatusMessage = $"Could not delete user: {ex.Message}";
        }

        return RedirectToPage(BuildFilterRouteValues());
    }

    private AMCOSUser? ResolveCurrentUser()
    {
        var identity = User.Identity as ClaimsIdentity;
        if (identity?.IsAuthenticated != true)
            return null;

        try
        {
            return UserAdministration.GetCurrentUser(identity);
        }
        catch
        {
            return null;
        }
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
