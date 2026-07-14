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
        public void AllCostPayPlans_NotEmpty()
        {
            Assert.IsTrue(LocalDashboards.GetAllCostPayPlans().Rows.Count > 0, "No pay plans with cost data.");
        }

        [TestMethod]
        public void CostTotalByGrade_ReturnsPerVersionTotals()
        {
            var payPlan = LocalDashboards.GetAllCostPayPlans().Rows[0]["payplan"].ToString();
            var table = LocalDashboards.GetCostTotalByGrade(payPlan!, _version);
            Assert.IsTrue(table.Rows.Count > 0, "No per-grade cost totals for a seeded pay plan.");
            CollectionAssert.AreEquivalent(new[] { "gradelevel", "amount" }, GetColumnNames(table));
        }

        [TestMethod]
        public void CostData_SupportsTwoVersionComparison()
        {
            // The version selector needs >= 2 versions with cost data for a real compare
            // (seed 009 derives a prior version from the current one).
            var versions = LocalDashboards.GetCostVersions();
            if (versions.Rows.Count < 2)
                Assert.Inconclusive("Only one cost version present; run seed 009_version_compare_demo.sql.");

            var vA = Convert.ToInt32(versions.Rows[0]["amcosversionid"]);
            var vB = Convert.ToInt32(versions.Rows[1]["amcosversionid"]);
            Assert.AreNotEqual(vA, vB);

            var payPlan = LocalDashboards.GetAllCostPayPlans().Rows[0]["payplan"].ToString();
            Assert.IsTrue(LocalDashboards.GetCostTotalByGrade(payPlan!, vA).Rows.Count > 0, "Version A has no data.");
            Assert.IsTrue(LocalDashboards.GetCostTotalByGrade(payPlan!, vB).Rows.Count > 0, "Version B has no data.");
        }

        [TestMethod]
        public void InventoryByGrade_ExecutesAndHasExpectedShape()
        {
            // The query must run and project the expected columns for any pay plan (catches
            // schema/type drift such as the gradelevel varchar), even one with no inventory.
            var table = LocalDashboards.GetInventoryByGrade("AO", _version);
            CollectionAssert.AreEquivalent(
                new[] { "gradelevel", "categorygroupcode", "inventory" },
                GetColumnNames(table));
        }

        [TestMethod]
        public void InventoryDemo_IsSeededForComparison()
        {
            // Demo inventory (seed 010) surfaces through data.inventory for at least one
            // pay plan; and the seeded prior version differs, so the comparison has a delta.
            var payPlans = LocalDashboards.GetAllInventoryPayPlans();
            if (payPlans.Rows.Count == 0)
                Assert.Inconclusive("No inventory seeded; run seed 010_inventory_demo.sql.");

            var payPlan = payPlans.Rows[0]["payplan"].ToString();
            Assert.IsTrue(LocalDashboards.GetInventoryTotalByGrade(payPlan!, _version).Rows.Count > 0,
                "Inventory pay plan has no rows for the current version.");
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
