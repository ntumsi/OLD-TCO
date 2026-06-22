using AMCOS.Logic.Controllers;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using System.Web.Mvc;

namespace AMCOS.Tests
{
    public class MockBaseController : BaseController
    {
        public void MockOnActionExecuting(ActionExecutingContext context)
        {
            this.OnActionExecuting(context);
        }
    }
}
