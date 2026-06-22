using AMCOS.Data;
using Microsoft.VisualStudio.TestTools.UnitTesting;

namespace AMCOS.Tests
{
    [TestClass]
    public class ConfigurationMigrationTests
    {
        [TestMethod]
        public void PlaceholderConnectionStringIsAvailable()
        {
            var connectionString = AppConfiguration.GetConnectionString();

            Assert.IsFalse(string.IsNullOrWhiteSpace(connectionString));
            StringAssert.Contains(connectionString, "Host=");
        }
    }
}
