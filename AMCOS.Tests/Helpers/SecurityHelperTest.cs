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
    public class SecurityHelperTest
    {
        [TestMethod]
        public void GetAntiForgeryTokenTest()
        {
            var token = SecurityHelper.GetAntiForgeryToken();
            Assert.IsNotNull(token);
            var tokens = token.Split(':');
            Assert.IsTrue(tokens.Length == 2);
            Assert.IsTrue(tokens[0].Length > 8 && tokens[1].Length > 8);
        }
    }
}
