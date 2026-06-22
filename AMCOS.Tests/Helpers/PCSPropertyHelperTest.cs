using AMCOS.Data;
using AMCOS.Data.Entities;
using AMCOS.Logic;
using AMCOS.Logic.Helpers;
using Microsoft.VisualStudio.TestTools.UnitTesting;
using System;
using System.Collections.Generic;
using System.Configuration;
using System.Data;
using System.Data.SqlClient;
using System.Linq;


namespace AMCOS.Tests.Helpers
{
    [TestClass]
    public class PCSPropertyHelperTest
    {
        private Dictionary<string, Guid> _userIds = new Dictionary<string, Guid>();
        private Dictionary<Guid, string> _projects = new Dictionary<Guid, string>();
        [TestMethod]
        public void ProcessJsonInputTest()
        {
            var input = new Logic.ViewModels.CivPcsJson()
            {
                InitialState = true,
                AmcosVersionId = 202101,
                Year = 2021,
                Appropriation = "OMA",
                ConversionType = "ThenToThen",
                LocationChanged = true,
                NumberOfDaysHunting = 2,
                HouseHuntingHaveSpouse = true,
                POVMileage = 0,
                TransportationDependents = 1,
                TransportationSubTotal = 0,                
                NumberDaysTQSE = 2,
                TQSEDependents = 1,
                TransportationType = "Goods",
                MEAHasSpouse = true,
                HHGTotalMileage = 0,
                HHGTotalWeight = 0,
                MobileHomeTotalMileage = 0,
                MobileHomeEstCostPerMile = 0,
            };
            var json = PcsPropertyHelper.ProcessJsonInput(input);


            Assert.IsNotNull(json);
        }
        [TestMethod]
        public void CalculateDistanceTest()
        {
            var data = ExecuteSQL("SELECT LocationId FROM [warehouse].[Location] WHERE SourceSystemCode = '90210'");
            var originationId = Convert.ToInt32(data.Tables[0].Rows[0].ItemArray[0]);
            var origination = PcsPropertyHelper.GetCivLocationPerDiemById(originationId, 202101);
            data = ExecuteSQL("SELECT LocationId FROM [warehouse].[Location] WHERE SourceSystemCode = '02360'");
            var destinationId = Convert.ToInt32(data.Tables[0].Rows[0].ItemArray[0]);
            var destination = PcsPropertyHelper.GetCivLocationPerDiemById(destinationId, 202101);
            var distance = PcsPropertyHelper.CalculateDistance(origination, destination);
            Assert.IsTrue(distance > 0);
        }
        [TestMethod]
        public void SaveProjectTest()
        {
            if (!_userIds.ContainsKey("TestUser"))
            {
                _userIds.Add("TestUser", Guid.NewGuid());
                TestMethods.AddAmcosUser(_userIds["TestUser"].ToString(), "Test", "User", "test.user@mail.mil", "Active", DateTime.Now);
            }
            var locations = PcsPropertyHelper.GetAllCivPCSLocations(202101);            
            var originationId = Convert.ToInt32(locations.Where(s => s.Text.IndexOf("Denver") == 0).FirstOrDefault().Value);
            var destinationId = Convert.ToInt32(locations.Where(d => d.Text.IndexOf("Pittsfield") == 0).FirstOrDefault().Value);

            //Create mock user input
            var inputJson = new PCSProject()
            {
                ProjectName = "TestProject",                
                ConversionType = "ThenToThen",
                Year = 2021,
                Appropriation = "OMA",                
                AmcosVersionId = 202101,
                OriginationId = originationId,
                DestinationId = destinationId,
                CalculatedDistance = 200,
                NumberOfDaysHunting = 2,
                HouseHuntingHaveSpouse = true,
                SelfLodgingPerDiem = 200,
                SpouseLodgingPerDiem = 30,
                SelfMIEPerDiem = 40,
                SpouseMIEPerDiem = 30,
                HouseHuntingTotal = 100,
                SpousePerDiemRate = 40,
                POVMileage = 300,
                TransportationDependents = 1,
                PCSMaltRate = 50,
                MileageReimbursement = .16M,
                DependantMileageReimbursement = .14M,
                TransportationSubTotal = 50,
                NumberDaysTQSE = 2,
                TQSEDependents = 1,
                TQSESelfPerDiemLodging = 30,
                TQSESpousePerDiemLodging = 20,
                TQSESelfPerDiemMIE = 20,
                TQSESpousePerDiemMIE = 15,
                TQSEPerDiemRate = 50,
                TQSESpousePerDiemRate = 30,
                TQSETotal = 190,
                TransportationType = "Goods",
                GHTransportationTotal = 550,
                HHGTotalMileage = 400,
                HHGTotalWeight = 30,
                HHGMaxWeight = 18000,
                HHGEstimatedCostPerMile = 40,
                HHGEstimatedCostPerPound = 400,
                HHGCostByTotalMiles = 30,
                HHGCostByTotalWeight = 5000.03M,
                SubtotalHHG = 600.12M,
                MobileHomeTotalMileage = 400,
                MobileHomeEstCostPerMile = 500,
                MobileHomeSubtotal = 400000,
                MEAHasSpouse = true,
                MEACivilian = 4000,
                MEACivilianAndSpouse = 6000,
                MEASubtotal = 5000,
                RealEstateOrLease = "RealEstate",
                SalePriceAmount = 400000,
                PurchasePriceAmount = 600000,
                RealEstateSubtotal = 50000,
                UELAmount = 44.44M,
                UELTotal = 33.33M,
                RealEstateLeaseTotal = 44444,
                IsIsolatedDutyStation = true,
                NTSSubtotal = 4000,
                DefaultFederalTaxRate = 29.64M,
                FederalTaxRate = 14,
                SocialSecurityTaxRate = 2,
                MedicareTaxRate = 3,
                StateTaxRate = 5,
                CountyTaxRate = 1,
                CityTaxRate = 1.2M,
                HouseHuntingRITA = 500,
                TransportationRITA = 300,
                TQSERITA = 200,
                GHTransportationRITA = 400,
                MEARITA = 200,
                RealEstateLeaseRITA = 500,
                NTSRITA = 1000,
                RITASubtotal = 8000,
                GrandTotal = 300000
            };
            _projects.Add(_userIds["TestUser"], inputJson.ProjectName);          
            //controller.SaveProject(inputJson);
            PcsPropertyHelper.SaveProject(inputJson, _userIds["TestUser"].ToString());
            //Verify saved data
            var project = GetPCSProject(_userIds["TestUser"].ToString(), inputJson.ProjectName);
            Assert.IsNotNull(project);
            Assert.IsTrue(project.AmcosVersionId == inputJson.AmcosVersionId);
            Assert.IsTrue(project.OriginationId == inputJson.OriginationId);
            Assert.IsTrue(project.DestinationId == inputJson.DestinationId);
            Assert.IsTrue(project.ConversionType == inputJson.ConversionType);
            Assert.IsTrue(project.NumberOfDaysHunting == inputJson.NumberOfDaysHunting);
            Assert.IsTrue(project.TransportationType == inputJson.TransportationType);
            Assert.IsTrue(project.CalculatedDistance == inputJson.CalculatedDistance);
            Assert.IsTrue(project.HouseHuntingTotal == inputJson.HouseHuntingTotal);
            Assert.IsTrue(project.TransportationSubTotal == inputJson.TransportationSubTotal);
            Assert.IsTrue(project.TQSETotal == inputJson.TQSETotal);
            Assert.IsTrue(project.GHTransportationTotal == inputJson.GHTransportationTotal);
            Assert.IsTrue(project.RealEstateSubtotal == inputJson.RealEstateSubtotal);
            Assert.IsTrue(project.UELAmount == Math.Round(inputJson.UELAmount.Value, 2));
            Assert.IsTrue(project.NTSSubtotal == inputJson.NTSSubtotal);
            Assert.IsTrue(project.RITASubtotal == inputJson.RITASubtotal);
            Assert.IsTrue(project.GrandTotal == inputJson.GrandTotal);
                        
        }
        [TestMethod]
        public void OpenProjectTest()
        {
            //We first need a project to test.  Add a project using the the save project test method
            SaveProjectTest();
            var project = PcsPropertyHelper.OpenProject("TestProject", _userIds["TestUser"].ToString());
            Assert.IsTrue(project != null);
            Assert.IsTrue(!project.InitialState);
        }
        [TestMethod]
        public void SetProjectDeletedTest()
        {
            _userIds.Add("SetDeletedTestUser", Guid.NewGuid());
            TestMethods.AddAmcosUser(_userIds["SetDeletedTestUser"].ToString(), "Test", "User", "test.user@mail.mil", "Active", DateTime.Now);
            var locations = PcsPropertyHelper.GetAllCivPCSLocations(202101);
            var originationId = Convert.ToInt32(locations.Where(s => s.Text.IndexOf("Denver") == 0).FirstOrDefault().Value);
            var destinationId = Convert.ToInt32(locations.Where(d => d.Text.IndexOf("Pittsfield") == 0).FirstOrDefault().Value);

            //Create mock user input
            var inputJson = new PCSProject()
            {
                ProjectName = "TestProject",
                ConversionType = "ThenToThen",
                Year = 2021,
                Appropriation = "OMA",
                AmcosVersionId = 202101,
                OriginationId = originationId,
                DestinationId = destinationId,                
            };
            _projects.Add(_userIds["SetDeletedTestUser"], inputJson.ProjectName);
            //controller.SaveProject(inputJson);
            PcsPropertyHelper.SaveProject(inputJson, _userIds["SetDeletedTestUser"].ToString());
            //Verify saved data
            var project = GetPCSProject(_userIds["SetDeletedTestUser"].ToString(), inputJson.ProjectName);
            Assert.IsTrue(project.Deleted == false);
            //Set project to deleted
            PcsPropertyHelper.SetProjectDeleted(inputJson.ProjectName, _userIds["SetDeletedTestUser"].ToString());
            //Verify project set to deleted
            project = GetPCSProject(_userIds["SetDeletedTestUser"].ToString(), inputJson.ProjectName);
            Assert.IsTrue(project.Deleted == true);
        }
        private PCSProject GetPCSProject(string userId, string projectName)
        {
            using (var context = new ApplicationDbContext())
            {
                return context.PCSProject.AsNoTracking().Where(p => p.UserId == userId && p.ProjectName == projectName).FirstOrDefault();
            }
        }
        private static DataSet ExecuteSQL(string sql, params SqlParameter[] parameters)
        {
            DataSet dataset = new DataSet();

            using (SqlConnection connection = new SqlConnection(ConfigurationManager.ConnectionStrings["AmcosAdo"].ConnectionString))
            {
                connection.Open();
                SqlDataAdapter adapter = new SqlDataAdapter();
                using (SqlCommand command = new SqlCommand(sql, connection))
                {                    
                    command.CommandType = CommandType.Text;
                    adapter.SelectCommand = command;
                    adapter.Fill(dataset);
                }
            }
            return dataset;
        }

        [TestCleanup]
        public void TestCleanup()
        {
            _projects.ToList().ForEach(v => TestMethods.DeletePCSProject(v.Key.ToString(), v.Value));
            _userIds.Values.ToList().ForEach(v => DataAccessUtility.GetScalarByStaticSql("DELETE FROM webuser.User_Login_History where UserID=@uid", new string[] { "@uid" }, new string[] { v.ToString() }));
            _userIds.Values.ToList().ForEach(v => TestMethods.DeleteUserById(v.ToString()));
        }
    }
}
