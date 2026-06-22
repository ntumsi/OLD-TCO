using System;
using System.Collections.Generic;
using System.Data;
using System.Data.Common;
using System.Text;
using Microsoft.Data.Tools.Schema.Sql.UnitTesting;
using Microsoft.Data.Tools.Schema.Sql.UnitTesting.Conditions;
using Microsoft.VisualStudio.TestTools.UnitTesting;

namespace AMCOS.Tests
{
    [TestClass()]
    public class CostCrunchTest : SqlDatabaseTestClass
    {

        public CostCrunchTest()
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
        public void ActiveDutyInventoryWithoutBasePay()
        {
            SqlDatabaseTestActions testActions = this.ActiveDutyInventoryWithoutBasePayData;
            // Execute the pre-test script
            // 
            System.Diagnostics.Trace.WriteLineIf((testActions.PretestAction != null), "Executing pre-test script...");
            SqlExecutionResult[] pretestResults = TestService.Execute(this.PrivilegedContext, this.PrivilegedContext, testActions.PretestAction);
            // Execute the test script
            // 
            System.Diagnostics.Trace.WriteLineIf((testActions.TestAction != null), "Executing test script...");
            SqlExecutionResult[] testResults = TestService.Execute(this.ExecutionContext, this.PrivilegedContext, testActions.TestAction);
            // Execute the post-test script
            // 
            System.Diagnostics.Trace.WriteLineIf((testActions.PosttestAction != null), "Executing post-test script...");
            SqlExecutionResult[] posttestResults = TestService.Execute(this.PrivilegedContext, this.PrivilegedContext, testActions.PosttestAction);
        }
        [TestMethod()]
        public void ReserveComponentsInventoryWithoutBasePay()
        {
            SqlDatabaseTestActions testActions = this.ReserveComponentsInventoryWithoutBasePayData;
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
        public void ArchivedCostElementsInCostSummary()
        {
            SqlDatabaseTestActions testActions = this.ArchivedCostElementsInCostSummaryData;
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
        public void ArchivedCostElementsInCostTables()
        {
            SqlDatabaseTestActions testActions = this.ArchivedCostElementsInCostTablesData;
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
        public void CostElementsInAncillaryCostSummaryAndAnotherCostSummary()
        {
            SqlDatabaseTestActions testActions = this.CostElementsInAncillaryCostSummaryAndAnotherCostSummaryData;
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
        public void CostElementsNotIncludedInCostSummary()
        {
            SqlDatabaseTestActions testActions = this.CostElementsNotIncludedInCostSummaryData;
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
            Microsoft.Data.Tools.Schema.Sql.UnitTesting.SqlDatabaseTestAction ActiveDutyInventoryWithoutBasePay_TestAction;
            System.ComponentModel.ComponentResourceManager resources = new System.ComponentModel.ComponentResourceManager(typeof(CostCrunchTest));
            Microsoft.Data.Tools.Schema.Sql.UnitTesting.Conditions.EmptyResultSetCondition emptyResultSetCondition1;
            Microsoft.Data.Tools.Schema.Sql.UnitTesting.SqlDatabaseTestAction ReserveComponentsInventoryWithoutBasePay_TestAction;
            Microsoft.Data.Tools.Schema.Sql.UnitTesting.Conditions.EmptyResultSetCondition emptyResultSetCondition2;
            Microsoft.Data.Tools.Schema.Sql.UnitTesting.SqlDatabaseTestAction ArchivedCostElementsInCostSummary_TestAction;
            Microsoft.Data.Tools.Schema.Sql.UnitTesting.Conditions.EmptyResultSetCondition emptyResultSetCondition3;
            Microsoft.Data.Tools.Schema.Sql.UnitTesting.SqlDatabaseTestAction ArchivedCostElementsInCostTables_TestAction;
            Microsoft.Data.Tools.Schema.Sql.UnitTesting.Conditions.EmptyResultSetCondition emptyResultSetCondition4;
            Microsoft.Data.Tools.Schema.Sql.UnitTesting.SqlDatabaseTestAction CostElementsInAncillaryCostSummaryAndAnotherCostSummary_TestAction;
            Microsoft.Data.Tools.Schema.Sql.UnitTesting.Conditions.EmptyResultSetCondition emptyResultSetCondition5;
            Microsoft.Data.Tools.Schema.Sql.UnitTesting.SqlDatabaseTestAction CostElementsNotIncludedInCostSummary_TestAction;
            Microsoft.Data.Tools.Schema.Sql.UnitTesting.Conditions.EmptyResultSetCondition emptyResultSetCondition6;
            this.ActiveDutyInventoryWithoutBasePayData = new Microsoft.Data.Tools.Schema.Sql.UnitTesting.SqlDatabaseTestActions();
            this.ReserveComponentsInventoryWithoutBasePayData = new Microsoft.Data.Tools.Schema.Sql.UnitTesting.SqlDatabaseTestActions();
            this.ArchivedCostElementsInCostSummaryData = new Microsoft.Data.Tools.Schema.Sql.UnitTesting.SqlDatabaseTestActions();
            this.ArchivedCostElementsInCostTablesData = new Microsoft.Data.Tools.Schema.Sql.UnitTesting.SqlDatabaseTestActions();
            this.CostElementsInAncillaryCostSummaryAndAnotherCostSummaryData = new Microsoft.Data.Tools.Schema.Sql.UnitTesting.SqlDatabaseTestActions();
            this.CostElementsNotIncludedInCostSummaryData = new Microsoft.Data.Tools.Schema.Sql.UnitTesting.SqlDatabaseTestActions();
            ActiveDutyInventoryWithoutBasePay_TestAction = new Microsoft.Data.Tools.Schema.Sql.UnitTesting.SqlDatabaseTestAction();
            emptyResultSetCondition1 = new Microsoft.Data.Tools.Schema.Sql.UnitTesting.Conditions.EmptyResultSetCondition();
            ReserveComponentsInventoryWithoutBasePay_TestAction = new Microsoft.Data.Tools.Schema.Sql.UnitTesting.SqlDatabaseTestAction();
            emptyResultSetCondition2 = new Microsoft.Data.Tools.Schema.Sql.UnitTesting.Conditions.EmptyResultSetCondition();
            ArchivedCostElementsInCostSummary_TestAction = new Microsoft.Data.Tools.Schema.Sql.UnitTesting.SqlDatabaseTestAction();
            emptyResultSetCondition3 = new Microsoft.Data.Tools.Schema.Sql.UnitTesting.Conditions.EmptyResultSetCondition();
            ArchivedCostElementsInCostTables_TestAction = new Microsoft.Data.Tools.Schema.Sql.UnitTesting.SqlDatabaseTestAction();
            emptyResultSetCondition4 = new Microsoft.Data.Tools.Schema.Sql.UnitTesting.Conditions.EmptyResultSetCondition();
            CostElementsInAncillaryCostSummaryAndAnotherCostSummary_TestAction = new Microsoft.Data.Tools.Schema.Sql.UnitTesting.SqlDatabaseTestAction();
            emptyResultSetCondition5 = new Microsoft.Data.Tools.Schema.Sql.UnitTesting.Conditions.EmptyResultSetCondition();
            CostElementsNotIncludedInCostSummary_TestAction = new Microsoft.Data.Tools.Schema.Sql.UnitTesting.SqlDatabaseTestAction();
            emptyResultSetCondition6 = new Microsoft.Data.Tools.Schema.Sql.UnitTesting.Conditions.EmptyResultSetCondition();
            // 
            // ActiveDutyInventoryWithoutBasePay_TestAction
            // 
            ActiveDutyInventoryWithoutBasePay_TestAction.Conditions.Add(emptyResultSetCondition1);
            resources.ApplyResources(ActiveDutyInventoryWithoutBasePay_TestAction, "ActiveDutyInventoryWithoutBasePay_TestAction");
            // 
            // emptyResultSetCondition1
            // 
            emptyResultSetCondition1.Enabled = true;
            emptyResultSetCondition1.Name = "emptyResultSetCondition1";
            emptyResultSetCondition1.ResultSet = 1;
            // 
            // ReserveComponentsInventoryWithoutBasePay_TestAction
            // 
            ReserveComponentsInventoryWithoutBasePay_TestAction.Conditions.Add(emptyResultSetCondition2);
            resources.ApplyResources(ReserveComponentsInventoryWithoutBasePay_TestAction, "ReserveComponentsInventoryWithoutBasePay_TestAction");
            // 
            // emptyResultSetCondition2
            // 
            emptyResultSetCondition2.Enabled = true;
            emptyResultSetCondition2.Name = "emptyResultSetCondition2";
            emptyResultSetCondition2.ResultSet = 1;
            // 
            // ArchivedCostElementsInCostSummary_TestAction
            // 
            ArchivedCostElementsInCostSummary_TestAction.Conditions.Add(emptyResultSetCondition3);
            resources.ApplyResources(ArchivedCostElementsInCostSummary_TestAction, "ArchivedCostElementsInCostSummary_TestAction");
            // 
            // emptyResultSetCondition3
            // 
            emptyResultSetCondition3.Enabled = true;
            emptyResultSetCondition3.Name = "emptyResultSetCondition3";
            emptyResultSetCondition3.ResultSet = 1;
            // 
            // ArchivedCostElementsInCostTables_TestAction
            // 
            ArchivedCostElementsInCostTables_TestAction.Conditions.Add(emptyResultSetCondition4);
            resources.ApplyResources(ArchivedCostElementsInCostTables_TestAction, "ArchivedCostElementsInCostTables_TestAction");
            // 
            // emptyResultSetCondition4
            // 
            emptyResultSetCondition4.Enabled = true;
            emptyResultSetCondition4.Name = "emptyResultSetCondition4";
            emptyResultSetCondition4.ResultSet = 1;
            // 
            // CostElementsInAncillaryCostSummaryAndAnotherCostSummary_TestAction
            // 
            CostElementsInAncillaryCostSummaryAndAnotherCostSummary_TestAction.Conditions.Add(emptyResultSetCondition5);
            resources.ApplyResources(CostElementsInAncillaryCostSummaryAndAnotherCostSummary_TestAction, "CostElementsInAncillaryCostSummaryAndAnotherCostSummary_TestAction");
            // 
            // emptyResultSetCondition5
            // 
            emptyResultSetCondition5.Enabled = true;
            emptyResultSetCondition5.Name = "emptyResultSetCondition5";
            emptyResultSetCondition5.ResultSet = 1;
            // 
            // CostElementsNotIncludedInCostSummary_TestAction
            // 
            CostElementsNotIncludedInCostSummary_TestAction.Conditions.Add(emptyResultSetCondition6);
            resources.ApplyResources(CostElementsNotIncludedInCostSummary_TestAction, "CostElementsNotIncludedInCostSummary_TestAction");
            // 
            // emptyResultSetCondition6
            // 
            emptyResultSetCondition6.Enabled = false;
            emptyResultSetCondition6.Name = "emptyResultSetCondition6";
            emptyResultSetCondition6.ResultSet = 1;
            // 
            // ActiveDutyInventoryWithoutBasePayData
            // 
            this.ActiveDutyInventoryWithoutBasePayData.PosttestAction = null;
            this.ActiveDutyInventoryWithoutBasePayData.PretestAction = null;
            this.ActiveDutyInventoryWithoutBasePayData.TestAction = ActiveDutyInventoryWithoutBasePay_TestAction;
            // 
            // ReserveComponentsInventoryWithoutBasePayData
            // 
            this.ReserveComponentsInventoryWithoutBasePayData.PosttestAction = null;
            this.ReserveComponentsInventoryWithoutBasePayData.PretestAction = null;
            this.ReserveComponentsInventoryWithoutBasePayData.TestAction = ReserveComponentsInventoryWithoutBasePay_TestAction;
            // 
            // ArchivedCostElementsInCostSummaryData
            // 
            this.ArchivedCostElementsInCostSummaryData.PosttestAction = null;
            this.ArchivedCostElementsInCostSummaryData.PretestAction = null;
            this.ArchivedCostElementsInCostSummaryData.TestAction = ArchivedCostElementsInCostSummary_TestAction;
            // 
            // ArchivedCostElementsInCostTablesData
            // 
            this.ArchivedCostElementsInCostTablesData.PosttestAction = null;
            this.ArchivedCostElementsInCostTablesData.PretestAction = null;
            this.ArchivedCostElementsInCostTablesData.TestAction = ArchivedCostElementsInCostTables_TestAction;
            // 
            // CostElementsInAncillaryCostSummaryAndAnotherCostSummaryData
            // 
            this.CostElementsInAncillaryCostSummaryAndAnotherCostSummaryData.PosttestAction = null;
            this.CostElementsInAncillaryCostSummaryAndAnotherCostSummaryData.PretestAction = null;
            this.CostElementsInAncillaryCostSummaryAndAnotherCostSummaryData.TestAction = CostElementsInAncillaryCostSummaryAndAnotherCostSummary_TestAction;
            // 
            // CostElementsNotIncludedInCostSummaryData
            // 
            this.CostElementsNotIncludedInCostSummaryData.PosttestAction = null;
            this.CostElementsNotIncludedInCostSummaryData.PretestAction = null;
            this.CostElementsNotIncludedInCostSummaryData.TestAction = CostElementsNotIncludedInCostSummary_TestAction;
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

        private SqlDatabaseTestActions ActiveDutyInventoryWithoutBasePayData;
        private SqlDatabaseTestActions ReserveComponentsInventoryWithoutBasePayData;
        private SqlDatabaseTestActions ArchivedCostElementsInCostSummaryData;
        private SqlDatabaseTestActions ArchivedCostElementsInCostTablesData;
        private SqlDatabaseTestActions CostElementsInAncillaryCostSummaryAndAnotherCostSummaryData;
        private SqlDatabaseTestActions CostElementsNotIncludedInCostSummaryData;
    }
}
