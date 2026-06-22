using AMCOS.Logic.ViewModels;
using System.Collections.Generic;
using System.Web.Mvc;
using AMCOS.Logic.Helpers;
using AMCOS.Data.DataTransferObjects;
using System.IO;

namespace AMCOS.Logic.Controllers
{
    [Route("Civilian/PCS/{action}")]
    public class CivPCSController : BaseController
    {
        public ActionResult Index()
        {
            return View(new CivPcsViewModel(PcsPropertyHelper.GetProjects(CurrentUser.UserId, "projectSaveDate", "desc"), CurrentUser));
        }
        [HttpPost]
        public JsonResult GetAllLocations(int amcosVersionId)
        {
            var json = Json(PcsPropertyHelper.GetAllCivPCSLocations(amcosVersionId));

            json.MaxJsonLength = int.MaxValue;
            return json;

        }
        [HttpPost]
        public JsonResult GetLocations(int amcosVersionId, string query)
        {
            if (string.IsNullOrWhiteSpace(query))
                query = "A";

            return Json(PcsPropertyHelper.GetCivPCSLocations(amcosVersionId, query));
        }
        [HttpPost]
        public JsonResult GetSpecificLocations(int amcosVersionId, int originationId, int destinationId)
        {
            List<LocationDto> locations = null;
            if (originationId > 0 || destinationId > 0)
            {
                locations = new List<LocationDto>();
                if (originationId > 0)
                {
                    var origin = PcsPropertyHelper.GetCivPCSLocationById(originationId, amcosVersionId);
                    if (origin != null)
                        locations.Add(origin);
                }
                if (destinationId > 0)
                {
                    var dest = PcsPropertyHelper.GetCivPCSLocationById(destinationId, amcosVersionId);
                    if (dest != null)
                        locations.Add(dest);
                }
            }
            return Json(locations);
        }

        /// <summary>
        /// Calculate all values and return as json string
        /// </summary>
        /// <param name="originationId"></param>
        /// <param name="destinationId"></param>
        /// <returns></returns>
        [HttpPost]
        public JsonResult CalculateAll(CivPcsJson jsonInput)
        {
            if (ModelState.IsValid)
            {
                PcsPropertyHelper.ProcessJsonInput(jsonInput);
                return JsonNet(jsonInput);
            }                
            else
                return JsonNet(jsonInput);
        }
        /// <summary>
        /// Get list of available jic inflation years based on selected amcosversionid, conversiontype and appropriation
        /// </summary>
        /// <param name="amcosVersionId"></param>
        /// <param name="conversionType"></param>
        /// <param name="appropriation"></param>
        /// <returns></returns>
        [HttpPost]
        public JsonResult GetYearList(int amcosVersionId, string conversionType, string appropriation)
        {
            return Json(PcsPropertyHelper.GetJicInflationRateYears(conversionType, appropriation, amcosVersionId));
        }
        /// <summary>
        /// Save pcsproject to webuser.PCSProject
        /// </summary>
        /// <param name="jsonInput"></param>
        /// <returns></returns>
        [HttpPost]
        public JsonResult SaveProject(CivPcsJson jsonInput)
        {
            PcsPropertyHelper.SaveProject(PcsPropertyHelper.ProcessJsonInput(jsonInput).ConvertToPCSProject(), CurrentUser.UserId);
            return JsonNet(PcsPropertyHelper.GetProjects(CurrentUser.UserId, jsonInput.ViewProjectsSortColumn, jsonInput.ViewProjectsSortOrder));
        }
        /// <summary>
        /// Retrieve saved pcsproject from webuser.PCSProject
        /// </summary>
        /// <param name="projectName"></param>
        /// <returns></returns>
        [HttpPost]
        public JsonResult OpenProject(string projectName)
        {
            var json = PcsPropertyHelper.OpenProject(projectName, CurrentUser.UserId);
            return JsonNet(json);
        }
        /// <summary>
        /// Export the Civilian PCS data to an excel document
        /// </summary>
        /// <param name="json"></param>
        /// <returns></returns>        
        public FileResult Export(string projectName)
        {
            var memoryStream = new MemoryStream();
            ExportHelper.ExportToExcel(memoryStream, PcsPropertyHelper.OpenProject(projectName, CurrentUser.UserId), "Civilian Permanent Change of Station");
            return File(memoryStream, "application/ms-excel", projectName + ".xlsx");
        }
        /// <summary>
        /// Sets project deleted boolean to true
        /// </summary>
        /// <param name="projectName"></param>
        /// <returns></returns>
        [HttpPost]
        public JsonResult DeleteProject(string projectName, string sortColumn, string sortOrder)
        {
            PcsPropertyHelper.SetProjectDeleted(projectName, CurrentUser.UserId);
            
            return JsonNet(PcsPropertyHelper.GetProjects(CurrentUser.UserId, sortColumn, sortOrder));
        }
        /// <summary>
        /// Returns a sorted list of saved project names and saved dates
        /// </summary>
        /// <param name="sortColumn"></param>
        /// <param name="sortOrder"></param>
        /// <returns></returns>
        [HttpPost]
        public JsonResult SortProjects(string sortColumn, string sortOrder)
        {
            return JsonNet(PcsPropertyHelper.GetProjects(CurrentUser.UserId, sortColumn, sortOrder));
        }
    }
}
