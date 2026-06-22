using Microsoft.VisualStudio.TestTools.UnitTesting;
using AMCOS.Logic.Helpers;
using System.IO;
using AMCOS.Logic.ViewModels;

namespace AMCOS.Tests.Helpers
{
    [TestClass]
    public class ExportHelperTest
    {
        [TestMethod]
        public void ExportTest()
        {
            using (var stream = new MemoryStream())
            {
                ExportHelper.ExportToExcel(stream, new CivPcsJson(), "ExportTest");
                Assert.IsTrue(stream.Length > 100);
            }

        }
    }
}
