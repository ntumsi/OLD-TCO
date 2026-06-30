using System.Drawing;
using System.Reflection;
using AMCOS.Logic.Attributes;
using Aspose.Cells;

namespace AMCOS.Web.Core.Pages.App.CivilianPcs;

/// <summary>
/// Attribute-driven Excel exporter for the Civilian PCS calculator. Ported from the legacy
/// AMCOS.Logic.Helpers.ExportHelper (which is excluded from the Core build because AMCOS.Logic has
/// no Aspose reference). It walks the data object's <see cref="ForExport"/> / <see cref="ExportIf"/>
/// attributes to build one worksheet per section, with label/value pairs and per-component tables —
/// matching the legacy report instead of a flat totals dump.
/// </summary>
public static class CivPcsExportHelper
{
    public static void ExportToExcel(Stream stream, object data, string title)
    {
        if (data == null)
            return;

        // The bundled Aspose.Cells.lic predates the Aspose DLL build and SetLicense throws on it;
        // an expired/missing license must not abort the export (Aspose falls back to evaluation mode).
        try
        {
            if (System.IO.File.Exists("Licenses/Aspose.Cells.lic"))
                new License().SetLicense("Licenses/Aspose.Cells.lic");
        }
        catch { /* evaluation mode */ }

        var workbook = new Workbook();

        var sections = GetDataSetFromObject(data).ToList();
        for (int x = 0; x < sections.Count(); x++)
        {
            var idx = 0;
            if (x > 0)
                workbook.Worksheets.Add();
            var worksheet = workbook.Worksheets[x];
            worksheet.Name = SanitizeSheetName(sections[x].Key);
            // Title row
            worksheet.Cells[idx, 0].PutValue(title);
            var styleFlag = GetStyleFlag();
            worksheet.Cells.CreateRange(0, 0, 1, 4).ApplyStyle(CreateTitleStyle(workbook), styleFlag);
            worksheet.Cells.Merge(0, 0, 1, 4);
            // Section title
            worksheet.Cells[++idx, 0].PutValue(sections[x].Key);
            worksheet.Cells.CreateRange(idx, 0, 1, 1).ApplyStyle(CreateSectionHeaderStyle(workbook), styleFlag);
            var values = sections[x].Value.Values.ToList();
            idx++;
            var startRow = idx + 1;
            for (int y = 0; y < values.Count(); y++)
            {
                worksheet.Cells[++idx, 0].PutValue(values[y].Key);
                AddValueToCell(worksheet.Cells[idx, 1], values[y].Value);
                worksheet.Cells.CreateRange(idx, 0, 1, 2).ApplyStyle(CreateLabelValueStyle(workbook), styleFlag);
            }
            worksheet.Cells.CreateRange(startRow, 0, ++idx - startRow, 2).SetOutlineBorders(CellBorderType.Double, Color.DarkGray);

            var tables = sections[x].Value.Tables.ToList();
            for (int y = 0; y < tables.Count(); y++)
            {
                worksheet.Cells[++idx, 0].PutValue(tables[y].Key);
                var columns = tables[y].Value.Columns.ToList();
                for (int colIdx = 0; colIdx < columns.Count(); colIdx++)
                {
                    worksheet.Cells[idx, colIdx + 1].PutValue(columns[colIdx]);
                }
                worksheet.Cells.CreateRange(idx, 0, 1, columns.Count() + 1).ApplyStyle(CreateHeaderStyle(workbook), styleFlag);
                worksheet.Cells.CreateRange(idx + 1, 0, tables[y].Value.Rows.Count(), columns.Count() + 1).ApplyStyle(CreateRowHeaderStyle(workbook), styleFlag);
                foreach (var row in tables[y].Value.Rows)
                {
                    worksheet.Cells[++idx, 0].PutValue(row.Key);
                    for (int c = 0; c < columns.Count(); c++)
                    {
                        var value = row.Value[columns[c]];
                        AddValueToCell(worksheet.Cells[idx, c + 1], value);
                    }
                }
                idx++;
            }
            worksheet.AutoFitColumns();
        }

        workbook.Save(stream, SaveFormat.Xlsx);
        stream.Position = 0;
    }

    private static string SanitizeSheetName(string name)
    {
        if (string.IsNullOrWhiteSpace(name)) return "Sheet";
        foreach (var c in new[] { '\\', '/', '?', '*', '[', ']', ':' })
            name = name.Replace(c, ' ');
        return name.Length > 31 ? name[..31] : name;
    }

    private static void AddValueToCell(Cell cell, object value)
    {
        cell.PutValue(value);
        if (value?.GetType() == typeof(decimal))
        {
            var style = cell.GetStyle();
            style.Number = 39;
            cell.SetStyle(style);
        }
    }

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

    private static Style CreateHeaderStyle(Workbook workbook)
    {
        var style = workbook.CreateStyle();
        SetThinBorders(style);
        style.Number = 0;
        style.Font.IsBold = true;
        style.Font.Size = 12;
        style.Font.Color = Color.White;
        style.ForegroundColor = Color.Black;
        style.Pattern = BackgroundType.Solid;
        style.ShrinkToFit = true;
        style.HorizontalAlignment = TextAlignmentType.Center;
        return style;
    }

    private static Style CreateSectionHeaderStyle(Workbook workbook)
    {
        var style = workbook.CreateStyle();
        style.Number = 0;
        style.Font.IsBold = true;
        style.Font.Size = 14;
        style.Font.Color = Color.Black;
        style.ForegroundColor = Color.White;
        style.Pattern = BackgroundType.Solid;
        style.ShrinkToFit = true;
        style.HorizontalAlignment = TextAlignmentType.Left;
        return style;
    }

    private static Style CreateRowHeaderStyle(Workbook workbook)
    {
        var style = workbook.CreateStyle();
        SetThinBorders(style);
        style.Number = 0;
        style.Font.IsBold = false;
        style.Font.Size = 12;
        style.Font.Color = Color.Black;
        style.ForegroundColor = Color.LightGray;
        style.Pattern = BackgroundType.Solid;
        style.ShrinkToFit = true;
        style.HorizontalAlignment = TextAlignmentType.Left;
        return style;
    }

    private static Style CreateLabelValueStyle(Workbook workbook)
    {
        var style = workbook.CreateStyle();
        style.Borders.SetColor(Color.DarkGray);
        style.Number = 0;
        style.Font.IsBold = false;
        style.Font.Size = 12;
        style.Font.Color = Color.Black;
        style.ForegroundColor = Color.LightGray;
        style.Pattern = BackgroundType.Solid;
        style.ShrinkToFit = true;
        style.HorizontalAlignment = TextAlignmentType.Left;
        return style;
    }

    private static Style CreateTitleStyle(Workbook workbook)
    {
        var style = workbook.CreateStyle();
        SetThinBorders(style);
        style.Number = 0;
        style.Font.IsBold = true;
        style.Font.Size = 16;
        style.Font.Color = Color.White;
        style.ForegroundColor = Color.DarkGreen;
        style.Pattern = BackgroundType.Solid;
        style.ShrinkToFit = true;
        style.HorizontalAlignment = TextAlignmentType.Left;
        return style;
    }

    private static void SetThinBorders(Style style)
    {
        style.Borders[BorderType.TopBorder].LineStyle = CellBorderType.Thin;
        style.Borders[BorderType.BottomBorder].LineStyle = CellBorderType.Thin;
        style.Borders[BorderType.LeftBorder].LineStyle = CellBorderType.Thin;
        style.Borders[BorderType.RightBorder].LineStyle = CellBorderType.Thin;
    }

    private static StyleFlag GetStyleFlag() => new()
    {
        Borders = true,
        FontBold = true,
        FontColor = true,
        FontSize = true,
        CellShading = true,
        HorizontalAlignment = true
    };

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