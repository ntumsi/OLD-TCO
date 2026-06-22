using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using System.Web.Mvc;

namespace AMCOS.Tests
{
    public class MockActionDescriptor : ActionDescriptor
    {
        private ParameterDescriptor[] _parameters = new ParameterDescriptor[] { };
        private Controller _controller;
        
        public MockActionDescriptor(string actionName, Controller controller)
        {
            ActionName = actionName;
            _controller = controller;
            ControllerDescriptor = new MockControllerDescriptor(controller, this);
        }
        public override string ActionName { get; }

        public override ControllerDescriptor ControllerDescriptor { get; }

        public override object Execute(ControllerContext controllerContext, IDictionary<string, object> parameters)
        {
            return null;
        }

        public override ParameterDescriptor[] GetParameters()
        {
            return _parameters;
        }
        public override object[] GetCustomAttributes(bool inherit)
        {
            return System.Attribute.GetCustomAttributes(_controller.GetType().GetMember(ActionName).FirstOrDefault(), inherit);
        }
        public override object[] GetCustomAttributes(Type attributeType, bool inherit)
        {
            return System.Attribute.GetCustomAttributes(_controller.GetType().GetMethod(ActionName), attributeType, inherit);
        }
    }
    public class MockControllerDescriptor : ControllerDescriptor
    {
        private Controller _controller;
        private List<ActionDescriptor> _actionDescriptor = new List<ActionDescriptor>();
        public MockControllerDescriptor(Controller controller, ActionDescriptor actionDescriptor)
        {
            _controller = controller;
            _actionDescriptor.Add(actionDescriptor);
        }
        public override Type ControllerType => _controller.GetType();

        public override ActionDescriptor FindAction(ControllerContext controllerContext, string actionName)
        {
            return _actionDescriptor.Where(a => a.ActionName == actionName).FirstOrDefault();
        }

        public override ActionDescriptor[] GetCanonicalActions()
        {
            return _actionDescriptor.ToArray();
        }
        public override object[] GetCustomAttributes(bool inherit)
        {
            return System.Attribute.GetCustomAttributes(_controller.GetType(), inherit);
        }
        public override object[] GetCustomAttributes(Type attributeType, bool inherit)
        {
            return System.Attribute.GetCustomAttributes(_controller.GetType(), attributeType, inherit);
        }
    }
}
