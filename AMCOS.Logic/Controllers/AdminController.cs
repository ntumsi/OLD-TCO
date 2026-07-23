using AMCOS.Logic.Attributes;
using AMCOS.Logic.Helpers;
using AMCOS.Logic.ViewModels;
using System.Configuration;
using System.Web.Mvc;
using Amazon.Athena.Model;
using System;
using System.Web;
using Aspose.Cells;


namespace AMCOS.Logic.Controllers
{
    [AdminOnly]
    [Route("Admin/{action}")]
    public class AdminController : BaseController
    {
        private readonly string _awsRegionCode = "us-gov-west-1";
        readonly string _awsAccountId = ConfigurationManager.AppSettings["AwsAccountId"];


        // Admin visualizations, now rendered as local (non-QuickSight) C3 charts. Each action
        // scaffolds the chart shell; populate Categories/Series (or the table) with a real query
        // to render data. Renders via Views/Shared/Visualization.vbhtml -> _LocalVisualization.

        public ActionResult AmcosLiteUsage()
        {
            var model = new VisualizationViewModel(CurrentUser, "AMCOS Lite Usage")
                .AsChart("line", "Date", "Sessions");
            // TODO: model.Categories = dates; model.Series.Add(new VisualizationSeries("Sessions", counts));
            return View("Visualization", model);
        }
        public ActionResult AmcosUserLogins()
        {
            var model = new VisualizationViewModel(CurrentUser, "AMCOS User Logins")
                .AsChart("line", "Date", "Logins");
            return View("Visualization", model);
        }
        public ActionResult AmcosUserApprovals()
        {
            var model = new VisualizationViewModel(CurrentUser, "AMCOS User Approvals")
                .AsChart("bar", "Date", "Approvals");
            return View("Visualization", model);
        }
        public ActionResult CurrentActiveAmcosUsers()
        {
            var model = new VisualizationViewModel(CurrentUser, "Current Active AMCOS Users")
                .AsChart("bar", "Account Type", "Users");
            return View("Visualization", model);
        }
        public ActionResult CostCompareNew()
        {
            var model = new VisualizationViewModel(CurrentUser, "Cost Compare")
                .AsChart("bar", "Grade", "Cost ($)");
            model.ValueFormat = "$,.0f";
            return View("Visualization", model);
        }

        public ActionResult HelpSpotData()
        {
            var model = new VisualizationViewModel(CurrentUser, "HelpSpot Data")
                .AsChart("bar", "Category", "Count");
            return View("Visualization", model);
        }
        public FileResult GetHelpSpotFile(int id, string table = "helpspot_flat")
        {
            // Get configuration values
            string databaseName = "helpspot";
            string tableName = table;
            string idColumn = "document_xdocumentid";
            string contentColumn = "document_blobfile";
            string fileNameColumn = "document_sfilename";
            string fileTypeColumn = "document_sfilemimetype";
            // Validate input first            
            if (tableName != "helpspot_flat" && tableName != "helpspot_flat_calibre")
            {
                throw new InvalidRequestException("Invalid table name");
            }

            // Create the SQL query
            string query = $"SELECT {contentColumn}, {fileNameColumn}, {fileTypeColumn} FROM {databaseName}.{tableName} WHERE {idColumn} = {id}";

            var results = AthenaHelper.ExecuteQuery(query, databaseName);

            // Check if we have results
            if (results.ResultSet.Rows.Count <= 1)
            {
                throw new HttpException(404, "File not found");
            }

            // Get file data
            //Row dataRow = results.ResultSet.Rows[1];
            Amazon.Athena.Model.Row dataRow = results.ResultSet.Rows[1];
            string base64Content = dataRow.Data[0].VarCharValue;
            string fileName = dataRow.Data[1].VarCharValue;
            string dataType = dataRow.Data[2].VarCharValue;

            // Decode base64
            byte[] fileBytes = Convert.FromBase64String(base64Content);

            // Return file
            return File(fileBytes, dataType, fileName);
        }
        public FileResult GetHelpSpotFileDetail(int id, string table = "helpspot_flat")
        {
            // Get configuration values
            string databaseName = "helpspot";
            string tableName = table;
            string idColumn = "request_xrequest";
            string contentColumn = "request_history_tnote";

            // Validate input first            
            if (tableName != "helpspot_flat" && tableName != "helpspot_flat_calibre")
            {
                throw new InvalidRequestException("Invalid table name");
            }

            // Create the SQL query
            string query = $"SELECT {contentColumn} FROM {databaseName}.{tableName} WHERE {idColumn} = {id}";

            var results = AthenaHelper.ExecuteQuery(query, databaseName);

            // Check if we have results
            if (results.ResultSet.Rows.Count <= 1)
            {
                throw new HttpException(404, "File not found");
            }
            Aspose.Cells.License license = new Aspose.Cells.License();
            license.SetLicense("Aspose.Cells.lic");
            // Create a new Excel package
            // Create a new workbook and worksheet
           
            Workbook workbook = new Workbook();
            Worksheet sheet = workbook.Worksheets[0];
            sheet.Name = "HelpSpot Data";

            // Add the headers
            sheet.Cells[0, 0].PutValue("NOTES");

            // Add the data
            for (int i = 1; i < results.ResultSet.Rows.Count; i++)
            {
                var dataRow = results.ResultSet.Rows[i];
                Cell cell = sheet.Cells[i, 0];

                cell.PutValue(dataRow.Data[0].VarCharValue);

                //apply text wrapping

                Style style = cell.GetStyle();
                style.IsTextWrapped = true;
                cell.SetStyle(style);

                //autofit row height
                sheet.AutoFitRow(i);
                  
            }
            sheet.AutoFitColumn(0);

            // Save the workbook to a memory stream
            var stream = new System.IO.MemoryStream();
            {
                string mimeType = "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet";
                string fileName = "HelpSpotData.xlsx";
                workbook.Save(stream, SaveFormat.Xlsx);
                var fileBytes = stream.ToArray();
               // System.Console.WriteLine(fileBytes.ToString());
                // Return the Excel file
                return File(fileBytes, mimeType, fileName);
            }

        }
    }
}
