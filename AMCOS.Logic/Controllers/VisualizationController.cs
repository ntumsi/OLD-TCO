using AMCOS.Logic.ViewModels;
using System.Configuration;
using System.Web.Mvc;

namespace AMCOS.Logic.Controllers
{
    [Route("Visualization/{action}")]
    public class VisualizationController : BaseController
    {
        readonly string awsAccountId = ConfigurationManager.AppSettings["AwsAccountId"];
        public ActionResult LocalityRateByZipCode()
        {
            string dashboardId = ConfigurationManager.AppSettings["GSLocalityRatesByZipCodeDashboardId"];
            string awsRegionCode = "us-gov-west-1";
            QuickSight quickSight = new QuickSight(awsAccountId, awsRegionCode);
            string url = quickSight.EmbedDashboard(dashboardId);
            return View("Visualization", new VisualizationViewModel(CurrentUser, url,"GS Locality Rates by ZIP Code", "_QuickSight"));
        }
        public ActionResult PaySchedule()
        {
            string dashboardId = ConfigurationManager.AppSettings["PayScheduleDashboardId"];
            string awsRegionCode = "us-gov-west-1";
            QuickSight quickSight = new QuickSight(awsAccountId, awsRegionCode);
            string url = quickSight.EmbedDashboard(dashboardId);
            return View("Visualization", new VisualizationViewModel(CurrentUser, url, "Pay Schedule", "_QuickSight"));
        }
        public ActionResult Inventory()
        {
            string dashboardId = ConfigurationManager.AppSettings["InventoryDashboardId"];
            string awsRegionCode = "us-gov-west-1";
            QuickSight quickSight = new QuickSight(awsAccountId, awsRegionCode);
            string url = quickSight.EmbedDashboard(dashboardId);
            return View("Visualization", new VisualizationViewModel(CurrentUser, url, "Inventory", "_QuickSight"));
        }
        public ActionResult Xwalk()
        {
            return View("UnderConstruction", new DefaultViewModel(CurrentUser));
            //string dashboardId = ConfigurationManager.AppSettings["XwalkDashboardId"];
            //string awsRegionCode = "us-gov-west-1";
            //QuickSight quickSight = new QuickSight(awsAccountId, awsRegionCode);
            //string url = quickSight.EmbedDashboard(dashboardId);
            //return View("Visualization", new VisualizationViewModel(CurrentUser, url, "Xwalk", "_QuickSight"));
        }
    }
}
