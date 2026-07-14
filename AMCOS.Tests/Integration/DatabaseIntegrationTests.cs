using System;
using System.Linq;
using AMCOS.Data;
using AMCOS.Logic;
using Microsoft.VisualStudio.TestTools.UnitTesting;

namespace AMCOS.Tests.Integration
{
    // Tier 2: DB-integration tests. These require a reachable PostgreSQL "amcos"
    // database with the standard migrations + demo seed applied. Supply the
    // connection via the AMCOS_POSTGRES_CONNECTION environment variable (it takes
    // precedence over appsettings.json), e.g.:
    //   AMCOS_POSTGRES_CONNECTION="Host=localhost;Database=amcos;Username=postgres;Password=postgr3s"
    //
    // When no database is reachable the tests report Inconclusive (not Failed), so the
    // suite stays green on machines without a database. Filter them with:
    //   dotnet test --filter TestCategory=Integration
    //
    // NOTE ON THE LEGACY TESTS: the old CostCrunch/Inventory/Location/PaySchedule tests
    // were SSDT (SqlDatabaseTestClass) T-SQL tests bound to SQL Server and to reference
    // data (military installations, test.* data-quality views) that is not part of the
    // Postgres demo seed, so they are not ported verbatim. These integration tests instead
    // exercise the migrated data layer against data that is reliably present (self-managed
    // CRUD + demo seed + the ported crunch read function).
    [TestClass]
    [TestCategory("Integration")]
    public class DatabaseIntegrationTests
    {
        [TestInitialize]
        public void RequireDatabase()
        {
            try
            {
                DataAccessUtility.GetScalarByStaticSql("SELECT 1");
            }
            catch (Exception ex)
            {
                Assert.Inconclusive(
                    "PostgreSQL 'amcos' database not reachable; set AMCOS_POSTGRES_CONNECTION. " +
                    ex.Message);
            }
        }

        [TestMethod]
        public void DataAccessUtility_GetScalarByStaticSql_ReturnsValue()
        {
            var result = DataAccessUtility.GetScalarByStaticSql("SELECT 1");
            Assert.AreEqual(1, Convert.ToInt32(result));
        }

        [TestMethod]
        public void AmcosUser_CrudRoundTrip()
        {
            // Self-contained: create a user with a unique id, read/update/delete it,
            // and clean up in a finally so a failed assert never leaves a stray row.
            var userId = Guid.NewGuid().ToString();
            const string email = "test.user.civ@mail.mil";
            try
            {
                var created = TestMethods.AddAmcosUser(userId, "Integration", "Tester", email, "Pending");
                Assert.IsNotNull(created);

                // Read back in a fresh context (hits the database, not the change tracker).
                using (var context = new ApplicationDbContext())
                {
                    var fetched = context.AMCOSUser.FirstOrDefault(u => u.UserId == userId);
                    Assert.IsNotNull(fetched, "User was not persisted.");
                    Assert.AreEqual(email, fetched.Email);
                    Assert.AreEqual("Pending", fetched.UserStatus);

                    // Update.
                    fetched.UserStatus = "Active";
                    context.SaveChanges();
                }

                using (var context = new ApplicationDbContext())
                {
                    var updated = context.AMCOSUser.First(u => u.UserId == userId);
                    Assert.AreEqual("Active", updated.UserStatus, "Update did not persist.");
                }
            }
            finally
            {
                TestMethods.DeleteUserById(userId);
            }

            // Delete is verified after cleanup.
            using (var context = new ApplicationDbContext())
            {
                var gone = context.AMCOSUser.FirstOrDefault(u => u.UserId == userId);
                Assert.IsNull(gone, "User was not deleted.");
            }
        }

        [TestMethod]
        public void SeedData_CoreReferenceRowsPresent()
        {
            // Guards against a seed regression: the demo seed must provide at least one
            // AMCOS version, warehouse locations, and demo cost rows for the app to render.
            Assert.IsTrue(CountOf("lookup.amcosversion") > 0, "No AMCOS versions seeded.");
            Assert.IsTrue(CountOf("warehouse.location") > 0, "No warehouse locations seeded.");
            Assert.IsTrue(CountOf("crunch.costs_ao") > 0, "No demo Active-Officer cost rows seeded.");
        }

        [TestMethod]
        public void CivPcs_DutyStationsAreSelectable()
        {
            // The Civilian PCS origination/destination picker
            // (web.GetCivPCSLocationsByQuery) must surface several zip-type duty stations
            // with coordinates + per-diem. Seed 011 adds installations beyond the two base
            // rows; assert a 'Fort' search returns more than one.
            var count = Convert.ToInt64(DataAccessUtility.GetScalarByStaticSql(
                "SELECT count(*) FROM web.getcivpcslocationsbyquery(202501, 'Fort', NULL)"));
            Assert.IsTrue(count > 1, $"Expected multiple 'Fort' duty stations, got {count}.");
        }

        [TestMethod]
        public void CivPcs_AutoDistanceCanCompute()
        {
            // Distance auto-calculates only when BOTH selected stations resolve per-diem in
            // web.civlocationperdiem (else ProcessJsonInput early-returns) AND both have
            // geography coordinates. Assert a real mileage is computable between two selectable
            // stations end-to-end (guards the picker/per-diem seed staying in sync).
            var miles = DataAccessUtility.GetScalarByStaticSql(
                @"SELECT round((ST_Distance(a.coordinates, b.coordinates) / 1609.34)::numeric)
                  FROM warehouse.location a
                  JOIN web.civlocationperdiem pa ON pa.locationid = a.locationid AND pa.amcosversionid = 202501
                  JOIN warehouse.location b ON b.locationtype = 'zip' AND b.locationid <> a.locationid
                  JOIN web.civlocationperdiem pb ON pb.locationid = b.locationid AND pb.amcosversionid = 202501
                  WHERE a.displayname LIKE 'Fort Moore%'
                    AND a.coordinates IS NOT NULL AND b.coordinates IS NOT NULL
                  LIMIT 1");
            Assert.IsTrue(miles != null && miles != DBNull.Value && Convert.ToInt64(miles) > 0,
                "No computable mileage between selectable duty stations — per-diem/coordinate seed out of sync.");
        }

        [TestMethod]
        public void CrunchGetSingleValue_ExecutesWithExpectedSignature()
        {
            // Contract test for the ported read function crunch.getsinglevalue(varchar,
            // varchar, int) -> numeric. A non-matching lookup returns NULL rather than
            // throwing; the point is that the function exists and is callable as the web
            // read-path invokes it.
            var result = DataAccessUtility.GetScalarByStaticSql(
                "SELECT crunch.getsinglevalue('AO', 'BasePay', -1)");
            Assert.IsTrue(result == null || result == DBNull.Value || IsNumeric(result),
                "getsinglevalue did not return a numeric-or-null result.");
        }

        private static long CountOf(string qualifiedTable)
        {
            var result = DataAccessUtility.GetScalarByStaticSql($"SELECT count(*) FROM {qualifiedTable}");
            return Convert.ToInt64(result);
        }

        private static bool IsNumeric(object value)
        {
            return value is decimal || value is double || value is float
                || value is int || value is long || value is short;
        }
    }
}
