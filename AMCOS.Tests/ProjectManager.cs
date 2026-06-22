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
    public class ProjectManager : SqlDatabaseTestClass
    {

        public ProjectManager()
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
        public void PMValidateUnitRequirement_AE_11_11B_Returns_AE_11_11B()
        {
            SqlDatabaseTestActions testActions = this.PMValidateUnitRequirement_AE_11_11B_Returns_AE_11_11BData;
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
        public void PMValidateUnitRequirement_AE_11_11P_Returns_AE_11_Neg1()
        {
            SqlDatabaseTestActions testActions = this.PMValidateUnitRequirement_AE_11_11P_Returns_AE_11_Neg1Data;
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
        public void PMValidateUnitRequirement_AO_12_12B_Returns_AO_12_Neg1()
        {
            SqlDatabaseTestActions testActions = this.PMValidateUnitRequirement_AO_12_12B_Returns_AO_12_Neg1Data;
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
        public void PMValidateUnitRequirement_A0_05_05A_172_3_Returns_A0_Neg1_Neg1_Neg1_3()
        {
            SqlDatabaseTestActions testActions = this.PMValidateUnitRequirement_A0_05_05A_172_3_Returns_A0_Neg1_Neg1_Neg1_3Data;
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
        public void PMValidateUnitRequirement_AE_25_25H_388_7_Returns_AE_Neg1_Neg1_Neg1_7()
        {
            SqlDatabaseTestActions testActions = this.PMValidateUnitRequirement_AE_25_25H_388_7_Returns_AE_Neg1_Neg1_Neg1_7Data;
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
            Microsoft.Data.Tools.Schema.Sql.UnitTesting.SqlDatabaseTestAction PMValidateUnitRequirement_AE_11_11B_Returns_AE_11_11B_TestAction;
            System.ComponentModel.ComponentResourceManager resources = new System.ComponentModel.ComponentResourceManager(typeof(ProjectManager));
            Microsoft.Data.Tools.Schema.Sql.UnitTesting.SqlDatabaseTestAction PMValidateUnitRequirement_AE_11_11B_Returns_AE_11_11B_PretestAction;
            Microsoft.Data.Tools.Schema.Sql.UnitTesting.SqlDatabaseTestAction PMValidateUnitRequirement_AE_11_11P_Returns_AE_11_Neg1_TestAction;
            Microsoft.Data.Tools.Schema.Sql.UnitTesting.SqlDatabaseTestAction PMValidateUnitRequirement_AO_12_12B_Returns_AO_12_Neg1_TestAction;
            Microsoft.Data.Tools.Schema.Sql.UnitTesting.SqlDatabaseTestAction PMValidateUnitRequirement_A0_05_05A_172_3_Returns_A0_Neg1_Neg1_Neg1_3_TestAction;
            Microsoft.Data.Tools.Schema.Sql.UnitTesting.SqlDatabaseTestAction PMValidateUnitRequirement_AE_25_25H_388_7_Returns_AE_Neg1_Neg1_Neg1_7_TestAction;
            Microsoft.Data.Tools.Schema.Sql.UnitTesting.Conditions.ChecksumCondition checksumCondition1;
            Microsoft.Data.Tools.Schema.Sql.UnitTesting.Conditions.ChecksumCondition checksumCondition2;
            Microsoft.Data.Tools.Schema.Sql.UnitTesting.Conditions.ChecksumCondition checksumCondition3;
            Microsoft.Data.Tools.Schema.Sql.UnitTesting.Conditions.ChecksumCondition checksumCondition4;
            Microsoft.Data.Tools.Schema.Sql.UnitTesting.Conditions.ChecksumCondition checksumCondition5;
            this.PMValidateUnitRequirement_AE_11_11B_Returns_AE_11_11BData = new Microsoft.Data.Tools.Schema.Sql.UnitTesting.SqlDatabaseTestActions();
            this.PMValidateUnitRequirement_AE_11_11P_Returns_AE_11_Neg1Data = new Microsoft.Data.Tools.Schema.Sql.UnitTesting.SqlDatabaseTestActions();
            this.PMValidateUnitRequirement_AO_12_12B_Returns_AO_12_Neg1Data = new Microsoft.Data.Tools.Schema.Sql.UnitTesting.SqlDatabaseTestActions();
            this.PMValidateUnitRequirement_A0_05_05A_172_3_Returns_A0_Neg1_Neg1_Neg1_3Data = new Microsoft.Data.Tools.Schema.Sql.UnitTesting.SqlDatabaseTestActions();
            this.PMValidateUnitRequirement_AE_25_25H_388_7_Returns_AE_Neg1_Neg1_Neg1_7Data = new Microsoft.Data.Tools.Schema.Sql.UnitTesting.SqlDatabaseTestActions();
            PMValidateUnitRequirement_AE_11_11B_Returns_AE_11_11B_TestAction = new Microsoft.Data.Tools.Schema.Sql.UnitTesting.SqlDatabaseTestAction();
            PMValidateUnitRequirement_AE_11_11B_Returns_AE_11_11B_PretestAction = new Microsoft.Data.Tools.Schema.Sql.UnitTesting.SqlDatabaseTestAction();
            PMValidateUnitRequirement_AE_11_11P_Returns_AE_11_Neg1_TestAction = new Microsoft.Data.Tools.Schema.Sql.UnitTesting.SqlDatabaseTestAction();
            PMValidateUnitRequirement_AO_12_12B_Returns_AO_12_Neg1_TestAction = new Microsoft.Data.Tools.Schema.Sql.UnitTesting.SqlDatabaseTestAction();
            PMValidateUnitRequirement_A0_05_05A_172_3_Returns_A0_Neg1_Neg1_Neg1_3_TestAction = new Microsoft.Data.Tools.Schema.Sql.UnitTesting.SqlDatabaseTestAction();
            PMValidateUnitRequirement_AE_25_25H_388_7_Returns_AE_Neg1_Neg1_Neg1_7_TestAction = new Microsoft.Data.Tools.Schema.Sql.UnitTesting.SqlDatabaseTestAction();
            checksumCondition1 = new Microsoft.Data.Tools.Schema.Sql.UnitTesting.Conditions.ChecksumCondition();
            checksumCondition2 = new Microsoft.Data.Tools.Schema.Sql.UnitTesting.Conditions.ChecksumCondition();
            checksumCondition3 = new Microsoft.Data.Tools.Schema.Sql.UnitTesting.Conditions.ChecksumCondition();
            checksumCondition4 = new Microsoft.Data.Tools.Schema.Sql.UnitTesting.Conditions.ChecksumCondition();
            checksumCondition5 = new Microsoft.Data.Tools.Schema.Sql.UnitTesting.Conditions.ChecksumCondition();
            // 
            // PMValidateUnitRequirement_AE_11_11B_Returns_AE_11_11B_TestAction
            // 
            PMValidateUnitRequirement_AE_11_11B_Returns_AE_11_11B_TestAction.Conditions.Add(checksumCondition2);
            resources.ApplyResources(PMValidateUnitRequirement_AE_11_11B_Returns_AE_11_11B_TestAction, "PMValidateUnitRequirement_AE_11_11B_Returns_AE_11_11B_TestAction");
            // 
            // PMValidateUnitRequirement_AE_11_11B_Returns_AE_11_11B_PretestAction
            // 
            resources.ApplyResources(PMValidateUnitRequirement_AE_11_11B_Returns_AE_11_11B_PretestAction, "PMValidateUnitRequirement_AE_11_11B_Returns_AE_11_11B_PretestAction");
            // 
            // PMValidateUnitRequirement_AE_11_11P_Returns_AE_11_Neg1_TestAction
            // 
            PMValidateUnitRequirement_AE_11_11P_Returns_AE_11_Neg1_TestAction.Conditions.Add(checksumCondition3);
            resources.ApplyResources(PMValidateUnitRequirement_AE_11_11P_Returns_AE_11_Neg1_TestAction, "PMValidateUnitRequirement_AE_11_11P_Returns_AE_11_Neg1_TestAction");
            // 
            // PMValidateUnitRequirement_AO_12_12B_Returns_AO_12_Neg1_TestAction
            // 
            PMValidateUnitRequirement_AO_12_12B_Returns_AO_12_Neg1_TestAction.Conditions.Add(checksumCondition5);
            resources.ApplyResources(PMValidateUnitRequirement_AO_12_12B_Returns_AO_12_Neg1_TestAction, "PMValidateUnitRequirement_AO_12_12B_Returns_AO_12_Neg1_TestAction");
            // 
            // PMValidateUnitRequirement_A0_05_05A_172_3_Returns_A0_Neg1_Neg1_Neg1_3_TestAction
            // 
            PMValidateUnitRequirement_A0_05_05A_172_3_Returns_A0_Neg1_Neg1_Neg1_3_TestAction.Conditions.Add(checksumCondition1);
            resources.ApplyResources(PMValidateUnitRequirement_A0_05_05A_172_3_Returns_A0_Neg1_Neg1_Neg1_3_TestAction, "PMValidateUnitRequirement_A0_05_05A_172_3_Returns_A0_Neg1_Neg1_Neg1_3_TestAction");
            // 
            // PMValidateUnitRequirement_AE_25_25H_388_7_Returns_AE_Neg1_Neg1_Neg1_7_TestAction
            // 
            PMValidateUnitRequirement_AE_25_25H_388_7_Returns_AE_Neg1_Neg1_Neg1_7_TestAction.Conditions.Add(checksumCondition4);
            resources.ApplyResources(PMValidateUnitRequirement_AE_25_25H_388_7_Returns_AE_Neg1_Neg1_Neg1_7_TestAction, "PMValidateUnitRequirement_AE_25_25H_388_7_Returns_AE_Neg1_Neg1_Neg1_7_TestAction");
            // 
            // PMValidateUnitRequirement_AE_11_11B_Returns_AE_11_11BData
            // 
            this.PMValidateUnitRequirement_AE_11_11B_Returns_AE_11_11BData.PosttestAction = null;
            this.PMValidateUnitRequirement_AE_11_11B_Returns_AE_11_11BData.PretestAction = PMValidateUnitRequirement_AE_11_11B_Returns_AE_11_11B_PretestAction;
            this.PMValidateUnitRequirement_AE_11_11B_Returns_AE_11_11BData.TestAction = PMValidateUnitRequirement_AE_11_11B_Returns_AE_11_11B_TestAction;
            // 
            // PMValidateUnitRequirement_AE_11_11P_Returns_AE_11_Neg1Data
            // 
            this.PMValidateUnitRequirement_AE_11_11P_Returns_AE_11_Neg1Data.PosttestAction = null;
            this.PMValidateUnitRequirement_AE_11_11P_Returns_AE_11_Neg1Data.PretestAction = null;
            this.PMValidateUnitRequirement_AE_11_11P_Returns_AE_11_Neg1Data.TestAction = PMValidateUnitRequirement_AE_11_11P_Returns_AE_11_Neg1_TestAction;
            // 
            // PMValidateUnitRequirement_AO_12_12B_Returns_AO_12_Neg1Data
            // 
            this.PMValidateUnitRequirement_AO_12_12B_Returns_AO_12_Neg1Data.PosttestAction = null;
            this.PMValidateUnitRequirement_AO_12_12B_Returns_AO_12_Neg1Data.PretestAction = null;
            this.PMValidateUnitRequirement_AO_12_12B_Returns_AO_12_Neg1Data.TestAction = PMValidateUnitRequirement_AO_12_12B_Returns_AO_12_Neg1_TestAction;
            // 
            // PMValidateUnitRequirement_A0_05_05A_172_3_Returns_A0_Neg1_Neg1_Neg1_3Data
            // 
            this.PMValidateUnitRequirement_A0_05_05A_172_3_Returns_A0_Neg1_Neg1_Neg1_3Data.PosttestAction = null;
            this.PMValidateUnitRequirement_A0_05_05A_172_3_Returns_A0_Neg1_Neg1_Neg1_3Data.PretestAction = null;
            this.PMValidateUnitRequirement_A0_05_05A_172_3_Returns_A0_Neg1_Neg1_Neg1_3Data.TestAction = PMValidateUnitRequirement_A0_05_05A_172_3_Returns_A0_Neg1_Neg1_Neg1_3_TestAction;
            // 
            // PMValidateUnitRequirement_AE_25_25H_388_7_Returns_AE_Neg1_Neg1_Neg1_7Data
            // 
            this.PMValidateUnitRequirement_AE_25_25H_388_7_Returns_AE_Neg1_Neg1_Neg1_7Data.PosttestAction = null;
            this.PMValidateUnitRequirement_AE_25_25H_388_7_Returns_AE_Neg1_Neg1_Neg1_7Data.PretestAction = null;
            this.PMValidateUnitRequirement_AE_25_25H_388_7_Returns_AE_Neg1_Neg1_Neg1_7Data.TestAction = PMValidateUnitRequirement_AE_25_25H_388_7_Returns_AE_Neg1_Neg1_Neg1_7_TestAction;
            // 
            // checksumCondition1
            // 
            checksumCondition1.Checksum = "1724042230";
            checksumCondition1.Enabled = true;
            checksumCondition1.Name = "checksumCondition1";
            // 
            // checksumCondition2
            // 
            checksumCondition2.Checksum = "498579125";
            checksumCondition2.Enabled = true;
            checksumCondition2.Name = "checksumCondition2";
            // 
            // checksumCondition3
            // 
            checksumCondition3.Checksum = "387283924";
            checksumCondition3.Enabled = true;
            checksumCondition3.Name = "checksumCondition3";
            // 
            // checksumCondition4
            // 
            checksumCondition4.Checksum = "1444056166";
            checksumCondition4.Enabled = true;
            checksumCondition4.Name = "checksumCondition4";
            // 
            // checksumCondition5
            // 
            checksumCondition5.Checksum = "-1280241505";
            checksumCondition5.Enabled = true;
            checksumCondition5.Name = "checksumCondition5";
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
        private SqlDatabaseTestActions PMValidateUnitRequirement_AE_11_11B_Returns_AE_11_11BData;
        private SqlDatabaseTestActions PMValidateUnitRequirement_AE_11_11P_Returns_AE_11_Neg1Data;
        private SqlDatabaseTestActions PMValidateUnitRequirement_AO_12_12B_Returns_AO_12_Neg1Data;
        private SqlDatabaseTestActions PMValidateUnitRequirement_A0_05_05A_172_3_Returns_A0_Neg1_Neg1_Neg1_3Data;
        private SqlDatabaseTestActions PMValidateUnitRequirement_AE_25_25H_388_7_Returns_AE_Neg1_Neg1_Neg1_7Data;
    }
}
