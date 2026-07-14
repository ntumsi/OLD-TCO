using System;
using System.Data;
using AMCOS.Logic;
using Microsoft.VisualStudio.TestTools.UnitTesting;

namespace AMCOS.Tests.Integration
{
    // Integration tests for the local-dashboard query methods (LocalDashboards), which
    // back the Cost Compare / Inventory / GS Locality Rates pages. Require a reachable
    // amcos database (see DatabaseIntegrationTests for the AMCOS_POSTGRES_CONNECTION note);
    // Inconclusive when none is available. Cost Compare asserts on demo data that is
    // seeded; Inventory/Locality only assert the queries execute (their tables are empty
    // until ETL runs), which is exactly what guards against broken SQL/schema drift.
    [TestClass]
    [TestCategory("Integration")]
    public class LocalDashboardsTests
    {
        private int _version;

        [TestInitialize]
        public void RequireDatabase()
        {
            try
            {
                DataAccessUtility.GetScalarByStaticSql("SELECT 1");
            }
            catch (Exception ex)
            {
                Assert.Inconclusive("amcos database not reachable; set AMCOS_POSTGRES_CONNECTION. " + ex.Message);
            }

            // Use a real version that has cost data so Cost Compare assertions are meaningful.
            var versions = LocalDashboards.GetCostVersions();
            _version = versions.Rows.Count > 0 ? Convert.ToInt32(versions.Rows[0]["amcosversionid"]) : 0;
        }

        [TestMethod]
        public void CostVersions_And_AmcosVersions_NotEmpty()
        {
            Assert.IsTrue(LocalDashboards.GetCostVersions().Rows.Count > 0, "No cost versions.");
            Assert.IsTrue(LocalDashboards.GetAmcosVersions().Rows.Count > 0, "No AMCOS versions.");
        }

        [TestMethod]
        public void CostCompare_ReturnsGradeByCategoryRows()
        {
            var payPlans = LocalDashboards.GetCostPayPlans(_version);
            Assert.IsTrue(payPlans.Rows.Count > 0, "No pay plans with cost data.");
            var payPlan = payPlans.Rows[0]["payplan"].ToString();

            var table = LocalDashboards.GetCostCompare(payPlan!, _version);
            Assert.IsTrue(table.Rows.Count > 0, "Cost Compare returned no rows for a seeded pay plan.");
            CollectionAssert.AreEquivalent(
                new[] { "gradelevel", "costelementcategory", "amount" },
                GetColumnNames(table));
        }

        [TestMethod]
        public void InventoryByGrade_ExecutesAndHasExpectedShape()
        {
            // data.inventory is empty until ETL; the query must still run and project the
            // expected columns (catches schema/type drift such as the gradelevel varchar).
            var table = LocalDashboards.GetInventoryByGrade("AO", _version);
            CollectionAssert.AreEquivalent(
                new[] { "gradelevel", "categorygroupcode", "inventory" },
                GetColumnNames(table));
        }

        [TestMethod]
        public void LocalityRateByZip_ExecutesWithoutError()
        {
            // Validates the ZIP -> FIPS -> locality -> rate join against the real schema.
            var table = LocalDashboards.GetLocalityRateByZip("20301", _version);
            Assert.IsNotNull(table);
        }

        [TestMethod]
        public void AllLocalityRates_ExecutesWithExpectedShape()
        {
            var table = LocalDashboards.GetAllLocalityRates(_version);
            CollectionAssert.AreEquivalent(
                new[] { "localitycode", "localityname", "localityrate" },
                GetColumnNames(table));
        }

        private static string[] GetColumnNames(DataTable table)
        {
            var names = new string[table.Columns.Count];
            for (var i = 0; i < table.Columns.Count; i++) names[i] = table.Columns[i].ColumnName;
            return names;
        }
    }
}
