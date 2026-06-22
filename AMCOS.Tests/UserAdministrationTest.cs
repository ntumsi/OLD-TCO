using System;
using System.Collections.Generic;
using System.Linq;
using AMCOS.Data;
using AMCOS.Logic;
using Microsoft.VisualStudio.TestTools.UnitTesting;

namespace AMCOS.Tests
{
    [TestClass]
    public class UserAdministrationTest
    {
        private Dictionary<string, Guid> _userIds = new Dictionary<string, Guid>();
        public TestContext TestContext { get; set; }
        [TestMethod]
        public void SponsorDoesExist()
        {
            Assert.Inconclusive();
        }

        [TestMethod]
        public void SponsorDoesNotExist()
        {
            Assert.Inconclusive();
        }

        [TestMethod]
        public void SponsorNullOrEmpty_ThrowsArgumentNullException()
        {
            Assert.Inconclusive();
        }

        [TestMethod]
        public void PhoneNumber_FormattedCorrectly()
        {
            string fromCall = UserAdministration.GetFormattedPhoneNo("5551234567");
            Assert.AreEqual("(555)123-4567",fromCall,false,"Phone number not formatted");
        }

        [TestMethod]
        public void PhoneNumberNullOrEmpty_ThrowsArgumentNullException()
        { 
            string fromCall = UserAdministration.GetFormattedPhoneNo("");
        }

        [TestMethod]
        public void PhoneNumber_ThrowsArgumentNullException()
        {
            Assert.Inconclusive();
        }

        [TestMethod]
        public void RequiresSponsor_TrueForContractor()
        {
            Assert.IsTrue(UserAdministration.RequiresSponsor("greg.bonner.ctr@mail.mil", UserAdministration.AccountType.CONTRACTOR));
        }

        [TestMethod]
        public void RequiresSponsor_FalseForMilitary()
        {
            Assert.IsFalse(UserAdministration.RequiresSponsor("bugs.bunny.mil@mail.mil", UserAdministration.AccountType.MILITARY));
        }

        [TestMethod]
        public void RequiresSponsor_FalseForCivilian()
        {
            Assert.IsFalse(UserAdministration.RequiresSponsor("greg.bonner.civ@mail.mil", UserAdministration.AccountType.CIVILIAN));
        }

        [TestMethod]
        public void RequiresSponsor_TrueForOther()
        {
            Assert.IsTrue(UserAdministration.RequiresSponsor("dhog12@gmail.com", UserAdministration.AccountType.OTHER));
        }
        
        [TestCleanup]
        public void TestCleanup()
        {
            //Cleanup            
            _userIds.Values.ToList().ForEach(v => DataAccessUtility.GetScalarByStaticSql("DELETE FROM webuser.User_Login_History where UserID=@uid", new string[] { "@uid" }, new string[] { v.ToString() }));
            _userIds.Values.ToList().ForEach(v => DeleteUserById(v.ToString()));
        }
        private void DeleteUserById(string userId)
        {
            try
            {
                using (var context = new ApplicationDbContext())
                {
                    var user = context.AMCOSUser.Where(x => x.UserId == userId).FirstOrDefault();
                    if (user != null)
                    {
                        context.AMCOSUser.Remove(user);
                        context.SaveChanges();
                    }
                }
            }
            catch (Exception ex)
            {
                TestContext.WriteLine("Error removing user {0} Error: {1}", userId, ex.Message);
            }
        }
    }
}
