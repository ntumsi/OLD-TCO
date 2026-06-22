using AMCOS.Logic.ViewModels;
using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Net.Http;
using System.Text;
using System.Threading.Tasks;
using System.Web.Mvc;
using System.Web.UI;

namespace AMCOS.Logic.Controllers
{
    public class HomeController : BaseController
    {       
        [Route("home")]
        [Route("")]
        public ActionResult Index()
        {

            var files = Directory.GetFiles(Server.MapPath("~/dist/img/backgrounds/"), "*.png", SearchOption.TopDirectoryOnly);
            var idx = new Random().Next(1, files.Length + 1);
            var imgPath = Url.Content("~/dist/img/backgrounds/" + Path.GetFileName(files[idx - 1]));

            return View("Home", new HomeViewModel(CurrentUser, imgPath));          
       
        }
        
        [HttpPost]
        public JsonResult KeepAlive()
        {
            // The OWIN pipeline intercepts this request. Because the user is [Authorize]d,
            // and SlidingExpiration = true, OWIN will automatically issue a new cookie
            // with a fresh 10 or 15 minute lifespan.
            // We just need to return a simple 200 OK success status.
            return JsonNet(new BaseJson());
        }

    }
}
