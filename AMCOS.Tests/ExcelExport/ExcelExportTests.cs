using System.Data;
using System.IO;
using System.Linq;
using AMCOS.Logic.ViewModels;
using AMCOS.Web.Core.Models;
using AMCOS.Web.Core.Pages.App.CivilianPcs;
using AMCOS.Web.Core.Pages.App.Lite;
using ClosedXML.Excel;
using Microsoft.VisualStudio.TestTools.UnitTesting;

namespace AMCOS.Tests.ExcelExport
{
    // Verifies the ClosedXML export helpers (which replaced Aspose.Cells) produce real,
    // re-openable .xlsx output. Re-opening the stream with ClosedXML validates the OOXML is
    // well-formed (catches bad addressing / invalid values that a byte-length check would miss).
    // No database or license required.
    [TestClass]
    public class ExcelExportTests
    {
        [TestMethod]
        public void CivPcsExport_ProducesValidXlsx()
        {
            using var stream = new MemoryStream();
            CivPcsExportHelper.ExportToExcel(stream, new CivPcsJson(), "Cost Estimate");

            Assert.IsTrue(stream.Length > 100, "No xlsx bytes were produced.");

            stream.Position = 0;
            using var workbook = new XLWorkbook(stream); // throws if the file is not a valid xlsx
            Assert.IsTrue(workbook.Worksheets.Count >= 1, "Workbook has no worksheets.");
        }

        [TestMethod]
        public void LiteExport_ProducesValidXlsxWithData()
        {
            var costs = new DataTable();
            costs.Columns.Add("Cost Element Name", typeof(string));
            costs.Columns.Add("appn", typeof(string));
            costs.Columns.Add("showorder", typeof(int));
            costs.Columns.Add("AE01", typeof(decimal));
            var cr = costs.NewRow();
            cr["Cost Element Name"] = "Base Pay";
            cr["appn"] = "MPA";
            cr["showorder"] = 1;
            cr["AE01"] = 1234.56m;
            costs.Rows.Add(cr);

            var inflation = new DataTable();
            inflation.Columns.Add("Inflation Rate", typeof(string));
            inflation.Columns.Add("2025", typeof(string));
            var ir = inflation.NewRow();
            ir["Inflation Rate"] = "Inflation Rate";
            ir["2025"] = "0.0231";
            inflation.Rows.Add(ir);

            var request = new LiteCostRequest { PayPlan = "AE", CostSummaryName = "Default" };
            var bytes = LiteExportHelper.Build(request, costs, inflation, cceMaxPayFootnote: 0m, defaultYear: 2025);

            Assert.IsTrue(bytes.Length > 100, "No xlsx bytes were produced.");

            using var workbook = new XLWorkbook(new MemoryStream(bytes));
            var sheet = workbook.Worksheets.First();
            Assert.AreEqual("AMCOS Lite", sheet.Name);
            // The banner text is written to the first cell.
            StringAssert.Contains(sheet.Cell(1, 1).GetString(), "UNCLASSIFIED");
        }
    }
}
