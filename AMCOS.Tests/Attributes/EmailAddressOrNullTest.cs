using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using AMCOS.Logic.Attributes;
using Microsoft.VisualStudio.TestTools.UnitTesting;

namespace AMCOS.Tests.Attributes
{
    // Pure-logic tests for the [EmailAddressOrNull] validation attribute: an empty/null
    // value is allowed, a well-formed address is allowed, and a malformed non-empty
    // value fails. Driven through Validator.TryValidateProperty so the attribute runs
    // exactly as the model-validation pipeline invokes it.
    [TestClass]
    public class EmailAddressOrNullTest
    {
        private sealed class Model
        {
            [EmailAddressOrNull]
            public string Email { get; set; }
        }

        private static bool IsValid(string email)
        {
            var model = new Model { Email = email };
            var context = new ValidationContext(model) { MemberName = nameof(Model.Email) };
            return Validator.TryValidateProperty(model.Email, context, new List<ValidationResult>());
        }

        [DataTestMethod]
        [DataRow(null)]                        // "OrNull": absent value is allowed
        [DataRow("")]
        [DataRow("   ")]
        [DataRow("user@example.com")]
        [DataRow("first.last@sub.army.mil")]
        public void AllowsNullEmptyOrWellFormed(string email)
        {
            Assert.IsTrue(IsValid(email));
        }

        [DataTestMethod]
        [DataRow("not-an-email")]
        [DataRow("missing-domain@")]
        [DataRow("@missing-local.com")]
        [DataRow("spaces in@name.com")]
        public void RejectsMalformedNonEmpty(string email)
        {
            Assert.IsFalse(IsValid(email));
        }
    }
}
