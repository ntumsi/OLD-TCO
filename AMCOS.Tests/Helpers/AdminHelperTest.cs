using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using Microsoft.VisualStudio.TestTools.UnitTesting;
using AMCOS.Logic.Helpers;

namespace AMCOS.Tests.Helpers
{
    [TestClass]
    public class AdminHelperTest
    {
        [TestMethod]
        public void ThrowExceptionIfNotAdminTest()
        {
            try
            {
                AdminHelper.ThrowExceptionIfNotAdmin("Admin");
            } catch { Assert.Fail(); }
            try
            {
                AdminHelper.ThrowExceptionIfNotAdmin("User");
                Assert.Fail();
            } catch { /*Pass */ }
            
        }
    }
}
