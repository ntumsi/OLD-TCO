using AMCOS.Logic;
using AMCOS.Logic.Controllers;
using AMCOS.Logic.ViewModels;
using AMCOS.Tests.Emulators;
using Microsoft.VisualStudio.TestTools.UnitTesting;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Web.Mvc;
using System.Web.Routing;

namespace AMCOS.Tests.Controllers
{
    [TestClass]
    public class HomeControllerTest
    {
        private HomeController _controller;
        private Dictionary<string, Guid> _userIds = new Dictionary<string, Guid>();
        [TestInitialize]
        public void TestInit() //TestContext
        {
            _userIds.Add("TestUser", Guid.NewGuid());
            _controller = new HomeController();
            _controller.CurrentUser = TestMethods.AddAmcosUser(_userIds["TestUser"].ToString(), "Test", "User", "test.user@mail.mil", "Active", DateTime.Now);
            var context = new MockHttpContext("CONTRACTOR", "Mr.", "test.user@mail.mil", _userIds["TestUser"].ToString());
            _controller.ControllerContext = new ControllerContext(context, new RouteData(), _controller);
            _controller.Url = new MockUrlHelper(new RequestContext(context, new RouteData()));            
        }
        [TestMethod]
        public void HomeTest()
        {
            var homeView = _controller.Index() as ViewResult;
            Assert.IsNotNull(homeView);
            var model = homeView.Model as HomeViewModel;
            Assert.IsNotNull(model);           
            Assert.IsFalse(string.IsNullOrWhiteSpace(model.ImageUrl));
        }
        [TestCleanup]
        public void TestCleanup()
        {
            _userIds.Values.ToList().ForEach(v => DataAccessUtility.GetScalarByStaticSql("DELETE FROM webuser.User_Login_History where UserID=@uid", new string[] { "@uid" }, new string[] { v.ToString() }));
            _userIds.Values.ToList().ForEach(v => TestMethods.DeleteUserById(v.ToString()));
        }
    }
}
