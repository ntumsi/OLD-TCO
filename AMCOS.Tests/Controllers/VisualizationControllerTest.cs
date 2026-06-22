using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using Microsoft.VisualStudio.TestTools.UnitTesting;
using AMCOS.Logic.Controllers;
using System.Web.Mvc;
using System.Web.Routing;
using AMCOS.Logic.ViewModels;
using AMCOS.Logic;

namespace AMCOS.Tests.Controllers
{
   
    [TestClass]
    public class VisualizationControllerTest
    {
        private VisualizationController _controller;
        private Dictionary<string, Guid> _userIds = new Dictionary<string, Guid>();
        public TestContext TestContext { get; set; }
        [TestInitialize]
        public void TestInit() //TestContext
        {
            _userIds.Add("TestUser", Guid.NewGuid());
            _controller = new VisualizationController();
            _controller.CurrentUser = TestMethods.AddAmcosUser(_userIds["TestUser"].ToString(), "Test", "User", "test.user@mail.mil", "Active", DateTime.Now);
            _controller.ControllerContext = new ControllerContext(new MockHttpContext("CONTRACTOR", "Mr.", "test.user@mail.mil", _userIds["TestUser"].ToString()), new RouteData(), _controller);
        }
        [TestMethod]
        public void InventoryTest()
        {
            var inventory = _controller.Inventory() as ViewResult;
            Assert.IsNotNull(inventory);
            var model = inventory.Model as VisualizationViewModel;
            Assert.IsNotNull(model);
            Assert.IsTrue(model.Url.Contains("dashboards/"));
            Assert.IsTrue(model.Url.Length > 25);
            Assert.IsTrue(model.Title == "Inventory");
            Assert.IsTrue(model.View == "_QuickSight");            
        }
        [Ignore]
        [TestMethod]
        public void XwalkTest()
        {
            var inventory = _controller.Xwalk() as ViewResult;
            Assert.IsNotNull(inventory);
            var model = inventory.Model as VisualizationViewModel;
            Assert.IsNotNull(model);
            Assert.IsTrue(model.Url.Contains("dashboards/"));
            Assert.IsTrue(model.Url.Length > 25);
            Assert.IsTrue(model.Title == "Xwalk");
            Assert.IsTrue(model.View == "_QuickSight");
        }

        [TestCleanup]
        public void TestCleanup()
        {
            _userIds.Values.ToList().ForEach(v => DataAccessUtility.GetScalarByStaticSql("DELETE FROM webuser.User_Login_History where UserID=@uid", new string[] { "@uid" }, new string[] { v.ToString() }));
            _userIds.Values.ToList().ForEach(v => TestMethods.DeleteUserById(v.ToString()));
        }
    }
}
