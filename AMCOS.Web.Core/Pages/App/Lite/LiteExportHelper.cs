using System.Data;
using System.Globalization;
using System.Text.RegularExpressions;
using ClosedXML.Excel;
using AMCOS.Web.Core.Models;

namespace AMCOS.Web.Core.Pages.App.Lite;

/// <summary>
/// Builds the AMCOS Lite Excel download (legacy default.aspx IbDownloadExcel_Click): classification
/// banner, page title, inflation-rate header, filter selections, and the cost detail grid — shaped
/// to match the on-screen grid (amcos-lite.js shapeCostTable / renderTable): internal columns hidden,
/// rows ordered by ShowOrder, WSM/Federal-OM subtotals + grand Total, currency formatting, and the
/// CCE over-limit column highlight. Uses ClosedXML (MIT) rather than Aspose.Cells.
/// </summary>
public static class LiteExportHelper
{
    private const string NameCol = "Cost Element Name";
    private const string PercentFormat = "0.00%";
    private const string CurrencyFormat = "$#,##0.00;($#,##0.00)";
    private static readonly string[] PreferredCols = { "appn", "Cost Element Category", "Cost Element Name" };
    private static readonly string[] HiddenCols = { "showorder", "appngroup", "description" };

    public static byte[] Build(LiteCostRequest req, DataTable costs, DataTable inflation,
        decimal cceMaxPayFootnote, int defaultYear)
    {
        using var workbook = new XLWorkbook();
        var ws = workbook.Worksheets.Add("AMCOS Lite");

        var row = 0;
        WriteBanner(ws, row, "UNCLASSIFIED//FOR OFFICIAL USE ONLY");
        row += 2;

        var title = Cell0(ws, row, 0);
        title.Value = "AMCOS Lite";
        title.Style.Font.Bold = true;
        title.Style.Font.FontSize = 16;
        row += 2;

        row = WriteInflation(ws, row, inflation);
        row = WriteFilters(ws, row, req, defaultYear);
        WriteCostDetail(ws, row, costs, req, cceMaxPayFootnote);

        ws.Columns().AdjustToContents();

        using var stream = new MemoryStream();
        workbook.SaveAs(stream);
        return stream.ToArray();
    }

    // ── inflation-rate header ─────────────────────────────────────────────────
    private static int WriteInflation(IXLWorksheet ws, int row, DataTable inflation)
    {
        row = WriteSectionTitle(ws, row, "Inflation Rates");
        if (inflation == null || inflation.Columns.Count == 0 || inflation.Rows.Count == 0)
        {
            Cell0(ws, row, 0).Value = "No data available.";
            return row + 2;
        }
        for (var c = 0; c < inflation.Columns.Count; c++)
            WriteHeaderCell(ws, row, c, inflation.Columns[c].ColumnName);
        row++;
        var data = inflation.Rows[0];
        for (var c = 0; c < inflation.Columns.Count; c++)
        {
            var cell = Cell0(ws, row, c);
            var value = data[c];
            // First column is the row label ('Inflation Rate'); the rest are fractional rates → percent.
            if (c > 0 && decimal.TryParse(value?.ToString(), NumberStyles.Any, CultureInfo.InvariantCulture, out var rate))
            {
                cell.Value = (double)rate;
                cell.Style.NumberFormat.Format = PercentFormat;
            }
            else
            {
                cell.Value = value == DBNull.Value ? "" : value?.ToString() ?? "";
            }
        }
        return row + 2;
    }

    // ── filter selections ─────────────────────────────────────────────────────
    private static int WriteFilters(IXLWorksheet ws, int row, LiteCostRequest req, int defaultYear)
    {
        row = WriteSectionTitle(ws, row, "Filter Selections");
        row = WriteKeyValue(ws, row, "Pay Plan", req.PayPlan);
        row = WriteKeyValue(ws, row, "Cost Summary", req.CostSummaryName);
        row = WriteKeyValue(ws, row, "Category Group", req.CategoryGroupCode);
        row = WriteKeyValue(ws, row, "Category Subgroup", req.CategorySubgroupCode);
        row = WriteKeyValue(ws, row, "Career Program", req.CareerProgramNumber);
        row = WriteKeyValue(ws, row, "Location", string.IsNullOrWhiteSpace(req.LocationText) ? req.LocationId.ToString() : req.LocationText);
        row = WriteKeyValue(ws, row, "Dependent Status", req.DependentStatus);
        if (!string.IsNullOrWhiteSpace(req.ScienceTechnologyReinventionLaboratory) && req.ScienceTechnologyReinventionLaboratory != "-1")
            row = WriteKeyValue(ws, row, "STRL", req.ScienceTechnologyReinventionLaboratory);
        if (string.Equals(req.PayPlan, "CCE", StringComparison.OrdinalIgnoreCase))
            row = WriteKeyValue(ws, row, "Overhead %", (req.OverheadPercent ?? 0).ToString(CultureInfo.InvariantCulture));
        row = WriteKeyValue(ws, row, "Inflation", $"{req.InflationConversionType} (Base/Input Year: {defaultYear})");
        row = WriteKeyValue(ws, row, "Output/Target Year", req.InflationYear);
        return row + 1;
    }

    // ── cost detail grid ──────────────────────────────────────────────────────
    private static void WriteCostDetail(IXLWorksheet ws, int row, DataTable costs, LiteCostRequest req, decimal cceMaxPay)
    {
        row = WriteSectionTitle(ws, row, "Cost Detail");
        if (costs == null || costs.Columns.Count == 0 || costs.Rows.Count == 0)
        {
            Cell0(ws, row, 0).Value = "No data available.";
            return;
        }

        var rows = ToDicts(costs);
        var shaped = Shape(rows, req.CostSummaryName ?? "Default", req.PayPlan ?? string.Empty);
        var headers = OrderHeaders(rows[0].Keys);
        var gradeCols = headers.Where(IsGradeCol).ToList();
        var isCce = string.Equals(req.PayPlan, "CCE", StringComparison.OrdinalIgnoreCase);

        // CCE: legacy highlights the entire grade column when a value equals the salary-limit sentinel.
        var cceCols = new HashSet<string>();
        if (isCce && cceMaxPay > 0)
            foreach (var gc in gradeCols)
                if (shaped.Any(r => !IsTotal(r) && Num(r.GetValueOrDefault(gc)) == cceMaxPay))
                    cceCols.Add(gc);

        for (var c = 0; c < headers.Count; c++) WriteHeaderCell(ws, row, c, headers[c]);
        row++;

        foreach (var r in shaped)
        {
            var total = IsTotal(r);
            var grand = r.ContainsKey("_grand");
            for (var c = 0; c < headers.Count; c++)
            {
                var h = headers[c];
                var grade = IsGradeCol(h);
                var value = r.GetValueOrDefault(h);
                var cell = Cell0(ws, row, c);

                if (grade && value != null && value != DBNull.Value
                    && decimal.TryParse(value.ToString(), NumberStyles.Any, CultureInfo.InvariantCulture, out var money))
                {
                    cell.Value = (double)money;
                }
                else
                {
                    cell.Value = value == null || value == DBNull.Value ? "" : value.ToString();
                }

                if (grade) cell.Style.NumberFormat.Format = CurrencyFormat;
                if (total)
                {
                    cell.Style.Fill.BackgroundColor = grand ? XLColor.FromHtml("#343a40") : XLColor.FromHtml("#DEDFDE");
                    cell.Style.Font.Bold = true;
                    if (grand) cell.Style.Font.FontColor = XLColor.White;
                }
                else if (cceCols.Contains(h))
                {
                    cell.Style.Fill.BackgroundColor = XLColor.Yellow;
                }
            }
            row++;
        }
    }

    // ── row shaping (mirror amcos-lite.js shapeCostTable) ─────────────────────
    private static List<Dictionary<string, object?>> Shape(List<Dictionary<string, object?>> rows, string summary, string payPlan)
    {
        if (rows.Count == 0) return rows;
        var gradeCols = rows[0].Keys.Where(IsGradeCol).ToList();

        var work = rows.Where(r =>
        {
            var nm = (Convert.ToString(r.GetValueOrDefault(NameCol)) ?? "").ToLowerInvariant();
            if (!nm.Contains("weapon specific training")) return true;
            return !gradeCols.All(gc => Num(r.GetValueOrDefault(gc)) == 0);
        }).OrderBy(r => Num(r.GetValueOrDefault("showorder"))).ToList();

        if (gradeCols.Count == 0) return work;
        var maxShow = work.Count == 0 ? 0m : work.Max(r => Num(r.GetValueOrDefault("showorder")));

        Dictionary<string, object?> SumRow(string label, Func<Dictionary<string, object?>, bool> predicate, decimal order, string kind)
        {
            var r = new Dictionary<string, object?> { [NameCol] = label, ["showorder"] = order, ["_total"] = true, [kind] = true };
            foreach (var gc in gradeCols)
                r[gc] = Math.Round(work.Where(predicate).Sum(x => Num(x.GetValueOrDefault(gc))), 2);
            return r;
        }

        var extras = new List<Dictionary<string, object?>>();
        if (summary == "Weapon System Manpower" && payPlan.StartsWith("A", StringComparison.OrdinalIgnoreCase))
        {
            extras.Add(SumRow("WEAPON SYSTEM MANPOWER Total", r => Convert.ToString(r.GetValueOrDefault("appn")) != "Federal OM", maxShow + 1, "_subtotal"));
            if (work.Any(r => Convert.ToString(r.GetValueOrDefault("appn")) == "Federal OM"))
                extras.Add(SumRow("FEDERAL OM Total", r => Convert.ToString(r.GetValueOrDefault("appn")) == "Federal OM", maxShow + 2, "_subtotal"));
        }
        if (summary != "Ancillary")
            extras.Add(SumRow("Total", r => !(Convert.ToString(r.GetValueOrDefault(NameCol)) ?? "").ToLowerInvariant().EndsWith("total"), maxShow + 3, "_grand"));

        return work.Concat(extras).ToList();
    }

    // ── helpers ───────────────────────────────────────────────────────────────
    private static IXLCell Cell0(IXLWorksheet ws, int row, int col) => ws.Cell(row + 1, col + 1);

    private static IXLRange Range0(IXLWorksheet ws, int firstRow, int firstCol, int totalRows, int totalCols)
        => ws.Range(firstRow + 1, firstCol + 1, firstRow + totalRows, firstCol + totalCols);

    private static bool IsTotal(Dictionary<string, object?> r) => r.ContainsKey("_total");

    private static List<Dictionary<string, object?>> ToDicts(DataTable table)
    {
        var list = new List<Dictionary<string, object?>>();
        foreach (DataRow dr in table.Rows)
        {
            var d = new Dictionary<string, object?>();
            foreach (DataColumn col in table.Columns)
                d[col.ColumnName] = dr[col] == DBNull.Value ? null : dr[col];
            list.Add(d);
        }
        return list;
    }

    private static readonly Regex GradeRx = new(@"^[A-Za-z]{1,3}\d{1,2}$", RegexOptions.Compiled);
    private static bool IsGradeCol(string h) =>
        GradeRx.IsMatch(h) || Regex.IsMatch(h, "^(MIN|AVG|MAX)$", RegexOptions.IgnoreCase)
        || Regex.IsMatch(h, "^A_(PCT|MEDIAN)", RegexOptions.IgnoreCase);
    private static int GradeNum(string h) { var m = Regex.Match(h, @"\d+"); return m.Success ? int.Parse(m.Value) : 0; }

    private static List<string> OrderHeaders(IEnumerable<string> all)
    {
        var visible = all.Where(h => !HiddenCols.Contains(h, StringComparer.OrdinalIgnoreCase)).ToList();
        var lead = PreferredCols.Where(visible.Contains).ToList();
        var grades = visible.Where(h => IsGradeCol(h) && !lead.Contains(h)).OrderBy(GradeNum).ToList();
        var rest = visible.Where(h => !lead.Contains(h) && !grades.Contains(h)).ToList();
        return lead.Concat(rest).Concat(grades).ToList();
    }

    private static decimal Num(object? v)
    {
        if (v == null || v == DBNull.Value) return 0m;
        return v switch
        {
            decimal d => d,
            double db => (decimal)db,
            int i => i,
            long l => l,
            _ => decimal.TryParse(v.ToString(), NumberStyles.Any, CultureInfo.InvariantCulture, out var r) ? r : 0m
        };
    }

    // ── styled-cell writers ───────────────────────────────────────────────────
    private static void WriteBanner(IXLWorksheet ws, int row, string text)
    {
        var cell = Cell0(ws, row, 0);
        cell.Value = text;
        cell.Style.Font.Bold = true;
        cell.Style.Font.FontColor = XLColor.White;
        cell.Style.Fill.BackgroundColor = XLColor.Green;
        cell.Style.Alignment.Horizontal = XLAlignmentHorizontalValues.Center;
        Range0(ws, row, 0, 1, 10).Merge();
    }

    private static int WriteSectionTitle(IXLWorksheet ws, int row, string title)
    {
        var cell = Cell0(ws, row, 0);
        cell.Value = title;
        cell.Style.Font.Bold = true;
        cell.Style.Font.FontSize = 14;
        return row + 1;
    }

    private static int WriteKeyValue(IXLWorksheet ws, int row, string key, string? value)
    {
        var keyCell = Cell0(ws, row, 0);
        keyCell.Value = key;
        keyCell.Style.Font.Bold = true;
        keyCell.Style.Font.FontColor = XLColor.White;
        keyCell.Style.Fill.BackgroundColor = XLColor.Navy;
        Cell0(ws, row, 1).Value = value ?? "";
        return row + 1;
    }

    private static void WriteHeaderCell(IXLWorksheet ws, int row, int col, string text)
    {
        var cell = Cell0(ws, row, col);
        cell.Value = text;
        cell.Style.Font.Bold = true;
        cell.Style.Font.FontColor = XLColor.White;
        cell.Style.Fill.BackgroundColor = XLColor.Navy;
    }
}
