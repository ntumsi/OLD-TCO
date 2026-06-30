using System.Data;
using System.Globalization;

namespace AMCOS.Web.Core.Pages.App.Project;

/// <summary>
/// Ports the legacy report.aspx.vb cost-report shaping into a single reusable builder so the
/// on-screen table and the Excel export render identically. The migrated PostgreSQL
/// <c>web.pmreport</c> returns only the raw per-cost-element crosstab rows (one column per
/// calendar year). The legacy WebForms page then computed the APPN sub-totals, the grand totals,
/// the discounted (PVF-multiplied) summary, applied the appropriation colouring and tidied the
/// labels in code-behind. None of that survived the migration; this class restores it.
/// </summary>
public static class CostReportBuilder
{
    // Pay plans that drive the legacy APPN sub-total grouping.
    private static readonly string[] ActivePayPlans = { "AE", "AO", "AWO" };
    private static readonly string[] ArmyCivPayPlans =
        { "DB", "DE", "DJ", "DK", "GG", "GL", "GS", "GP", "NH", "NJ", "NK", "SES", "WG", "WL", "WS" };
    private static readonly string[] ReservePayPlans = { "NE", "NO", "NWO", "RE", "RO", "RWO" };

    // Columns that exist for bookkeeping/colouring and must never be shown to the user.
    public static readonly string[] HiddenColumns = { "GradeLevel", "ExceedsSalaryLimit", "ShowOrder", "RowKind" };

    /// <summary>Row classification, also used to drive cell colouring (see <see cref="RowKindColor"/>).</summary>
    public const string KindData = "Data";
    public const string KindArmy = "Army";
    public const string KindDod = "Dod";
    public const string KindFed = "Fed";
    public const string KindPa = "Pa";
    public const string KindOm = "Om";
    public const string KindContractor = "Contractor";
    public const string KindSubProject = "SubProject";
    public const string KindGrand = "Grand";

    /// <summary>Background colour (and whether white text) for a sub-total / total row kind.</summary>
    public static (string Bg, bool White)? RowKindColor(string? kind) => kind switch
    {
        KindArmy => ("#5D7430", true),
        KindDod => ("#7030A0", true),
        KindFed => ("#00008B", true),
        KindPa => ("#8BA103", true),
        KindOm => ("#6E8003", true),
        KindContractor => ("#006D8B", true),
        KindSubProject => ("#D3D3D3", false),
        KindGrand => ("#000000", true),
        _ => null
    };

    public sealed class Result
    {
        public DataTable Undiscounted { get; init; } = new();
        public DataTable Discounted { get; init; } = new();
        public List<string> YearColumns { get; init; } = new();
        public bool HasSpecialPay { get; init; }
        public bool CceOverSalaryLimit { get; init; }
    }

    /// <summary>
    /// Shapes the raw <c>default_summary</c> table into display-ready undiscounted and discounted
    /// tables, with APPN sub-totals, grand totals, tidy labels and a hidden RowKind column.
    /// </summary>
    /// <param name="raw">The raw crosstab (already passed through Project.UpdateLocationDisplay).</param>
    /// <param name="pvfByYear">Present-value factor keyed by calendar-year column name.</param>
    public static Result Build(DataTable? raw, IReadOnlyDictionary<string, decimal> pvfByYear)
    {
        if (raw is null || raw.Columns.Count == 0)
        {
            return new Result();
        }

        var yearColumns = raw.Columns.Cast<DataColumn>()
            .Where(c => int.TryParse(c.ColumnName, NumberStyles.Integer, CultureInfo.InvariantCulture, out _))
            .Select(c => c.ColumnName)
            .ToList();

        // Working table: same columns as raw, plus a hidden RowKind discriminator.
        var dt = raw.Clone();
        foreach (DataColumn c in dt.Columns)
        {
            c.DataType = typeof(object); // we mix decimals, strings and nulls freely
            c.ReadOnly = false;
        }
        if (!dt.Columns.Contains("RowKind")) dt.Columns.Add("RowKind", typeof(string));
        var hasShowOrder = dt.Columns.Contains("ShowOrder");

        // 1. Stable sort the data rows (legacy sSort), then renumber ShowOrder = i*10 so we have
        //    room to slot the sub-total rows in between categories.
        var sorted = raw.Rows.Cast<DataRow>()
            .OrderBy(r => Str(r, "Sub-Project Name"), StringComparer.OrdinalIgnoreCase)
            .ThenBy(r => Str(r, "UIC"), StringComparer.OrdinalIgnoreCase)
            .ThenBy(r => Str(r, "PayPlan"), StringComparer.OrdinalIgnoreCase)
            .ThenBy(r => Str(r, "CategoryGroupCode"), StringComparer.OrdinalIgnoreCase)
            .ThenBy(r => Str(r, "CategorySubgroupCode"), StringComparer.OrdinalIgnoreCase)
            .ThenBy(r => Str(r, "Location"), StringComparer.OrdinalIgnoreCase)
            .ThenBy(r => Dec(r, "GradeLevel"))
            .ThenBy(r => Dec(r, "ShowOrder"))
            .ToList();

        var hasSpecialPay = false;
        var cceOverLimit = false;

        for (var i = 0; i < sorted.Count; i++)
        {
            var src = sorted[i];
            var nr = dt.NewRow();
            foreach (DataColumn c in raw.Columns)
            {
                nr[c.ColumnName] = src[c.ColumnName];
            }

            CleanLabels(nr);
            if (hasShowOrder) nr["ShowOrder"] = i * 10;
            nr["RowKind"] = KindData;
            dt.Rows.Add(nr);

            if (ActivePayPlans.Contains(Str(src, "PayPlan"), StringComparer.OrdinalIgnoreCase)) hasSpecialPay = true;
            if (IsTrue(src, "ExceedsSalaryLimit")) cceOverLimit = true;
        }

        // 2. Per-category APPN sub-totals.
        var categories = dt.Rows.Cast<DataRow>()
            .Where(r => Str(r, "RowKind") == KindData)
            .Select(r => Str(r, "Sub-Project Name"))
            .Distinct()
            .ToList();

        var multipleCategories = categories.Count > 1;

        foreach (var category in categories)
        {
            var rows = dt.Rows.Cast<DataRow>()
                .Where(r => Str(r, "RowKind") == KindData && Str(r, "Sub-Project Name") == category)
                .ToList();
            if (rows.Count == 0) continue;

            var maxSeq = rows.Max(r => (int)Dec(r, "ShowOrder"));

            AddSubtotalIfAny(dt, yearColumns, rows, IsArmy, "ARMY APPN Total: ", KindArmy, category, maxSeq + 1);
            AddSubtotalIfAny(dt, yearColumns, rows, IsDod, "DoD APPN Total: ", KindDod, category, maxSeq + 2);
            AddSubtotalIfAny(dt, yearColumns, rows, IsFederal, "FEDERAL APPN Total: ", KindFed, category, maxSeq + 3);
            AddSubtotalIfAny(dt, yearColumns, rows, IsPa, "PA APPN Total: ", KindPa, category, maxSeq + 4);
            AddSubtotalIfAny(dt, yearColumns, rows, IsOm, "OM APPN Total: ", KindOm, category, maxSeq + 5);
            AddSubtotalIfAny(dt, yearColumns, rows, IsContractor, "Contractor APPN Total: ", KindContractor, category, maxSeq + 6);

            // Sub-Project Total is always present (sum of every costed row in the category).
            AddSubtotal(dt, yearColumns, rows.Where(HasAppn).ToList(),
                "Sub-Project Total: ", KindSubProject, category, maxSeq + 8);
        }

        // 3. Grand totals across all categories (legacy "Total of all …" + "TOTAL APPN COST SUMMARY").
        if (multipleCategories)
        {
            var baseSeq = (dt.Rows.Cast<DataRow>().Max(r => (int)Dec(r, "ShowOrder")) + 10) * 10;

            AddGrandTotal(dt, yearColumns, KindArmy, "Total of all ARMY APPNs: ", KindArmy, baseSeq + 1);
            AddGrandTotal(dt, yearColumns, KindDod, "Total of all DoD APPNs: ", KindDod, baseSeq + 2);
            AddGrandTotal(dt, yearColumns, KindFed, "Total of all FEDERAL APPNs: ", KindFed, baseSeq + 3);
            AddGrandTotal(dt, yearColumns, KindPa, "Total of all PA APPNs: ", KindPa, baseSeq + 4);
            AddGrandTotal(dt, yearColumns, KindOm, "Total of all OM APPNs: ", KindOm, baseSeq + 5);
            AddGrandTotal(dt, yearColumns, KindContractor, "Total of all Contractor APPNs: ", KindContractor, baseSeq + 6);
        }

        // Final grand summary: sum of every original costed row across the whole report.
        {
            var allCosted = dt.Rows.Cast<DataRow>()
                .Where(r => Str(r, "RowKind") == KindData && HasAppn(r))
                .ToList();
            if (allCosted.Count > 0)
            {
                var seq = dt.Rows.Cast<DataRow>().Max(r => (int)Dec(r, "ShowOrder")) + 10;
                AddSubtotal(dt, yearColumns, allCosted, "TOTAL APPN COST SUMMARY: ", KindGrand, "", seq);
            }
        }

        // 4. Order by ShowOrder so sub-totals fall after their category rows.
        var ordered = CloneSortedByShowOrder(dt);

        // 5. Discounted copy = each year cost × that year's PVF.
        var discounted = ordered.Copy();
        foreach (DataRow row in discounted.Rows)
        {
            foreach (var yc in yearColumns)
            {
                var pvf = pvfByYear.TryGetValue(yc, out var f) ? f : 1m;
                if (TryDec(row[yc], out var v)) row[yc] = v * pvf;
            }
        }

        return new Result
        {
            Undiscounted = ordered,
            Discounted = discounted,
            YearColumns = yearColumns,
            HasSpecialPay = hasSpecialPay,
            CceOverSalaryLimit = cceOverLimit
        };
    }

    // ── sub-total helpers ─────────────────────────────────────────────────────

    private static void AddSubtotalIfAny(DataTable dt, List<string> yearColumns, List<DataRow> rows,
        Func<DataRow, bool> predicate, string label, string kind, string category, int showOrder)
    {
        var matched = rows.Where(predicate).ToList();
        if (matched.Count > 0)
        {
            AddSubtotal(dt, yearColumns, matched, label, kind, category, showOrder);
        }
    }

    private static void AddSubtotal(DataTable dt, List<string> yearColumns, List<DataRow> rows,
        string label, string kind, string category, int showOrder)
    {
        var nr = dt.NewRow();
        if (dt.Columns.Contains("Sub-Project Name")) nr["Sub-Project Name"] = category;
        if (dt.Columns.Contains("Cost Element")) nr["Cost Element"] = label;
        if (dt.Columns.Contains("ShowOrder")) nr["ShowOrder"] = showOrder;
        nr["RowKind"] = kind;
        foreach (var yc in yearColumns)
        {
            nr[yc] = rows.Sum(r => TryDec(r[yc], out var v) ? v : 0m);
        }
        dt.Rows.Add(nr);
    }

    private static void AddGrandTotal(DataTable dt, List<string> yearColumns, string sourceKind,
        string label, string kind, int showOrder)
    {
        var rows = dt.Rows.Cast<DataRow>().Where(r => Str(r, "RowKind") == sourceKind).ToList();
        if (rows.Count == 0) return;
        AddSubtotal(dt, yearColumns, rows, label, kind, "", showOrder);
    }

    private static DataTable CloneSortedByShowOrder(DataTable dt)
    {
        var ordered = dt.Clone();
        foreach (var row in dt.Rows.Cast<DataRow>().OrderBy(r => Dec(r, "ShowOrder")))
        {
            ordered.ImportRow(row);
        }
        return ordered;
    }

    // ── APPN grouping predicates (mirror the legacy WHERE clauses) ─────────────

    private static bool IsArmy(DataRow r)
    {
        var pp = Str(r, "PayPlan");
        var appn = Str(r, "APPN");
        var activeMatch = ActivePayPlans.Contains(pp, StringComparer.OrdinalIgnoreCase)
            && new[] { "MPA", "MPA Non-Pay", "OMA", "OMA_1" }.Contains(appn, StringComparer.OrdinalIgnoreCase);
        var civMatch = ArmyCivPayPlans.Contains(pp, StringComparer.OrdinalIgnoreCase)
            && (appn.StartsWith("ARMY", StringComparison.OrdinalIgnoreCase) || appn.Equals("OMA", StringComparison.OrdinalIgnoreCase));
        return activeMatch || civMatch;
    }

    private static bool IsDod(DataRow r) => Str(r, "APPN").StartsWith("OMDW", StringComparison.OrdinalIgnoreCase);
    private static bool IsFederal(DataRow r) => Str(r, "APPN").StartsWith("Federal", StringComparison.OrdinalIgnoreCase);

    private static bool IsPa(DataRow r) =>
        ReservePayPlans.Contains(Str(r, "PayPlan"), StringComparer.OrdinalIgnoreCase)
        && Str(r, "APPN").Contains("PA", StringComparison.OrdinalIgnoreCase);

    private static bool IsOm(DataRow r) =>
        ReservePayPlans.Contains(Str(r, "PayPlan"), StringComparer.OrdinalIgnoreCase)
        && Str(r, "APPN").Contains("OM", StringComparison.OrdinalIgnoreCase);

    private static bool IsContractor(DataRow r) => Str(r, "APPN").StartsWith("Contractor", StringComparison.OrdinalIgnoreCase);

    private static bool HasAppn(DataRow r) => !string.IsNullOrEmpty(Str(r, "APPN"));

    // ── label tidy-up (mirror the legacy RowDataBound / export string fixes) ───

    private static void CleanLabels(DataRow nr)
    {
        // Grade: SES1/2/3 → MIN/AVG/MAX; strip CCE prefix on contractor percentile grades.
        if (nr.Table.Columns.Contains("Grade"))
        {
            var grade = nr["Grade"]?.ToString() ?? "";
            grade = grade switch { "SES1" => "MIN", "SES2" => "AVG", "SES3" => "MAX", _ => grade };
            if (grade.StartsWith("CCEA_", StringComparison.Ordinal)) grade = grade[3..]; // CCEA_PCT10 → A_PCT10
            nr["Grade"] = grade;
        }

        if (nr.Table.Columns.Contains("Cost Element"))
        {
            var ce = nr["Cost Element"]?.ToString() ?? "";
            if (ce.Contains(" MMPA")) ce = ce.Replace(" MMPA", " PA");
            if (ce.StartsWith("CCE_", StringComparison.Ordinal)) ce = ce[4..];
            if (ce == "Avg Cost of Special Pays") ce = "**" + ce; // not inflated – footnoted
            nr["Cost Element"] = ce;
        }
    }

    // ── value helpers ──────────────────────────────────────────────────────────

    private static string Str(DataRow r, string col) =>
        r.Table.Columns.Contains(col) && r[col] != DBNull.Value ? (r[col]?.ToString()?.Trim() ?? "") : "";

    private static decimal Dec(DataRow r, string col) =>
        r.Table.Columns.Contains(col) && TryDec(r[col], out var v) ? v : 0m;

    private static bool IsTrue(DataRow r, string col)
    {
        if (!r.Table.Columns.Contains(col) || r[col] == DBNull.Value) return false;
        var s = r[col].ToString();
        return s == "1" || string.Equals(s, "true", StringComparison.OrdinalIgnoreCase);
    }

    private static bool TryDec(object? value, out decimal result)
    {
        result = 0m;
        if (value is null || value == DBNull.Value) return false;
        if (value is decimal d) { result = d; return true; }
        if (value is double db) { result = (decimal)db; return true; }
        if (value is int i) { result = i; return true; }
        if (value is long l) { result = l; return true; }
        return decimal.TryParse(value.ToString(), NumberStyles.Any, CultureInfo.InvariantCulture, out result);
    }
}