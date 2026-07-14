using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using AMCOS.Logic.Attributes;
using Microsoft.VisualStudio.TestTools.UnitTesting;

namespace AMCOS.Tests.Attributes
{
    // Pure-logic tests for the cross-property validation attributes in
    // AMCOS.Logic.Attributes, driven through Validator.TryValidateProperty so the
    // attribute sees a real ValidationContext (both read another property off the
    // validated model instance via reflection).
    [TestClass]
    public class ValidationAttributesTest
    {
        // ---- [NotEqualTo(otherProperty)] : this field must differ from another ----

        private sealed class PasswordModel
        {
            public string OldPassword { get; set; }

            [NotEqualTo(nameof(OldPassword))]
            public string NewPassword { get; set; }
        }

        private static bool NewPasswordValid(string oldPw, string newPw)
        {
            var model = new PasswordModel { OldPassword = oldPw, NewPassword = newPw };
            var ctx = new ValidationContext(model) { MemberName = nameof(PasswordModel.NewPassword) };
            return Validator.TryValidateProperty(model.NewPassword, ctx, new List<ValidationResult>());
        }

        [TestMethod]
        public void NotEqualTo_FailsWhenEqual()
        {
            Assert.IsFalse(NewPasswordValid("hunter2", "hunter2"));
        }

        [TestMethod]
        public void NotEqualTo_PassesWhenDifferent()
        {
            Assert.IsTrue(NewPasswordValid("hunter2", "hunter3"));
        }

        // ---- [RequireIf(otherProperty, values)] : required when other is in set ----

        private sealed class OverseasModel
        {
            public string DutyLocation { get; set; }

            // Overseas allowance is required only when the duty location is OCONUS.
            [RequireIf(nameof(DutyLocation), new[] { "OCONUS" })]
            public string OverseasAllowance { get; set; }
        }

        private static bool AllowanceValid(string dutyLocation, string allowance)
        {
            var model = new OverseasModel { DutyLocation = dutyLocation, OverseasAllowance = allowance };
            var ctx = new ValidationContext(model) { MemberName = nameof(OverseasModel.OverseasAllowance) };
            return Validator.TryValidateProperty(model.OverseasAllowance, ctx, new List<ValidationResult>());
        }

        [TestMethod]
        public void RequireIf_RequiredWhenTriggerMatches_AndMissing()
        {
            Assert.IsFalse(AllowanceValid("OCONUS", null));
        }

        [TestMethod]
        public void RequireIf_SatisfiedWhenTriggerMatches_AndProvided()
        {
            Assert.IsTrue(AllowanceValid("OCONUS", "250.00"));
        }

        [TestMethod]
        public void RequireIf_NotRequiredWhenTriggerDoesNotMatch()
        {
            // CONUS is not in the trigger set, so a missing allowance is still valid.
            Assert.IsTrue(AllowanceValid("CONUS", null));
        }
    }
}
