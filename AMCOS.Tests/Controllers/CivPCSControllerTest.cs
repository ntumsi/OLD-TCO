using Microsoft.VisualStudio.TestTools.UnitTesting;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Web.Mvc;
using AMCOS.Logic.ViewModels;
using AMCOS.Data.DataTransferObjects;
using AMCOS.Data.Entities;
using AMCOS.Data;
using System.Web.Routing;
using AMCOS.Tests;


namespace AMCOS.Logic.Controllers.Tests
{
    
    [TestClass]
    public class CivPCSControllerTest
    {
        private Dictionary<string, Guid> _userIds = new Dictionary<string, Guid>();
        private Dictionary<Guid, string[]> _projects = new Dictionary<Guid, string[]>();

        
        [TestMethod]
        public void IndexTest()
        {
            var controller = new CivPCSController();
            _userIds.Add("TestUser", Guid.NewGuid());
            controller.CurrentUser = TestMethods.AddAmcosUser(_userIds["TestUser"].ToString(), "Test", "User", "test.user@mail.mil", "Active", DateTime.Now);
            controller.ControllerContext = new ControllerContext(new MockHttpContext("CONTRACTOR", "Mr.", "test.user@mail.mil", _userIds["TestUser"].ToString()), new RouteData(), controller);            
            var result = controller.Index();
            var model = (result as ViewResult)?.Model as CivPcsViewModel;
            Assert.IsNotNull(model);            
            var mileage = model.Content[0] as CivPcsMileageViewModel;
            Assert.IsNotNull(mileage);
            Assert.IsTrue(mileage.YearList.Count() > 0);
            var houseHunting = model.Content[1] as CivPcsHouseHuntingViewModel;
            Assert.IsNotNull(houseHunting);
            Assert.IsTrue(houseHunting.SpousePerDiemRate > 0);
            var transportation = model.Content[2] as CivPcsTransportationViewModel;
            Assert.IsNotNull(transportation);
            Assert.IsTrue(transportation.PCSMaltRate > 0 && transportation.TransportationVersionYear > 0);
            var tqse = model.Content[3] as CivPcsTqseViewModel;
            Assert.IsNotNull(tqse);
            Assert.IsTrue(tqse.TQSEPerDiemRate > 0 && tqse.TQSESpousePerDiemRate > 0);
            var goodshometransport = model.Content[4] as CivPcsGoodsHomeTransportation;
            Assert.IsNotNull(goodshometransport);
            Assert.IsTrue(goodshometransport.HHGTransportationModel != null && goodshometransport.HomeTranportationModel != null);
            Assert.IsTrue(goodshometransport.HHGTransportationModel.HHGMaxWeight > 0);
            Assert.IsTrue(goodshometransport.HHGTransportationModel.HHGEstimatedCostPerMile > 0 && goodshometransport.HHGTransportationModel.HHGEstimatedCostPerPound > 0);
            Assert.IsTrue(goodshometransport.HomeTranportationModel.MobileHomeEstCostPerMile > 0);
            var meaModel = model.Content[5] as CivPcsMeaViewModel;
            Assert.IsNotNull(meaModel);
            Assert.IsTrue(meaModel.MEACivilian > 0 && meaModel.MEACivilianAndSpouse > 0);
            var realEstate = model.Content[6] as CivPcsRealEstateLease;
            Assert.IsNotNull(realEstate);
            Assert.IsTrue(realEstate.RealEstateModel != null && realEstate.LeaseModel != null);
            Assert.IsTrue(realEstate.RealEstateLeaseTotal == 0 && realEstate.RealEstateOrLease == "RealEstate");
            Assert.IsTrue(realEstate.LeaseModel.UELAmount == 0 && realEstate.LeaseModel.UELTotal == 0);
            Assert.IsTrue(realEstate.RealEstateModel.SalePriceAmount == 0 && realEstate.RealEstateModel.PurchasePriceAmount == 0 && realEstate.RealEstateModel.SalePriceAmount == 0);
            var nts = model.Content[7] as CivPcsNtsViewModel;
            Assert.IsNotNull(nts);
            Assert.IsTrue(nts.NTSSubtotal == 0);
            var rita = model.Content[8] as CivPcsRitaViewModel;
            Assert.IsNotNull(rita);
            Assert.IsTrue(rita.FederalTaxRate > 0 && rita.DefaultFederalTaxRate > 0);
            Assert.IsTrue(rita.RITASubtotal == 0);
            var grandtotal = model.Content[9] as CivPcsGrandTotalViewModel;
            Assert.IsNotNull(grandtotal);
            Assert.IsTrue(grandtotal.GrandTotal == 0); 

        }
        [TestMethod]
        public void GetAllLocationsTest()
        {
            var controller = new CivPCSController();
            var result = controller.GetAllLocations(202101);
            var data = result.Data as IEnumerable<LocationDto>;
            Assert.IsTrue(data.Count() > 40000);
        }
        [TestMethod]
        public void GetSpecificLocationsTest()
        {
            var controller = new CivPCSController();
            var locations = controller.GetAllLocations(202101);
            var data = locations.Data as IEnumerable<LocationDto>;
            var originationId = Convert.ToInt32(data.Where(s => s.Text.IndexOf("Denver") == 0).FirstOrDefault().Value);
            var destinationId = Convert.ToInt32(data.Where(d => d.Text.IndexOf("Pittsfield") == 0).FirstOrDefault().Value);
            var result = controller.GetSpecificLocations(202101, originationId, destinationId);
            var specificData = result.Data as IEnumerable<LocationDto>;
            Assert.IsTrue(specificData.Count() == 2);
        }
        [TestMethod]
        public void GetCivPCSLocationsTest()
        {
            var controller = new CivPCSController();
            var result = controller.GetLocations(202101, "A");
            var data = result.Data as IEnumerable<LocationDto>;
            Assert.IsTrue(data.Count() >= 500);
        }
        [TestMethod]
        public void GetYearListTest()
        {
            var controller = new CivPCSController();
            var result = controller.GetYearList(202101, "ThenToThen", "OMA");
            var data = result.Data as IEnumerable<SelectListItem>;
            Assert.IsTrue(data.Count() > 0);
        }
        [TestMethod]
        public void SaveProjectOpenProjectExportProjectTest()
        {
            _userIds.Add("TestUser", Guid.NewGuid());
            var user = TestMethods.AddAmcosUser(_userIds["TestUser"].ToString(), "Test", "User", "test.user@mail.mil", "Active", DateTime.Now);
            var controller = new CivPCSController();
            controller.CurrentUser = user;
            controller.ControllerContext = new ControllerContext(new MockHttpContext("CONTRACTOR", "Mr.", "test.user@mail.mil", _userIds["TestUser"].ToString()), new RouteData(), controller);
            var locations = controller.GetAllLocations(202101);
            var data = locations.Data as IEnumerable<LocationDto>;
            var originationId = Convert.ToInt32(data.Where(s => s.Text.IndexOf("Denver") == 0).FirstOrDefault().Value);
            var destinationId = Convert.ToInt32(data.Where(d => d.Text.IndexOf("Pittsfield") == 0).FirstOrDefault().Value);

            //Create mock user input
            var inputJson = new CivPcsJson()
            {
                AmcosVersionId = 202101,
                InitialState = true,
                LocationChanged = true,
                ProjectSaveDate = DateTime.Now,
                ProjectName = "TestProject",
                OriginationId = originationId,
                DestinationId = destinationId,
                ConversionType = "ThenToThen",
                Appropriation = "OMA",
                Year = 2021,
                HouseHuntingHaveSpouse = true,
                NumberOfDaysHunting = 2,
                TransportationDependents = 1,
                TQSEDependents = 1,
                NumberDaysTQSE = 2,
                MEAHasSpouse = true,
                TransportationType = "Goods",
                IsIsolatedDutyStation = true,
            };
            _projects.Add(_userIds["TestUser"], new string[] {inputJson.ProjectName });
            controller.SaveProject(inputJson);
            
            //Verify saved data
            var project = controller.OpenProject(inputJson.ProjectName).Data as CivPcsJson;
            Assert.IsNotNull(project);
            Assert.IsTrue(project.AmcosVersionId == inputJson.AmcosVersionId);
            Assert.IsTrue(project.OriginationId == inputJson.OriginationId);
            Assert.IsTrue(project.DestinationId == inputJson.DestinationId);
            Assert.IsTrue(project.ConversionType == inputJson.ConversionType);
            Assert.IsTrue(project.NumberOfDaysHunting == 2);
            Assert.IsTrue(project.TransportationType == "Goods");
            Assert.IsTrue(project.CalculatedDistance > 0);
            Assert.IsTrue(project.HouseHuntingTotal > 0);
            Assert.IsTrue(project.TransportationSubTotal > 0);
            Assert.IsTrue(project.TQSETotal > 0);
            Assert.IsTrue(project.GHTransportationTotal > 0);
            Assert.IsTrue(project.RealEstateLeaseTotal > 0);
            Assert.IsTrue(project.NTSSubtotal > 0);
            Assert.IsTrue(project.RITASubtotal > 0);
            Assert.IsTrue(project.GrandTotal > 0);            

            //Verify the export function works
            var export = controller.Export(inputJson.ProjectName);
            Assert.IsNotNull(export);
            Assert.IsTrue(export.FileDownloadName == inputJson.ProjectName + ".xlsx");
         
        }
        [TestMethod]
        public void DeleteProjectTest()
        {
            _userIds.Add("DeleteProjectUser", Guid.NewGuid());
            var user = TestMethods.AddAmcosUser(_userIds["DeleteProjectUser"].ToString(), "Test", "User", "test.user@mail.mil", "Active", DateTime.Now);
            var controller = new CivPCSController();
            controller.CurrentUser = user;
            controller.ControllerContext = new ControllerContext(new MockHttpContext("CONTRACTOR", "Mr.", "test.user@mail.mil", _userIds["DeleteProjectUser"].ToString()), new RouteData(), controller);
            //Create the project
            var projectName = "DeleteProjectTest";
            _projects.Add(_userIds["DeleteProjectUser"], new string[] { projectName });
            CreatePCSProject(controller, projectName);
            //Retrieve the project
            var project = GetPCSProject(_userIds["DeleteProjectUser"].ToString(), projectName);
            //Verify that project deleted property is false
            Assert.IsTrue(project.Deleted == false);
            //Set Project to deleted
            controller.DeleteProject(projectName, "ProjectName", "asc");
            //Verify that project deleted property is true
            project = GetPCSProject(_userIds["DeleteProjectUser"].ToString(), projectName);
            Assert.IsTrue(project.Deleted == true);
        }
        [TestMethod]
        public void SortProjectsTest()
        {
            //Create the user and set the controller context to the created user
            _userIds.Add("SortTestUser", Guid.NewGuid());
            var user = TestMethods.AddAmcosUser(_userIds["SortTestUser"].ToString(), "Test", "User", "test.user@mail.mil", "Active", DateTime.Now);
            var controller = new CivPCSController();
            controller.CurrentUser = user;
            controller.ControllerContext = new ControllerContext(new MockHttpContext("CONTRACTOR", "Mr.", "test.user@mail.mil", _userIds["SortTestUser"].ToString()), new RouteData(), controller);
            //Create the projects
            var projectName1 = "SortTest1";
            var projectName2 = "SortTest2";
            _projects.Add(_userIds["SortTestUser"], new string[] { projectName1, projectName2 });
            CreatePCSProject(controller, projectName1);
            CreatePCSProject(controller, projectName2);
            //Verify that the sort algorithm works
            var data = controller.SortProjects("ProjectName", "Asc").Data as List<Tuple<string, DateTime>>;
            Assert.IsNotNull(data);
            Assert.IsTrue(data[0].Item1 == projectName1);
            data = controller.SortProjects("ProjectName", "desc").Data as List<Tuple<string, DateTime>>;
            Assert.IsNotNull(data);
            Assert.IsTrue(data[0].Item1 == projectName2);
        }
        private void CreatePCSProject(CivPCSController controller, string projectName)
        {
            var locations = controller.GetAllLocations(202101);
            var data = locations.Data as IEnumerable<LocationDto>;
            var originationId = Convert.ToInt32(data.Where(s => s.Text.IndexOf("Denver") == 0).FirstOrDefault().Value);
            var destinationId = Convert.ToInt32(data.Where(d => d.Text.IndexOf("Pittsfield") == 0).FirstOrDefault().Value);

            //Create mock user input
            var inputJson = new CivPcsJson()
            {
                AmcosVersionId = 202101,
                InitialState = true,
                LocationChanged = true,
                ProjectSaveDate = DateTime.Now,
                ProjectName = projectName,
                OriginationId = originationId,
                DestinationId = destinationId,
                ConversionType = "ThenToThen",
                Appropriation = "OMA",
                Year = 2021,
                HouseHuntingHaveSpouse = true,
                NumberOfDaysHunting = 2,
                TransportationDependents = 1,
                TQSEDependents = 1,
                NumberDaysTQSE = 2,
                MEAHasSpouse = true,
                TransportationType = "Goods",
                IsIsolatedDutyStation = true,
            };
            
            controller.SaveProject(inputJson);
        }
       
        private PCSProject GetPCSProject(string userId, string projectName)
        {
            using (var context = new ApplicationDbContext())
            {
                return context.PCSProject.AsNoTracking().Where(p => p.UserId == userId && p.ProjectName == projectName).FirstOrDefault();
            }
        }
        
        [TestMethod]
        public void CalculateAllTest()
        {
            _userIds.Add("TestUser", Guid.NewGuid());
            TestMethods.AddAmcosUser(_userIds["TestUser"].ToString(), "Test", "User", "test.user@mail.mil", "Active", DateTime.Now);
            var controller = new CivPCSController();
            controller.ControllerContext = new ControllerContext(new MockHttpContext("CONTRACTOR", "Mr.", "test.user@mail.mil", _userIds["TestUser"].ToString()), new RouteData(), controller);
            var locations = controller.GetAllLocations(202101);
            var data = locations.Data as IEnumerable<LocationDto>;
            var originationId = Convert.ToInt32(data.Where(s => s.Text.IndexOf("Denver") == 0).FirstOrDefault().Value);
            var destinationId = Convert.ToInt32(data.Where(d => d.Text.IndexOf("Pittsfield") == 0).FirstOrDefault().Value);
            var inputJson = new CivPcsJson()
            {
                AmcosVersionId = 202101,
                OriginationId = originationId,
                DestinationId = destinationId,
                ConversionType = "ThenToThen",
                Appropriation = "OMA",
                Year = 2021,
                LocationChanged = true,
                HouseHuntingHaveSpouse = true,
                NumberOfDaysHunting = 2,
                TransportationDependents = 1,
                TQSEDependents = 1,
                MEAHasSpouse = true,
                NumberDaysTQSE = 2,
                TransportationType = "Goods",
                RealEstateOrLease = "RealEstate",
                IsIsolatedDutyStation = false,
                InitialState = true,
            };
            var jsonResult = controller.CalculateAll(inputJson);
            var civPCSJson = jsonResult.Data as CivPcsJson;
            Assert.IsNotNull(civPCSJson);
            Assert.IsTrue(civPCSJson.CalculatedDistance > 0);
            Assert.IsTrue(civPCSJson.SelfLodgingPerDiem > 0);
            Assert.IsTrue(civPCSJson.SelfMIEPerDiem > 0);
            Assert.IsTrue(civPCSJson.SpouseLodgingPerDiem > 0);
            Assert.IsTrue(civPCSJson.SpouseMIEPerDiem > 0);
            Assert.IsTrue(civPCSJson.HouseHuntingTotal > 0);
            Assert.IsTrue(civPCSJson.TransportationSubTotal > 0);

            //Test TQSE
            Assert.IsTrue(civPCSJson.TQSEPerDiemRate > 0);
            Assert.IsTrue(civPCSJson.NumberDaysTQSE == 2);
            Assert.IsTrue(civPCSJson.TQSESelfPerDiemLodging > 0);
            Assert.IsTrue(civPCSJson.TQSESelfPerDiemMIE > 0);
            Assert.IsTrue(civPCSJson.TQSETotal > 0);

            //Test HHG
            Assert.IsTrue(civPCSJson.HHGCostByTotalMiles > 0);
            Assert.IsTrue(civPCSJson.HHGCostByTotalWeight > 0);
            Assert.IsTrue(civPCSJson.HHGEstimatedCostPerMile > 0);
            Assert.IsTrue(civPCSJson.HHGEstimatedCostPerPound > 0);
            Assert.IsTrue(civPCSJson.HHGMaxWeight > 0);
            Assert.IsTrue(civPCSJson.HHGTotalMileage > 0);
            Assert.IsTrue(civPCSJson.HHGTotalWeight > 0);
            Assert.IsTrue(civPCSJson.SubtotalHHG > 0);
            Assert.IsTrue(civPCSJson.GHTransportationTotal == civPCSJson.SubtotalHHG);

            //Test NTS
            Assert.IsTrue(civPCSJson.NTSSubtotal == 0);

            //Test Mobile Home
            inputJson.TransportationType = "Home";
            inputJson.LocationChanged = false;
            inputJson.IsIsolatedDutyStation = true;
            inputJson.IsIsolatedDutyStationChanged = true;
            jsonResult = controller.CalculateAll(inputJson);
            Assert.IsTrue(civPCSJson.MobileHomeEstCostPerMile > 0);
            Assert.IsTrue(civPCSJson.MobileHomeSubtotal > 0);
            Assert.IsTrue(civPCSJson.MobileHomeSubtotal == civPCSJson.GHTransportationTotal);

            //Test MEA
            Assert.IsTrue(civPCSJson.MEACivilian > 0 && civPCSJson.MEACivilianAndSpouse > 0);
            Assert.IsTrue(civPCSJson.MEASubtotal > 0);

            //Test RealEstate
            Assert.IsTrue(civPCSJson.PurchasePriceAmount > 0 && civPCSJson.SalePriceAmount > 0);
            Assert.IsTrue(civPCSJson.UELAmount > 0);
            Assert.IsTrue(civPCSJson.RealEstateSubtotal > 0);
            Assert.IsTrue(civPCSJson.RealEstateSubtotal == civPCSJson.RealEstateLeaseTotal);

            //Test NTS
            Assert.IsTrue(civPCSJson.NTSSubtotal > 0);

            //Test RITA
            Assert.IsTrue(civPCSJson.GHTransportationRITA > 0);
            Assert.IsTrue(civPCSJson.TransportationRITA > 0);
            Assert.IsTrue(civPCSJson.RealEstateLeaseRITA > 0);
            Assert.IsTrue(civPCSJson.HouseHuntingRITA > 0);
            Assert.IsTrue(civPCSJson.NTSRITA > 0);
            Assert.IsTrue(civPCSJson.MEARITA > 0);
            Assert.IsTrue(civPCSJson.RITASubtotal > 0);

            //Test GrandTotal
            Assert.IsTrue(civPCSJson.GrandTotal > 0);

        }
        [TestCleanup]
        public void TestCleanup()
        {
            _projects.ToList().ForEach(v => {
                v.Value.ToList().ForEach(p => TestMethods.DeletePCSProject(v.Key.ToString(), p));                
                });
            _userIds.Values.ToList().ForEach(v => DataAccessUtility.GetScalarByStaticSql("DELETE FROM webuser.User_Login_History where UserID=@uid", new string[] { "@uid" }, new string[] { v.ToString() }));
            _userIds.Values.ToList().ForEach(v => TestMethods.DeleteUserById(v.ToString()));
        }
    }
}
