using AMCOS.Logic;
using Microsoft.VisualStudio.TestTools.UnitTesting;

// Namespace intentionally NOT "AMCOS.Tests.Logic": that would shadow the global
// "AMCOS.Logic" for the relative "Logic.UserAdministration" reference in TestMethods.cs.
namespace AMCOS.Tests.LogicTests
{
    // Pure-logic unit tests (no database) for the classification/formatting helpers
    // in AMCOS.Logic.UserAdministration. These mirror behaviour the legacy app relied
    // on (email -> account type, raw phone -> display format) and run with no infra.
    [TestClass]
    public class UserAdministrationLogicTest
    {
        // ---- GetAccountTypeFromEmail: keyed off the ".<code>@" segment ----------

        [DataTestMethod]
        [DataRow("john.a.doe.mil@army.mil", UserAdministration.AccountType.MILITARY)]
        [DataRow("jane.b.doe.civ@army.mil", UserAdministration.AccountType.CIVILIAN)]
        [DataRow("pat.c.doe.naf@army.mil", UserAdministration.AccountType.CIVILIAN)]
        [DataRow("sam.d.doe.ctr@vendor.com", UserAdministration.AccountType.CONTRACTOR)]
        [DataRow("lee.e.doe.ret@army.mil", UserAdministration.AccountType.OTHER)]
        [DataRow("kim.f.doe.vol@army.mil", UserAdministration.AccountType.OTHER)]
        [DataRow("nobody@example.com", UserAdministration.AccountType.UNKNOWN)]
        public void GetAccountTypeFromEmail_ClassifiesByCode(string email, UserAdministration.AccountType expected)
        {
            Assert.AreEqual(expected, UserAdministration.GetAccountTypeFromEmail(email));
        }

        [TestMethod]
        public void GetAccountTypeFromEmail_IsCaseInsensitive()
        {
            // Method lower-cases before matching, so upper-case input must still classify.
            Assert.AreEqual(
                UserAdministration.AccountType.MILITARY,
                UserAdministration.GetAccountTypeFromEmail("JOHN.A.DOE.MIL@ARMY.MIL"));
        }

        // ---- GetFormattedPhoneNo: strip non-digits, format the last 10 ----------

        [DataTestMethod]
        [DataRow(null, "")]
        [DataRow("", "")]
        [DataRow("   ", "")]
        [DataRow("5551234567", "(555)123-4567")]      // exactly 10 digits
        [DataRow("(555) 123-4567", "(555)123-4567")]  // punctuation stripped
        [DataRow("1-555-123-4567", "(555)123-4567")]  // 11 digits -> last 10 kept
        [DataRow("5551234", "5551234")]               // fewer than 10 -> returned as-is
        public void GetFormattedPhoneNo_FormatsOrPassesThrough(string input, string expected)
        {
            Assert.AreEqual(expected, UserAdministration.GetFormattedPhoneNo(input));
        }
    }
}
