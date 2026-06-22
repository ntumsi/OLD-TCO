using Microsoft.VisualStudio.TestTools.UnitTesting;
// We don't need Moq for this anymore
using Owin;
using System.Configuration;
using AMCOS.Logic.Helpers;
using Microsoft.Owin.Security.OpenIdConnect;
using Microsoft.Owin.Security.Cookies;
using Microsoft.Owin;
using System.Collections.Generic;
using System;
using System.Threading.Tasks; // Required for the FakeAppBuilder
using System.Linq; // Required for LINQ

namespace AMCOS.Tests
{
    /// <summary>
    /// A simple "spy" implementation of IAppBuilder for testing.
    /// It has a real Properties dictionary and records calls to its Use method.
    /// </summary>
    public class FakeAppBuilder : IAppBuilder
    {
        // A real dictionary to support extension methods like SetDefaultSignInAsAuthenticationType
        public IDictionary<string, object> Properties { get; } = new Dictionary<string, object>();

        // A list to record the arguments passed to the Use method
        public List<object[]> UseMethodCallArgs { get; } = new List<object[]>();

        public IAppBuilder Use(object middleware, params object[] args)
        {
            // Record the arguments for later inspection
            var allArgs = new List<object> { middleware };
            allArgs.AddRange(args);
            UseMethodCallArgs.Add(allArgs.ToArray());

            // Return "this" to allow fluent chaining, just like the real IAppBuilder
            return this;
        }

        public object Build(Type returnType)
        {
            // Not needed for this test, can be a simple implementation
            return new Func<IDictionary<string, object>, Task>(env => Task.CompletedTask);
        }

        public IAppBuilder New()
        {
            // Not needed for this test
            return new FakeAppBuilder();
        }
    }

    [TestClass]
    public class KeyCloakHelperTests
    {
        private KeyCloakHelper _keyCloakHelper;
        private FakeAppBuilder _fakeAppBuilder; // Use our FakeAppBuilder instead of a Mock

        [TestInitialize]
        public void TestInitialize()
        {
            // Arrange: Create new instances for each test
            _keyCloakHelper = new KeyCloakHelper();
            _fakeAppBuilder = new FakeAppBuilder();
        }
        [Ignore]
        [TestMethod]
        public void Configuration_Test()
        {   
            // Act
            // Pass our fake IAppBuilder to the method
            _keyCloakHelper.Configuration(_fakeAppBuilder);

            // Assert
            // 1. Inspect the list of recorded calls on our fake builder
            var oidcOptions = _fakeAppBuilder.UseMethodCallArgs
                .SelectMany(args => args) // Flatten the list of arguments
                .OfType<OpenIdConnectAuthenticationOptions>() // Find the OIDC options object
                .FirstOrDefault();

            // 2. Assert that we found the options object
            Assert.IsNotNull(oidcOptions, "OpenIdConnectAuthenticationOptions were not passed to app.Use().");

            // 3. Now we can safely test its properties
            Assert.AreEqual(ConfigurationManager.AppSettings["KeyCloakClientId"], oidcOptions.ClientId);
            Assert.AreEqual(ConfigurationManager.AppSettings["KeyCloakAuthority"], oidcOptions.Authority);
            Assert.AreEqual(ConfigurationManager.AppSettings["AmcosUrl"], oidcOptions.RedirectUri);
        }

       
    }
}
