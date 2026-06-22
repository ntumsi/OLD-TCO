using AMCOS.Logic.ViewModels;
using System.Web.Mvc;

namespace AMCOS.Logic.Controllers
{
    [Route("Help/{action}")]
    public class HelpController : BaseController
    {
        public ActionResult DataRequest()
        {            
            return View("DataRequest", new HelpViewModel(CurrentUser));
        }

    }
}
