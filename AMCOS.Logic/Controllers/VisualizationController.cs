using AMCOS.Logic.ViewModels;
using System.Web.Mvc;

namespace AMCOS.Logic.Controllers
{
    // Local (non-QuickSight) visualizations. Each action scaffolds the chart shell — title,
    // chart type and axis labels — and leaves Categories/Series empty. Populate them (from a
    // query or the DataVisualization helper) to render real data; until then the view shows an
    // empty state. Rendering: Views/Shared/Visualization.vbhtml -> _LocalVisualization.vbhtml +
    // dist/js/local-visualization.js.
    [Route("Visualization/{action}")]
    public class VisualizationController : BaseController
    {
        public ActionResult LocalityRateByZipCode()
        {
            var model = new VisualizationViewModel(CurrentUser, "GS Locality Rates by ZIP Code")
                .AsChart("bar", "Locality", "Rate (%)");
            model.Description = "GS locality pay rate by area.";
            model.ValueFormat = ",.2f";
            // TODO: populate, e.g.
            //   model.Categories = localityNames;
            //   model.Series.Add(new VisualizationSeries("Rate", rates));
            return View("Visualization", model);
        }

        public ActionResult PaySchedule()
        {
            var model = new VisualizationViewModel(CurrentUser, "Pay Schedule")
                .AsChart("line", "Grade / Step", "Pay ($)");
            model.ValueFormat = "$,.0f";
            return View("Visualization", model);
        }

        public ActionResult Inventory()
        {
            var model = new VisualizationViewModel(CurrentUser, "Inventory")
                .AsChart("bar", "Grade", "Inventory (count)");
            model.Stacked = true;
            model.ValueFormat = ",.0f";
            return View("Visualization", model);
        }

        public ActionResult Xwalk()
        {
            var model = new VisualizationViewModel(CurrentUser, "Xwalk")
                .AsChart("bar", "Category", "Count");
            return View("Visualization", model);
        }
    }
}
