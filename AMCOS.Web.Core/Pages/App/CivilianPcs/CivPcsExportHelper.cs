using System.Reflection;
using AMCOS.Logic.Attributes;
using ClosedXML.Excel;

namespace AMCOS.Web.Core.Pages.App.CivilianPcs;

/// <summary>
/// Attribute-driven Excel exporter for the Civilian PCS calculator. Ported from the legacy
/// AMCOS.Logic.Helpers.ExportHelper. It walks the data object's <see cref="ForExport"/> /
/// <see cref="ExportIf"/> attributes to build one worksheet per section, with label/value pairs
/// and per-component tables — matching the legacy report instead of a flat totals dump.
///
/// Uses ClosedXML (MIT) rather than Aspose.Cells. Cell/range coordinates below are kept 0-based
/// (matching the original layout logic); <see cref="Cell0"/> / <see cref="Range0"/> convert to
/// ClosedXML's 1-based, inclusive addressing.
/// </summary>
public static class CivPcsExportHelper
{
    private const string AccountingFormat = "#,##0.00;(#,##0.00)";

    public static void ExportToExcel(Stream stream, object data, string title)
    {
        if (data == null)
            return;

        using var workbook = new XLWorkbook();

        var sections = GetDataSetFromObject(data).ToList();
        for (int x = 0; x < sections.Count; x++)
        {
            var idx = 0;
            var worksheet = workbook.Worksheets.Add(SanitizeSheetName(sections[x].Key));

            // Title row
            Cell0(worksheet, idx, 0).Value = title;
            ApplyTitleStyle(Range0(worksheet, 0, 0, 1, 4));
            Range0(worksheet, 0, 0, 1, 4).Merge();

            // Section title
            Cell0(worksheet, ++idx, 0).Value = sections[x].Key;
            ApplySectionHeaderStyle(Range0(worksheet, idx, 0, 1, 1));

            var values = sections[x].Value.Values.ToList();
            idx++;
            var startRow = idx + 1;
            for (int y = 0; y < values.Count; y++)
            {
                Cell0(worksheet, ++idx, 0).Value = values[y].Key;
                AddValueToCell(Cell0(worksheet, idx, 1), values[y].Value);
                ApplyLabelValueStyle(Range0(worksheet, idx, 0, 1, 2));
            }
            var labelBlock = Range0(worksheet, startRow, 0, ++idx - startRow, 2);
            labelBlock.Style.Border.OutsideBorder = XLBorderStyleValues.Double;
            labelBlock.Style.Border.OutsideBorderColor = XLColor.DarkGray;

            var tables = sections[x].Value.Tables.ToList();
            for (int y = 0; y < tables.Count; y++)
            {
                Cell0(worksheet, ++idx, 0).Value = tables[y].Key;
                var columns = tables[y].Value.Columns.ToList();
                for (int colIdx = 0; colIdx < columns.Count; colIdx++)
                    Cell0(worksheet, idx, colIdx + 1).Value = columns[colIdx];
                ApplyHeaderStyle(Range0(worksheet, idx, 0, 1, columns.Count + 1));
                ApplyRowHeaderStyle(Range0(worksheet, idx + 1, 0, tables[y].Value.Rows.Count, columns.Count + 1));
                foreach (var row in tables[y].Value.Rows)
                {
                    Cell0(worksheet, ++idx, 0).Value = row.Key;
                    for (int c = 0; c < columns.Count; c++)
                        AddValueToCell(Cell0(worksheet, idx, c + 1), row.Value[columns[c]]);
                }
                idx++;
            }
            worksheet.Columns().AdjustToContents();
        }

        // ClosedXML (unlike Aspose) refuses to save a workbook with no worksheets.
        if (!workbook.Worksheets.Any())
            workbook.Worksheets.Add("Export");

        workbook.SaveAs(stream);
        stream.Position = 0;
    }

    // ---- ClosedXML addressing helpers (0-based in, 1-based ClosedXML out) -------

    private static IXLCell Cell0(IXLWorksheet ws, int row, int col) => ws.Cell(row + 1, col + 1);

    private static IXLRange Range0(IXLWorksheet ws, int firstRow, int firstCol, int totalRows, int totalCols)
        => ws.Range(firstRow + 1, firstCol + 1, firstRow + totalRows, firstCol + totalCols);

    private static void AddValueToCell(IXLCell cell, object value)
    {
        SetCellValue(cell, value);
        if (value is decimal)
            cell.Style.NumberFormat.Format = AccountingFormat;
    }

    private static void SetCellValue(IXLCell cell, object value)
    {
        switch (value)
        {
            case null: break;
            case string s: cell.Value = s; break;
            case bool b: cell.Value = b; break;
            case DateTime dt: cell.Value = dt; break;
            case decimal dec: cell.Value = dec; break;
            case double d: cell.Value = d; break;
            case float f: cell.Value = f; break;
            case int i: cell.Value = i; break;
            case long l: cell.Value = l; break;
            case short sh: cell.Value = sh; break;
            case byte by: cell.Value = by; break;
            default: cell.Value = value.ToString(); break;
        }
    }

    private static string SanitizeSheetName(string name)
    {
        if (string.IsNullOrWhiteSpace(name)) return "Sheet";
        foreach (var c in new[] { '\\', '/', '?', '*', '[', ']', ':' })
            name = name.Replace(c, ' ');
        return name.Length > 31 ? name[..31] : name;
    }

    // ---- Styles (applied directly to a ClosedXML range) ------------------------

    private static void SetThinBorders(IXLRange range)
    {
        range.Style.Border.OutsideBorder = XLBorderStyleValues.Thin;
        range.Style.Border.InsideBorder = XLBorderStyleValues.Thin;
    }

    private static void ApplyHeaderStyle(IXLRange range)
    {
        SetThinBorders(range);
        range.Style.Font.Bold = true;
        range.Style.Font.FontSize = 12;
        range.Style.Font.FontColor = XLColor.White;
        range.Style.Fill.BackgroundColor = XLColor.Black;
        range.Style.Alignment.ShrinkToFit = true;
        range.Style.Alignment.Horizontal = XLAlignmentHorizontalValues.Center;
    }

    private static void ApplySectionHeaderStyle(IXLRange range)
    {
        range.Style.Font.Bold = true;
        range.Style.Font.FontSize = 14;
        range.Style.Font.FontColor = XLColor.Black;
        range.Style.Fill.BackgroundColor = XLColor.White;
        range.Style.Alignment.ShrinkToFit = true;
        range.Style.Alignment.Horizontal = XLAlignmentHorizontalValues.Left;
    }

    private static void ApplyRowHeaderStyle(IXLRange range)
    {
        SetThinBorders(range);
        range.Style.Font.Bold = false;
        range.Style.Font.FontSize = 12;
        range.Style.Font.FontColor = XLColor.Black;
        range.Style.Fill.BackgroundColor = XLColor.LightGray;
        range.Style.Alignment.ShrinkToFit = true;
        range.Style.Alignment.Horizontal = XLAlignmentHorizontalValues.Left;
    }

    private static void ApplyLabelValueStyle(IXLRange range)
    {
        range.Style.Border.OutsideBorderColor = XLColor.DarkGray;
        range.Style.Font.Bold = false;
        range.Style.Font.FontSize = 12;
        range.Style.Font.FontColor = XLColor.Black;
        range.Style.Fill.BackgroundColor = XLColor.LightGray;
        range.Style.Alignment.ShrinkToFit = true;
        range.Style.Alignment.Horizontal = XLAlignmentHorizontalValues.Left;
    }

    private static void ApplyTitleStyle(IXLRange range)
    {
        SetThinBorders(range);
        range.Style.Font.Bold = true;
        range.Style.Font.FontSize = 16;
        range.Style.Font.FontColor = XLColor.White;
        range.Style.Fill.BackgroundColor = XLColor.DarkGreen;
        range.Style.Alignment.ShrinkToFit = true;
        range.Style.Alignment.Horizontal = XLAlignmentHorizontalValues.Left;
    }

    // ---- Attribute-driven data extraction (unchanged) --------------------------

    private static Dictionary<string, Section> GetDataSetFromObject(object data)
    {
        var sections = new Dictionary<string, Section>();
        var properties = data.GetType().GetProperties();
        for (var x = 0; x < properties.Length; x++)
        {
            ForExport export = null;
            ExportIf exportIf = null;
            properties[x].GetCustomAttributes(false).ToList().ForEach(att =>
            {
                if (att.GetType() == typeof(ForExport))
                    export = att as ForExport;
                else if (att.GetType() == typeof(ExportIf))
                    exportIf = att as ExportIf;
            });
            if (exportIf != null && !exportIf.IsForExport(data))
                continue;
            if (export != null)
            {
                if (sections.TryGetValue(export.Section, out Section section))
                    AddToSections(export, section, properties[x], data);
                else
                {
                    var newSection = new Section();
                    sections.Add(export.Section, newSection);
                    AddToSections(export, newSection, properties[x], data);
                }
            }
        }
        return sections;
    }

    private static void AddToSections(ForExport export, Section section, PropertyInfo property, object data)
    {
        if (export.Label != null)
        {
            section.Values.Add(export.Label, property.GetValue(data));
        }
        else if (export.TableHeader != null)
        {
            if (section.Tables.TryGetValue(export.TableHeader, out Table table))
            {
                if (!table.Columns.Contains(export.ColumnHeader))
                    table.Columns.Add(export.ColumnHeader);
                if (table.Rows.TryGetValue(export.RowHeader, out Dictionary<string, object> row))
                    row.Add(export.ColumnHeader, property.GetValue(data));
                else
                {
                    var newRow = new Dictionary<string, object> { { export.ColumnHeader, property.GetValue(data) } };
                    table.Rows.Add(export.RowHeader, newRow);
                }
            }
            else
            {
                section.Tables.Add(export.TableHeader, new Table(export.RowHeader, export.ColumnHeader, property.GetValue(data)));
            }
        }
    }

    private class Section
    {
        public Dictionary<string, object> Values = new();
        public Dictionary<string, Table> Tables = new();
    }

    private class Table
    {
        public Table(string row, string column, object value)
        {
            Columns.Add(column);
            Rows.Add(row, new Dictionary<string, object> { { column, value } });
        }
        public Dictionary<string, Dictionary<string, object>> Rows { get; } = new();
        public List<string> Columns { get; } = new();
    }
}
