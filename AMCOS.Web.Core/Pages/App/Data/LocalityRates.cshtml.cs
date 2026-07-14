using System.Data;
using AMCOS.Logic;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;

namespace AMCOS.Web.Core.Pages.App.Data;

// Local GS Locality Rates by ZIP dashboard (replaces the QuickSight "locality-rates"
// embed). Enter a ZIP -> resolve its GS locality pay area(s) and rate, shown against a
// comparison bar of all locality rates. Source: lookup.fips_zip + xwalk.localitypayareatofips
// + lookup.localitypayarea + "PaySchedule".localitypay via LocalDashboards. Locality data is
// empty until the pay-schedule/xwalk ETL runs, in which case lookups return an empty state.
[Authorize]
public class LocalityRatesModel : PageModel
{
    public List<int> Versions { get; private set; } = new();
    public int SelectedVersion { get; private set; }
    public string? LoadError { get; private set; }

    public void OnGet(int? version)
    {
        try
        {
            Versions = ReadInts(LocalDashboards.GetAmcosVersions(), "amcosversionid");
            SelectedVersion = version ?? Versions.FirstOrDefault();
        }
        catch (Exception ex)
        {
            LoadError = $"Locality data could not be loaded: {ex.Message}";
        }
    }

    // JSON: { zip, matches:[{code,name,rate}], all:[{name,rate}] }.
    public IActionResult OnGetData(string zip, int version)
    {
        try
        {
            zip = (zip ?? string.Empty).Trim();

            var matches = new List<object>();
            var matchedNames = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
            if (zip.Length > 0)
            {
                foreach (DataRow row in LocalDashboards.GetLocalityRateByZip(zip, version).Rows)
                {
                    var name = row["localityname"]?.ToString() ?? "";
                    matchedNames.Add(name);
                    matches.Add(new
                    {
                        code = row["localitycode"]?.ToString(),
                        name,
                        rate = ToDecimal(row["localityrate"])
                    });
                }
            }

            var all = new List<object>();
            foreach (DataRow row in LocalDashboards.GetAllLocalityRates(version).Rows)
            {
                var name = row["localityname"]?.ToString() ?? "";
                all.Add(new
                {
                    name,
                    rate = ToDecimal(row["localityrate"]),
                    matched = matchedNames.Contains(name)
                });
            }

            return new JsonResult(new { zip, matches, all });
        }
        catch (Exception ex)
        {
            return new ObjectResult(new { error = ex.Message }) { StatusCode = 500 };
        }
    }

    private static decimal ToDecimal(object value) =>
        value == DBNull.Value || value == null ? 0m : Convert.ToDecimal(value);

    private static List<int> ReadInts(DataTable table, string column)
    {
        var list = new List<int>();
        foreach (DataRow row in table.Rows)
            if (row[column] != DBNull.Value) list.Add(Convert.ToInt32(row[column]));
        return list;
    }
}
