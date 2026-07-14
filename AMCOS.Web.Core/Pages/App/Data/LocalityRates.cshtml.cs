using System.Data;
using AMCOS.Logic;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;

namespace AMCOS.Web.Core.Pages.App.Data;

// Local GS Locality Rates by ZIP dashboard (replaces the QuickSight "locality-rates"
// embed). Enter a ZIP -> resolve its GS locality pay area(s) and compare the rate
// between TWO AMCOS versions, shown against a comparison bar of all locality rates.
// Source: lookup.fips_zip + xwalk.localitypayareatofips + lookup.localitypayarea +
// "PaySchedule".localitypay via LocalDashboards. Locality data is empty until ETL.
[Authorize]
public class LocalityRatesModel : PageModel
{
    public List<int> Versions { get; private set; } = new();
    public int VersionA { get; private set; }
    public int VersionB { get; private set; }
    public string? LoadError { get; private set; }

    public void OnGet(int? versionA, int? versionB)
    {
        try
        {
            Versions = ReadInts(LocalDashboards.GetAmcosVersions(), "amcosversionid");
            VersionA = versionA ?? Versions.ElementAtOrDefault(0);
            VersionB = versionB ?? (Versions.Count > 1 ? Versions[1] : VersionA);
        }
        catch (Exception ex)
        {
            LoadError = $"Locality data could not be loaded: {ex.Message}";
        }
    }

    // JSON: { zip, versionA, versionB, matched:[names],
    //         localities:[{ name, a, b, matched }] } — a/b are the rate in each version.
    public IActionResult OnGetData(string zip, int versionA, int versionB)
    {
        try
        {
            zip = (zip ?? string.Empty).Trim();

            var matched = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
            if (zip.Length > 0)
            {
                foreach (var name in ZipLocalityNames(zip, versionA)) matched.Add(name);
                foreach (var name in ZipLocalityNames(zip, versionB)) matched.Add(name);
            }

            var a = RatesByLocality(LocalDashboards.GetAllLocalityRates(versionA));
            var b = RatesByLocality(LocalDashboards.GetAllLocalityRates(versionB));

            var names = a.Keys.Union(b.Keys)
                .OrderByDescending(n => a.TryGetValue(n, out var v) ? v : (b.TryGetValue(n, out var v2) ? v2 : 0m))
                .ToList();

            var localities = names.Select(n => new
            {
                name = n,
                a = a.TryGetValue(n, out var va) ? va : 0m,
                b = b.TryGetValue(n, out var vb) ? vb : 0m,
                matched = matched.Contains(n)
            });

            return new JsonResult(new { zip, versionA, versionB, matched = matched.ToList(), localities });
        }
        catch (Exception ex)
        {
            return new ObjectResult(new { error = ex.Message }) { StatusCode = 500 };
        }
    }

    private static IEnumerable<string> ZipLocalityNames(string zip, int version)
    {
        foreach (DataRow row in LocalDashboards.GetLocalityRateByZip(zip, version).Rows)
            yield return row["localityname"]?.ToString() ?? "";
    }

    private static Dictionary<string, decimal> RatesByLocality(DataTable table)
    {
        var map = new Dictionary<string, decimal>(StringComparer.OrdinalIgnoreCase);
        foreach (DataRow row in table.Rows)
        {
            var name = row["localityname"]?.ToString() ?? "";
            var rate = row["localityrate"] == DBNull.Value ? 0m : Convert.ToDecimal(row["localityrate"]);
            map[name] = rate;
        }
        return map;
    }

    private static List<int> ReadInts(DataTable table, string column)
    {
        var list = new List<int>();
        foreach (DataRow row in table.Rows)
            if (row[column] != DBNull.Value) list.Add(Convert.ToInt32(row[column]));
        return list;
    }
}
