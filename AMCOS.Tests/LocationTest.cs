using Microsoft.Data.Tools.Schema.Sql.UnitTesting;
using Microsoft.Data.Tools.Schema.Sql.UnitTesting.Conditions;
using Microsoft.VisualStudio.TestTools.UnitTesting;
using System;
using System.Collections.Generic;
using System.Data;
using System.Data.Common;
using System.Text;

namespace AMCOS.Tests
{
    [TestClass()]
    public class LocationTest : SqlDatabaseTestClass
    {

        public LocationTest()
        {
            InitializeComponent();
        }

        [TestInitialize()]
        public void TestInitialize()
        {
            base.InitializeTest();
        }
        [TestCleanup()]
        public void TestCleanup()
        {
            base.CleanupTest();
        }
        [TestMethod()]
        public void MilitaryInstallationContainsFortLiberty()
        {
            SqlDatabaseTestActions testActions = this.MilitaryInstallationContainsFortLibertyData;
            // Execute the pre-test script
            // 
            System.Diagnostics.Trace.WriteLineIf((testActions.PretestAction != null), "Executing pre-test script...");
            SqlExecutionResult[] pretestResults = TestService.Execute(this.PrivilegedContext, this.PrivilegedContext, testActions.PretestAction);
            try
            {
                // Execute the test script
                // 
                System.Diagnostics.Trace.WriteLineIf((testActions.TestAction != null), "Executing test script...");
                SqlExecutionResult[] testResults = TestService.Execute(this.ExecutionContext, this.PrivilegedContext, testActions.TestAction);
            }
            finally
            {
                // Execute the post-test script
                // 
                System.Diagnostics.Trace.WriteLineIf((testActions.PosttestAction != null), "Executing post-test script...");
                SqlExecutionResult[] posttestResults = TestService.Execute(this.PrivilegedContext, this.PrivilegedContext, testActions.PosttestAction);
            }
        }
        [TestMethod()]
        public void MilitaryInstallationContainsFortMoore()
        {
            SqlDatabaseTestActions testActions = this.MilitaryInstallationContainsFortMooreData;
            // Execute the pre-test script
            // 
            System.Diagnostics.Trace.WriteLineIf((testActions.PretestAction != null), "Executing pre-test script...");
            SqlExecutionResult[] pretestResults = TestService.Execute(this.PrivilegedContext, this.PrivilegedContext, testActions.PretestAction);
            try
            {
                // Execute the test script
                // 
                System.Diagnostics.Trace.WriteLineIf((testActions.TestAction != null), "Executing test script...");
                SqlExecutionResult[] testResults = TestService.Execute(this.ExecutionContext, this.PrivilegedContext, testActions.TestAction);
            }
            finally
            {
                // Execute the post-test script
                // 
                System.Diagnostics.Trace.WriteLineIf((testActions.PosttestAction != null), "Executing post-test script...");
                SqlExecutionResult[] posttestResults = TestService.Execute(this.PrivilegedContext, this.PrivilegedContext, testActions.PosttestAction);
            }
        }
        [TestMethod()]
        public void MilitaryHousingAreaContainsFortMoore()
        {
            SqlDatabaseTestActions testActions = this.MilitaryHousingAreaContainsFortMooreData;
            // Execute the pre-test script
            // 
            System.Diagnostics.Trace.WriteLineIf((testActions.PretestAction != null), "Executing pre-test script...");
            SqlExecutionResult[] pretestResults = TestService.Execute(this.PrivilegedContext, this.PrivilegedContext, testActions.PretestAction);
            try
            {
                // Execute the test script
                // 
                System.Diagnostics.Trace.WriteLineIf((testActions.TestAction != null), "Executing test script...");
                SqlExecutionResult[] testResults = TestService.Execute(this.ExecutionContext, this.PrivilegedContext, testActions.TestAction);
            }
            finally
            {
                // Execute the post-test script
                // 
                System.Diagnostics.Trace.WriteLineIf((testActions.PosttestAction != null), "Executing post-test script...");
                SqlExecutionResult[] posttestResults = TestService.Execute(this.PrivilegedContext, this.PrivilegedContext, testActions.PosttestAction);
            }
        }
        [TestMethod()]
        public void MilitaryHousingAreaContainsFortLiberty()
        {
            SqlDatabaseTestActions testActions = this.MilitaryHousingAreaContainsFortLibertyData;
            // Execute the pre-test script
            // 
            System.Diagnostics.Trace.WriteLineIf((testActions.PretestAction != null), "Executing pre-test script...");
            SqlExecutionResult[] pretestResults = TestService.Execute(this.PrivilegedContext, this.PrivilegedContext, testActions.PretestAction);
            try
            {
                // Execute the test script
                // 
                System.Diagnostics.Trace.WriteLineIf((testActions.TestAction != null), "Executing test script...");
                SqlExecutionResult[] testResults = TestService.Execute(this.ExecutionContext, this.PrivilegedContext, testActions.TestAction);
            }
            finally
            {
                // Execute the post-test script
                // 
                System.Diagnostics.Trace.WriteLineIf((testActions.PosttestAction != null), "Executing post-test script...");
                SqlExecutionResult[] posttestResults = TestService.Execute(this.PrivilegedContext, this.PrivilegedContext, testActions.PosttestAction);
            }
        }
        [TestMethod()]
        public void LocationByCategoryContainsFortLiberty()
        {
            SqlDatabaseTestActions testActions = this.LocationByCategoryContainsFortLibertyData;
            // Execute the pre-test script
            // 
            System.Diagnostics.Trace.WriteLineIf((testActions.PretestAction != null), "Executing pre-test script...");
            SqlExecutionResult[] pretestResults = TestService.Execute(this.PrivilegedContext, this.PrivilegedContext, testActions.PretestAction);
            try
            {
                // Execute the test script
                // 
                System.Diagnostics.Trace.WriteLineIf((testActions.TestAction != null), "Executing test script...");
                SqlExecutionResult[] testResults = TestService.Execute(this.ExecutionContext, this.PrivilegedContext, testActions.TestAction);
            }
            finally
            {
                // Execute the post-test script
                // 
                System.Diagnostics.Trace.WriteLineIf((testActions.PosttestAction != null), "Executing post-test script...");
                SqlExecutionResult[] posttestResults = TestService.Execute(this.PrivilegedContext, this.PrivilegedContext, testActions.PosttestAction);
            }
        }
        [TestMethod()]
        public void LocationByCategoryContainsFortMoore()
        {
            SqlDatabaseTestActions testActions = this.LocationByCategoryContainsFortMooreData;
            // Execute the pre-test script
            // 
            System.Diagnostics.Trace.WriteLineIf((testActions.PretestAction != null), "Executing pre-test script...");
            SqlExecutionResult[] pretestResults = TestService.Execute(this.PrivilegedContext, this.PrivilegedContext, testActions.PretestAction);
            try
            {
                // Execute the test script
                // 
                System.Diagnostics.Trace.WriteLineIf((testActions.TestAction != null), "Executing test script...");
                SqlExecutionResult[] testResults = TestService.Execute(this.ExecutionContext, this.PrivilegedContext, testActions.TestAction);
            }
            finally
            {
                // Execute the post-test script
                // 
                System.Diagnostics.Trace.WriteLineIf((testActions.PosttestAction != null), "Executing post-test script...");
                SqlExecutionResult[] posttestResults = TestService.Execute(this.PrivilegedContext, this.PrivilegedContext, testActions.PosttestAction);
            }
        }








        #region Designer support code

        /// <summary> 
        /// Required method for Designer support - do not modify 
        /// the contents of this method with the code editor.
        /// </summary>
        private void InitializeComponent()
        {
            Microsoft.Data.Tools.Schema.Sql.UnitTesting.SqlDatabaseTestAction MilitaryInstallationContainsFortLiberty_TestAction;
            System.ComponentModel.ComponentResourceManager resources = new System.ComponentModel.ComponentResourceManager(typeof(LocationTest));
            Microsoft.Data.Tools.Schema.Sql.UnitTesting.Conditions.EmptyResultSetCondition emptyResultSetCondition2;
            Microsoft.Data.Tools.Schema.Sql.UnitTesting.SqlDatabaseTestAction MilitaryInstallationContainsFortMoore_TestAction;
            Microsoft.Data.Tools.Schema.Sql.UnitTesting.Conditions.EmptyResultSetCondition emptyResultSetCondition3;
            Microsoft.Data.Tools.Schema.Sql.UnitTesting.SqlDatabaseTestAction MilitaryHousingAreaContainsFortMoore_TestAction;
            Microsoft.Data.Tools.Schema.Sql.UnitTesting.Conditions.EmptyResultSetCondition emptyResultSetCondition6;
            Microsoft.Data.Tools.Schema.Sql.UnitTesting.SqlDatabaseTestAction MilitaryHousingAreaContainsFortLiberty_TestAction;
            Microsoft.Data.Tools.Schema.Sql.UnitTesting.Conditions.EmptyResultSetCondition emptyResultSetCondition5;
            Microsoft.Data.Tools.Schema.Sql.UnitTesting.SqlDatabaseTestAction LocationByCategoryContainsFortLiberty_TestAction;
            Microsoft.Data.Tools.Schema.Sql.UnitTesting.Conditions.EmptyResultSetCondition emptyResultSetCondition4;
            Microsoft.Data.Tools.Schema.Sql.UnitTesting.SqlDatabaseTestAction LocationByCategoryContainsFortMoore_TestAction;
            Microsoft.Data.Tools.Schema.Sql.UnitTesting.Conditions.EmptyResultSetCondition emptyResultSetCondition1;
            this.MilitaryInstallationContainsFortLibertyData = new Microsoft.Data.Tools.Schema.Sql.UnitTesting.SqlDatabaseTestActions();
            this.MilitaryInstallationContainsFortMooreData = new Microsoft.Data.Tools.Schema.Sql.UnitTesting.SqlDatabaseTestActions();
            this.MilitaryHousingAreaContainsFortMooreData = new Microsoft.Data.Tools.Schema.Sql.UnitTesting.SqlDatabaseTestActions();
            this.MilitaryHousingAreaContainsFortLibertyData = new Microsoft.Data.Tools.Schema.Sql.UnitTesting.SqlDatabaseTestActions();
            this.LocationByCategoryContainsFortLibertyData = new Microsoft.Data.Tools.Schema.Sql.UnitTesting.SqlDatabaseTestActions();
            this.LocationByCategoryContainsFortMooreData = new Microsoft.Data.Tools.Schema.Sql.UnitTesting.SqlDatabaseTestActions();
            MilitaryInstallationContainsFortLiberty_TestAction = new Microsoft.Data.Tools.Schema.Sql.UnitTesting.SqlDatabaseTestAction();
            emptyResultSetCondition2 = new Microsoft.Data.Tools.Schema.Sql.UnitTesting.Conditions.EmptyResultSetCondition();
            MilitaryInstallationContainsFortMoore_TestAction = new Microsoft.Data.Tools.Schema.Sql.UnitTesting.SqlDatabaseTestAction();
            emptyResultSetCondition3 = new Microsoft.Data.Tools.Schema.Sql.UnitTesting.Conditions.EmptyResultSetCondition();
            MilitaryHousingAreaContainsFortMoore_TestAction = new Microsoft.Data.Tools.Schema.Sql.UnitTesting.SqlDatabaseTestAction();
            emptyResultSetCondition6 = new Microsoft.Data.Tools.Schema.Sql.UnitTesting.Conditions.EmptyResultSetCondition();
            MilitaryHousingAreaContainsFortLiberty_TestAction = new Microsoft.Data.Tools.Schema.Sql.UnitTesting.SqlDatabaseTestAction();
            emptyResultSetCondition5 = new Microsoft.Data.Tools.Schema.Sql.UnitTesting.Conditions.EmptyResultSetCondition();
            LocationByCategoryContainsFortLiberty_TestAction = new Microsoft.Data.Tools.Schema.Sql.UnitTesting.SqlDatabaseTestAction();
            emptyResultSetCondition4 = new Microsoft.Data.Tools.Schema.Sql.UnitTesting.Conditions.EmptyResultSetCondition();
            LocationByCategoryContainsFortMoore_TestAction = new Microsoft.Data.Tools.Schema.Sql.UnitTesting.SqlDatabaseTestAction();
            emptyResultSetCondition1 = new Microsoft.Data.Tools.Schema.Sql.UnitTesting.Conditions.EmptyResultSetCondition();
            // 
            // MilitaryInstallationContainsFortLiberty_TestAction
            // 
            MilitaryInstallationContainsFortLiberty_TestAction.Conditions.Add(emptyResultSetCondition2);
            resources.ApplyResources(MilitaryInstallationContainsFortLiberty_TestAction, "MilitaryInstallationContainsFortLiberty_TestAction");
            // 
            // emptyResultSetCondition2
            // 
            emptyResultSetCondition2.Enabled = true;
            emptyResultSetCondition2.Name = "emptyResultSetCondition2";
            emptyResultSetCondition2.ResultSet = 1;
            // 
            // MilitaryInstallationContainsFortMoore_TestAction
            // 
            MilitaryInstallationContainsFortMoore_TestAction.Conditions.Add(emptyResultSetCondition3);
            resources.ApplyResources(MilitaryInstallationContainsFortMoore_TestAction, "MilitaryInstallationContainsFortMoore_TestAction");
            // 
            // emptyResultSetCondition3
            // 
            emptyResultSetCondition3.Enabled = true;
            emptyResultSetCondition3.Name = "emptyResultSetCondition3";
            emptyResultSetCondition3.ResultSet = 1;
            // 
            // MilitaryHousingAreaContainsFortMoore_TestAction
            // 
            MilitaryHousingAreaContainsFortMoore_TestAction.Conditions.Add(emptyResultSetCondition6);
            resources.ApplyResources(MilitaryHousingAreaContainsFortMoore_TestAction, "MilitaryHousingAreaContainsFortMoore_TestAction");
            // 
            // emptyResultSetCondition6
            // 
            emptyResultSetCondition6.Enabled = true;
            emptyResultSetCondition6.Name = "emptyResultSetCondition6";
            emptyResultSetCondition6.ResultSet = 1;
            // 
            // MilitaryHousingAreaContainsFortLiberty_TestAction
            // 
            MilitaryHousingAreaContainsFortLiberty_TestAction.Conditions.Add(emptyResultSetCondition5);
            resources.ApplyResources(MilitaryHousingAreaContainsFortLiberty_TestAction, "MilitaryHousingAreaContainsFortLiberty_TestAction");
            // 
            // emptyResultSetCondition5
            // 
            emptyResultSetCondition5.Enabled = true;
            emptyResultSetCondition5.Name = "emptyResultSetCondition5";
            emptyResultSetCondition5.ResultSet = 1;
            // 
            // LocationByCategoryContainsFortLiberty_TestAction
            // 
            LocationByCategoryContainsFortLiberty_TestAction.Conditions.Add(emptyResultSetCondition4);
            resources.ApplyResources(LocationByCategoryContainsFortLiberty_TestAction, "LocationByCategoryContainsFortLiberty_TestAction");
            // 
            // emptyResultSetCondition4
            // 
            emptyResultSetCondition4.Enabled = true;
            emptyResultSetCondition4.Name = "emptyResultSetCondition4";
            emptyResultSetCondition4.ResultSet = 1;
            // 
            // LocationByCategoryContainsFortMoore_TestAction
            // 
            LocationByCategoryContainsFortMoore_TestAction.Conditions.Add(emptyResultSetCondition1);
            resources.ApplyResources(LocationByCategoryContainsFortMoore_TestAction, "LocationByCategoryContainsFortMoore_TestAction");
            // 
            // emptyResultSetCondition1
            // 
            emptyResultSetCondition1.Enabled = true;
            emptyResultSetCondition1.Name = "emptyResultSetCondition1";
            emptyResultSetCondition1.ResultSet = 1;
            // 
            // MilitaryInstallationContainsFortLibertyData
            // 
            this.MilitaryInstallationContainsFortLibertyData.PosttestAction = null;
            this.MilitaryInstallationContainsFortLibertyData.PretestAction = null;
            this.MilitaryInstallationContainsFortLibertyData.TestAction = MilitaryInstallationContainsFortLiberty_TestAction;
            // 
            // MilitaryInstallationContainsFortMooreData
            // 
            this.MilitaryInstallationContainsFortMooreData.PosttestAction = null;
            this.MilitaryInstallationContainsFortMooreData.PretestAction = null;
            this.MilitaryInstallationContainsFortMooreData.TestAction = MilitaryInstallationContainsFortMoore_TestAction;
            // 
            // MilitaryHousingAreaContainsFortMooreData
            // 
            this.MilitaryHousingAreaContainsFortMooreData.PosttestAction = null;
            this.MilitaryHousingAreaContainsFortMooreData.PretestAction = null;
            this.MilitaryHousingAreaContainsFortMooreData.TestAction = MilitaryHousingAreaContainsFortMoore_TestAction;
            // 
            // MilitaryHousingAreaContainsFortLibertyData
            // 
            this.MilitaryHousingAreaContainsFortLibertyData.PosttestAction = null;
            this.MilitaryHousingAreaContainsFortLibertyData.PretestAction = null;
            this.MilitaryHousingAreaContainsFortLibertyData.TestAction = MilitaryHousingAreaContainsFortLiberty_TestAction;
            // 
            // LocationByCategoryContainsFortLibertyData
            // 
            this.LocationByCategoryContainsFortLibertyData.PosttestAction = null;
            this.LocationByCategoryContainsFortLibertyData.PretestAction = null;
            this.LocationByCategoryContainsFortLibertyData.TestAction = LocationByCategoryContainsFortLiberty_TestAction;
            // 
            // LocationByCategoryContainsFortMooreData
            // 
            this.LocationByCategoryContainsFortMooreData.PosttestAction = null;
            this.LocationByCategoryContainsFortMooreData.PretestAction = null;
            this.LocationByCategoryContainsFortMooreData.TestAction = LocationByCategoryContainsFortMoore_TestAction;
        }

        #endregion


        #region Additional test attributes
        //
        // You can use the following additional attributes as you write your tests:
        //
        // Use ClassInitialize to run code before running the first test in the class
        // [ClassInitialize()]
        // public static void MyClassInitialize(TestContext testContext) { }
        //
        // Use ClassCleanup to run code after all tests in a class have run
        // [ClassCleanup()]
        // public static void MyClassCleanup() { }
        //
        #endregion
        private SqlDatabaseTestActions MilitaryInstallationContainsFortLibertyData;
        private SqlDatabaseTestActions MilitaryInstallationContainsFortMooreData;
        private SqlDatabaseTestActions MilitaryHousingAreaContainsFortMooreData;
        private SqlDatabaseTestActions MilitaryHousingAreaContainsFortLibertyData;
        private SqlDatabaseTestActions LocationByCategoryContainsFortLibertyData;
        private SqlDatabaseTestActions LocationByCategoryContainsFortMooreData;
    }
}
