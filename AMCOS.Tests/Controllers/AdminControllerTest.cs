using Microsoft.VisualStudio.TestTools.UnitTesting;
using System;
using System.Collections.Generic;
using System.Linq;
using AMCOS.Logic.ViewModels;
using AMCOS.Logic;
using AMCOS.Logic.Controllers;
using AMCOS.Logic.Helpers;

namespace AMCOS.Tests.Controllers
{
    [TestClass]
    public class AdminControllerTest
    {
        private Dictionary<string, Guid> _userIds = new Dictionary<string, Guid>();

        
        [TestMethod]
        public void GetViewModelForCostCompareNew_AdminUser_ReturnsModel()
        {
            var controller = new AdminController();
          
            //Ensure the CostCompare model is returned for an admin user
            _userIds.Add("TestAdmin", Guid.NewGuid());
            var testAdmin = TestMethods.AddAmcosUser(_userIds["TestAdmin"].ToString(), "First", "Last", "test.admin@mail.mil", "Active", DateTime.Now, null, null, "Admin");            
            var model = MockRequest.GetViewModel<VisualizationViewModel>(controller, "CostCompareNew", testAdmin);
            Assert.IsNotNull(model);
        }

        [TestMethod]
        public void GetViewModelForCostCompareNew_NotAdminUser_DoesNotReturnModel()
        {
            var controller = new AdminController();

            //Ensure that the CostCompare model is not returned for a standard user
            _userIds.Add("TestUser", Guid.NewGuid());
            var testUser = TestMethods.AddAmcosUser(_userIds["TestUser"].ToString(), "First", "Last", "test.user@mail.mil", "Active", DateTime.Now);
            var model = MockRequest.GetViewModel<VisualizationViewModel>(controller, "CostCompareNew", testUser);
            Assert.IsNull(model);
        }
        /// <summary>
        /// If test fails please ensure permissions are set up.  If debugging locally create an AWS Access Key.
        /// Run the following: rundll32 sysdm.cpl,EditEnvironmentVariables to edit your user specific environment variables.
        /// Add new variables: AWS_ACCESS_KEY_ID, and AWS_SECRET_ACCESS_KEY and add your values.
        /// Restart VS
        /// </summary>
        [TestMethod]
        public void GetHelpSpotFile()
        {
            var controller = new AdminController();
            
            _userIds.Add("TestAdmin", Guid.NewGuid());
            var testAdmin = TestMethods.AddAmcosUser(_userIds["TestAdmin"].ToString(), "First", "Last", "test.admin@mail.mil", "Active", DateTime.Now, null, null, "Admin");
            var results = AthenaHelper.ExecuteQuery("Select document_xdocumentid from helpspot.helpspot_flat where document_xdocumentid is not null LIMIT 1", "helpspot");
            var dataRow = results.ResultSet.Rows[1];
            string testid = dataRow.Data[0].VarCharValue;
            var result = controller.GetHelpSpotFile(Convert.ToInt32(testid));
            Assert.IsNotNull(result);
        }
        /// <summary>
        /// If test fails please ensure permissions are set up.  If debugging locally create an AWS Access Key.
        /// Run the following: rundll32 sysdm.cpl,EditEnvironmentVariables to edit your user specific environment variables.
        /// Add new variables: AWS_ACCESS_KEY_ID, and AWS_SECRET_ACCESS_KEY and add your values.
        /// Restart VS
        /// </summary>
        [TestMethod]
        public void HelpSpotDataTest()
        {
            var controller = new AdminController();
            
            _userIds.Add("TestAdmin", Guid.NewGuid());
            var testAdmin = TestMethods.AddAmcosUser(_userIds["TestAdmin"].ToString(), "First", "Last", "test.admin@mail.mil", "Active", DateTime.Now, null, null, "Admin");
            var model = MockRequest.GetViewModel<VisualizationViewModel>(controller, "CostCompareNew", testAdmin);
            Assert.IsNotNull(model);
        }

        [TestCleanup]
        public void TestCleanup()
        {            
            _userIds.Values?.ToList().ForEach(v => DataAccessUtility.GetScalarByStaticSql("DELETE FROM webuser.User_Login_History where UserID=@uid", new string[] { "@uid" }, new string[] { v.ToString() }));
            _userIds.Values?.ToList().ForEach(v => TestMethods.DeleteUserById(v.ToString()));
        }
    }
}
