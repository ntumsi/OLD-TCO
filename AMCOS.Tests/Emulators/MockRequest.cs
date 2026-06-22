using AMCOS.Data.Entities;
using AMCOS.Logic.Controllers;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using System.Web.Mvc;
using System.Web.Routing;

namespace AMCOS.Tests
{
    public static class MockRequest
    {
        /// <summary>
        /// Mimics the behavior of the mvc controller.  Returns the View Model specified by the generic type.  
        /// Null is returned if the model cannot be converted, or a result is returned by the basecontroller. 
        /// </summary>
        /// <typeparam name="T"></typeparam>
        /// <param name="controller"></param>
        /// <param name="action"></param>
        /// <param name="user"></param>
        /// <returns></returns>
        public static T GetViewModel<T>(BaseController controller, string action, AMCOSUser user, object[] parameters = null) where T : class
        {
            var controllerName = controller.GetType().Name;
            controllerName = controllerName.Substring(0, controllerName.IndexOf("Controller"));
            var routeData = new RouteData();
            routeData.Values.Add("action", action);
            routeData.Values.Add("controller", controllerName);
            controller.ControllerContext = new ControllerContext(new MockHttpContext(user.ArmyAccountType, user.ArmyRank, user.Email, user.UserId, user.UserRole, routeData), routeData, controller);
            controller.CurrentUser = user;
            var basecontroller = new MockBaseController();
            var actionExecuting = new ActionExecutingContext(controller.ControllerContext, new MockActionDescriptor(action, controller), new Dictionary<string, object>());
            basecontroller.MockOnActionExecuting(actionExecuting);
            if (actionExecuting.Result != null)
                return null;
            else
                return (controller.GetType().GetMethod(action).Invoke(controller, parameters) as ViewResult)?.Model as T;
        }
    }
}
