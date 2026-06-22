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
    public class PayScheduleTest : SqlDatabaseTestClass
    {

        public PayScheduleTest()
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
        public void PayScheduleExistsForEachGradeInInventory_AE()
        {
            SqlDatabaseTestActions testActions = this.PayScheduleExistsForEachGradeInInventory_AEData;
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
        public void PayScheduleExistsForEachGradeInInventory_AO()
        {
            SqlDatabaseTestActions testActions = this.PayScheduleExistsForEachGradeInInventory_AOData;
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
        public void PayScheduleExistsForEachGradeInInventory_AWO()
        {
            SqlDatabaseTestActions testActions = this.PayScheduleExistsForEachGradeInInventory_AWOData;
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
        public void PayScheduleExistsForEachGradeInInventory_NE()
        {
            SqlDatabaseTestActions testActions = this.PayScheduleExistsForEachGradeInInventory_NEData;
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
        public void PayScheduleExistsForEachGradeInInventory_NO()
        {
            SqlDatabaseTestActions testActions = this.PayScheduleExistsForEachGradeInInventory_NOData;
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
        public void PayScheduleExistsForEachGradeInInventory_NWO()
        {
            SqlDatabaseTestActions testActions = this.PayScheduleExistsForEachGradeInInventory_NWOData;
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
        public void PayScheduleExistsForEachGradeInInventory_RE()
        {
            SqlDatabaseTestActions testActions = this.PayScheduleExistsForEachGradeInInventory_REData;
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
        public void PayScheduleExistsForEachGradeInInventory_RO()
        {
            SqlDatabaseTestActions testActions = this.PayScheduleExistsForEachGradeInInventory_ROData;
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
        public void PayScheduleExistsForEachGradeInInventory_RWO()
        {
            SqlDatabaseTestActions testActions = this.PayScheduleExistsForEachGradeInInventory_RWOData;
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
            Microsoft.Data.Tools.Schema.Sql.UnitTesting.SqlDatabaseTestAction PayScheduleExistsForEachGradeInInventory_AE_TestAction;
            System.ComponentModel.ComponentResourceManager resources = new System.ComponentModel.ComponentResourceManager(typeof(PayScheduleTest));
            Microsoft.Data.Tools.Schema.Sql.UnitTesting.Conditions.EmptyResultSetCondition emptyResultSetCondition1;
            Microsoft.Data.Tools.Schema.Sql.UnitTesting.SqlDatabaseTestAction PayScheduleExistsForEachGradeInInventory_AO_TestAction;
            Microsoft.Data.Tools.Schema.Sql.UnitTesting.Conditions.EmptyResultSetCondition emptyResultSetCondition2;
            Microsoft.Data.Tools.Schema.Sql.UnitTesting.SqlDatabaseTestAction PayScheduleExistsForEachGradeInInventory_AWO_TestAction;
            Microsoft.Data.Tools.Schema.Sql.UnitTesting.Conditions.EmptyResultSetCondition emptyResultSetCondition3;
            Microsoft.Data.Tools.Schema.Sql.UnitTesting.SqlDatabaseTestAction PayScheduleExistsForEachGradeInInventory_NE_TestAction;
            Microsoft.Data.Tools.Schema.Sql.UnitTesting.Conditions.EmptyResultSetCondition emptyResultSetCondition4;
            Microsoft.Data.Tools.Schema.Sql.UnitTesting.SqlDatabaseTestAction PayScheduleExistsForEachGradeInInventory_NO_TestAction;
            Microsoft.Data.Tools.Schema.Sql.UnitTesting.Conditions.EmptyResultSetCondition emptyResultSetCondition5;
            Microsoft.Data.Tools.Schema.Sql.UnitTesting.SqlDatabaseTestAction PayScheduleExistsForEachGradeInInventory_NWO_TestAction;
            Microsoft.Data.Tools.Schema.Sql.UnitTesting.Conditions.EmptyResultSetCondition emptyResultSetCondition6;
            Microsoft.Data.Tools.Schema.Sql.UnitTesting.SqlDatabaseTestAction PayScheduleExistsForEachGradeInInventory_RE_TestAction;
            Microsoft.Data.Tools.Schema.Sql.UnitTesting.Conditions.EmptyResultSetCondition emptyResultSetCondition7;
            Microsoft.Data.Tools.Schema.Sql.UnitTesting.SqlDatabaseTestAction PayScheduleExistsForEachGradeInInventory_RO_TestAction;
            Microsoft.Data.Tools.Schema.Sql.UnitTesting.Conditions.EmptyResultSetCondition emptyResultSetCondition8;
            Microsoft.Data.Tools.Schema.Sql.UnitTesting.SqlDatabaseTestAction PayScheduleExistsForEachGradeInInventory_RWO_TestAction;
            Microsoft.Data.Tools.Schema.Sql.UnitTesting.Conditions.EmptyResultSetCondition emptyResultSetCondition9;
            this.PayScheduleExistsForEachGradeInInventory_AEData = new Microsoft.Data.Tools.Schema.Sql.UnitTesting.SqlDatabaseTestActions();
            this.PayScheduleExistsForEachGradeInInventory_AOData = new Microsoft.Data.Tools.Schema.Sql.UnitTesting.SqlDatabaseTestActions();
            this.PayScheduleExistsForEachGradeInInventory_AWOData = new Microsoft.Data.Tools.Schema.Sql.UnitTesting.SqlDatabaseTestActions();
            this.PayScheduleExistsForEachGradeInInventory_NEData = new Microsoft.Data.Tools.Schema.Sql.UnitTesting.SqlDatabaseTestActions();
            this.PayScheduleExistsForEachGradeInInventory_NOData = new Microsoft.Data.Tools.Schema.Sql.UnitTesting.SqlDatabaseTestActions();
            this.PayScheduleExistsForEachGradeInInventory_NWOData = new Microsoft.Data.Tools.Schema.Sql.UnitTesting.SqlDatabaseTestActions();
            this.PayScheduleExistsForEachGradeInInventory_REData = new Microsoft.Data.Tools.Schema.Sql.UnitTesting.SqlDatabaseTestActions();
            this.PayScheduleExistsForEachGradeInInventory_ROData = new Microsoft.Data.Tools.Schema.Sql.UnitTesting.SqlDatabaseTestActions();
            this.PayScheduleExistsForEachGradeInInventory_RWOData = new Microsoft.Data.Tools.Schema.Sql.UnitTesting.SqlDatabaseTestActions();
            PayScheduleExistsForEachGradeInInventory_AE_TestAction = new Microsoft.Data.Tools.Schema.Sql.UnitTesting.SqlDatabaseTestAction();
            emptyResultSetCondition1 = new Microsoft.Data.Tools.Schema.Sql.UnitTesting.Conditions.EmptyResultSetCondition();
            PayScheduleExistsForEachGradeInInventory_AO_TestAction = new Microsoft.Data.Tools.Schema.Sql.UnitTesting.SqlDatabaseTestAction();
            emptyResultSetCondition2 = new Microsoft.Data.Tools.Schema.Sql.UnitTesting.Conditions.EmptyResultSetCondition();
            PayScheduleExistsForEachGradeInInventory_AWO_TestAction = new Microsoft.Data.Tools.Schema.Sql.UnitTesting.SqlDatabaseTestAction();
            emptyResultSetCondition3 = new Microsoft.Data.Tools.Schema.Sql.UnitTesting.Conditions.EmptyResultSetCondition();
            PayScheduleExistsForEachGradeInInventory_NE_TestAction = new Microsoft.Data.Tools.Schema.Sql.UnitTesting.SqlDatabaseTestAction();
            emptyResultSetCondition4 = new Microsoft.Data.Tools.Schema.Sql.UnitTesting.Conditions.EmptyResultSetCondition();
            PayScheduleExistsForEachGradeInInventory_NO_TestAction = new Microsoft.Data.Tools.Schema.Sql.UnitTesting.SqlDatabaseTestAction();
            emptyResultSetCondition5 = new Microsoft.Data.Tools.Schema.Sql.UnitTesting.Conditions.EmptyResultSetCondition();
            PayScheduleExistsForEachGradeInInventory_NWO_TestAction = new Microsoft.Data.Tools.Schema.Sql.UnitTesting.SqlDatabaseTestAction();
            emptyResultSetCondition6 = new Microsoft.Data.Tools.Schema.Sql.UnitTesting.Conditions.EmptyResultSetCondition();
            PayScheduleExistsForEachGradeInInventory_RE_TestAction = new Microsoft.Data.Tools.Schema.Sql.UnitTesting.SqlDatabaseTestAction();
            emptyResultSetCondition7 = new Microsoft.Data.Tools.Schema.Sql.UnitTesting.Conditions.EmptyResultSetCondition();
            PayScheduleExistsForEachGradeInInventory_RO_TestAction = new Microsoft.Data.Tools.Schema.Sql.UnitTesting.SqlDatabaseTestAction();
            emptyResultSetCondition8 = new Microsoft.Data.Tools.Schema.Sql.UnitTesting.Conditions.EmptyResultSetCondition();
            PayScheduleExistsForEachGradeInInventory_RWO_TestAction = new Microsoft.Data.Tools.Schema.Sql.UnitTesting.SqlDatabaseTestAction();
            emptyResultSetCondition9 = new Microsoft.Data.Tools.Schema.Sql.UnitTesting.Conditions.EmptyResultSetCondition();
            // 
            // PayScheduleExistsForEachGradeInInventory_AE_TestAction
            // 
            PayScheduleExistsForEachGradeInInventory_AE_TestAction.Conditions.Add(emptyResultSetCondition1);
            resources.ApplyResources(PayScheduleExistsForEachGradeInInventory_AE_TestAction, "PayScheduleExistsForEachGradeInInventory_AE_TestAction");
            // 
            // emptyResultSetCondition1
            // 
            emptyResultSetCondition1.Enabled = true;
            emptyResultSetCondition1.Name = "emptyResultSetCondition1";
            emptyResultSetCondition1.ResultSet = 1;
            // 
            // PayScheduleExistsForEachGradeInInventory_AO_TestAction
            // 
            PayScheduleExistsForEachGradeInInventory_AO_TestAction.Conditions.Add(emptyResultSetCondition2);
            resources.ApplyResources(PayScheduleExistsForEachGradeInInventory_AO_TestAction, "PayScheduleExistsForEachGradeInInventory_AO_TestAction");
            // 
            // emptyResultSetCondition2
            // 
            emptyResultSetCondition2.Enabled = true;
            emptyResultSetCondition2.Name = "emptyResultSetCondition2";
            emptyResultSetCondition2.ResultSet = 1;
            // 
            // PayScheduleExistsForEachGradeInInventory_AWO_TestAction
            // 
            PayScheduleExistsForEachGradeInInventory_AWO_TestAction.Conditions.Add(emptyResultSetCondition3);
            resources.ApplyResources(PayScheduleExistsForEachGradeInInventory_AWO_TestAction, "PayScheduleExistsForEachGradeInInventory_AWO_TestAction");
            // 
            // emptyResultSetCondition3
            // 
            emptyResultSetCondition3.Enabled = true;
            emptyResultSetCondition3.Name = "emptyResultSetCondition3";
            emptyResultSetCondition3.ResultSet = 1;
            // 
            // PayScheduleExistsForEachGradeInInventory_NE_TestAction
            // 
            PayScheduleExistsForEachGradeInInventory_NE_TestAction.Conditions.Add(emptyResultSetCondition4);
            resources.ApplyResources(PayScheduleExistsForEachGradeInInventory_NE_TestAction, "PayScheduleExistsForEachGradeInInventory_NE_TestAction");
            // 
            // emptyResultSetCondition4
            // 
            emptyResultSetCondition4.Enabled = true;
            emptyResultSetCondition4.Name = "emptyResultSetCondition4";
            emptyResultSetCondition4.ResultSet = 1;
            // 
            // PayScheduleExistsForEachGradeInInventory_NO_TestAction
            // 
            PayScheduleExistsForEachGradeInInventory_NO_TestAction.Conditions.Add(emptyResultSetCondition5);
            resources.ApplyResources(PayScheduleExistsForEachGradeInInventory_NO_TestAction, "PayScheduleExistsForEachGradeInInventory_NO_TestAction");
            // 
            // emptyResultSetCondition5
            // 
            emptyResultSetCondition5.Enabled = true;
            emptyResultSetCondition5.Name = "emptyResultSetCondition5";
            emptyResultSetCondition5.ResultSet = 1;
            // 
            // PayScheduleExistsForEachGradeInInventory_NWO_TestAction
            // 
            PayScheduleExistsForEachGradeInInventory_NWO_TestAction.Conditions.Add(emptyResultSetCondition6);
            resources.ApplyResources(PayScheduleExistsForEachGradeInInventory_NWO_TestAction, "PayScheduleExistsForEachGradeInInventory_NWO_TestAction");
            // 
            // emptyResultSetCondition6
            // 
            emptyResultSetCondition6.Enabled = true;
            emptyResultSetCondition6.Name = "emptyResultSetCondition6";
            emptyResultSetCondition6.ResultSet = 1;
            // 
            // PayScheduleExistsForEachGradeInInventory_RE_TestAction
            // 
            PayScheduleExistsForEachGradeInInventory_RE_TestAction.Conditions.Add(emptyResultSetCondition7);
            resources.ApplyResources(PayScheduleExistsForEachGradeInInventory_RE_TestAction, "PayScheduleExistsForEachGradeInInventory_RE_TestAction");
            // 
            // emptyResultSetCondition7
            // 
            emptyResultSetCondition7.Enabled = true;
            emptyResultSetCondition7.Name = "emptyResultSetCondition7";
            emptyResultSetCondition7.ResultSet = 1;
            // 
            // PayScheduleExistsForEachGradeInInventory_RO_TestAction
            // 
            PayScheduleExistsForEachGradeInInventory_RO_TestAction.Conditions.Add(emptyResultSetCondition8);
            resources.ApplyResources(PayScheduleExistsForEachGradeInInventory_RO_TestAction, "PayScheduleExistsForEachGradeInInventory_RO_TestAction");
            // 
            // emptyResultSetCondition8
            // 
            emptyResultSetCondition8.Enabled = true;
            emptyResultSetCondition8.Name = "emptyResultSetCondition8";
            emptyResultSetCondition8.ResultSet = 1;
            // 
            // PayScheduleExistsForEachGradeInInventory_RWO_TestAction
            // 
            PayScheduleExistsForEachGradeInInventory_RWO_TestAction.Conditions.Add(emptyResultSetCondition9);
            resources.ApplyResources(PayScheduleExistsForEachGradeInInventory_RWO_TestAction, "PayScheduleExistsForEachGradeInInventory_RWO_TestAction");
            // 
            // emptyResultSetCondition9
            // 
            emptyResultSetCondition9.Enabled = true;
            emptyResultSetCondition9.Name = "emptyResultSetCondition9";
            emptyResultSetCondition9.ResultSet = 1;
            // 
            // PayScheduleExistsForEachGradeInInventory_AEData
            // 
            this.PayScheduleExistsForEachGradeInInventory_AEData.PosttestAction = null;
            this.PayScheduleExistsForEachGradeInInventory_AEData.PretestAction = null;
            this.PayScheduleExistsForEachGradeInInventory_AEData.TestAction = PayScheduleExistsForEachGradeInInventory_AE_TestAction;
            // 
            // PayScheduleExistsForEachGradeInInventory_AOData
            // 
            this.PayScheduleExistsForEachGradeInInventory_AOData.PosttestAction = null;
            this.PayScheduleExistsForEachGradeInInventory_AOData.PretestAction = null;
            this.PayScheduleExistsForEachGradeInInventory_AOData.TestAction = PayScheduleExistsForEachGradeInInventory_AO_TestAction;
            // 
            // PayScheduleExistsForEachGradeInInventory_AWOData
            // 
            this.PayScheduleExistsForEachGradeInInventory_AWOData.PosttestAction = null;
            this.PayScheduleExistsForEachGradeInInventory_AWOData.PretestAction = null;
            this.PayScheduleExistsForEachGradeInInventory_AWOData.TestAction = PayScheduleExistsForEachGradeInInventory_AWO_TestAction;
            // 
            // PayScheduleExistsForEachGradeInInventory_NEData
            // 
            this.PayScheduleExistsForEachGradeInInventory_NEData.PosttestAction = null;
            this.PayScheduleExistsForEachGradeInInventory_NEData.PretestAction = null;
            this.PayScheduleExistsForEachGradeInInventory_NEData.TestAction = PayScheduleExistsForEachGradeInInventory_NE_TestAction;
            // 
            // PayScheduleExistsForEachGradeInInventory_NOData
            // 
            this.PayScheduleExistsForEachGradeInInventory_NOData.PosttestAction = null;
            this.PayScheduleExistsForEachGradeInInventory_NOData.PretestAction = null;
            this.PayScheduleExistsForEachGradeInInventory_NOData.TestAction = PayScheduleExistsForEachGradeInInventory_NO_TestAction;
            // 
            // PayScheduleExistsForEachGradeInInventory_NWOData
            // 
            this.PayScheduleExistsForEachGradeInInventory_NWOData.PosttestAction = null;
            this.PayScheduleExistsForEachGradeInInventory_NWOData.PretestAction = null;
            this.PayScheduleExistsForEachGradeInInventory_NWOData.TestAction = PayScheduleExistsForEachGradeInInventory_NWO_TestAction;
            // 
            // PayScheduleExistsForEachGradeInInventory_REData
            // 
            this.PayScheduleExistsForEachGradeInInventory_REData.PosttestAction = null;
            this.PayScheduleExistsForEachGradeInInventory_REData.PretestAction = null;
            this.PayScheduleExistsForEachGradeInInventory_REData.TestAction = PayScheduleExistsForEachGradeInInventory_RE_TestAction;
            // 
            // PayScheduleExistsForEachGradeInInventory_ROData
            // 
            this.PayScheduleExistsForEachGradeInInventory_ROData.PosttestAction = null;
            this.PayScheduleExistsForEachGradeInInventory_ROData.PretestAction = null;
            this.PayScheduleExistsForEachGradeInInventory_ROData.TestAction = PayScheduleExistsForEachGradeInInventory_RO_TestAction;
            // 
            // PayScheduleExistsForEachGradeInInventory_RWOData
            // 
            this.PayScheduleExistsForEachGradeInInventory_RWOData.PosttestAction = null;
            this.PayScheduleExistsForEachGradeInInventory_RWOData.PretestAction = null;
            this.PayScheduleExistsForEachGradeInInventory_RWOData.TestAction = PayScheduleExistsForEachGradeInInventory_RWO_TestAction;
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
        private SqlDatabaseTestActions PayScheduleExistsForEachGradeInInventory_AEData;
        private SqlDatabaseTestActions PayScheduleExistsForEachGradeInInventory_AOData;
        private SqlDatabaseTestActions PayScheduleExistsForEachGradeInInventory_AWOData;
        private SqlDatabaseTestActions PayScheduleExistsForEachGradeInInventory_NEData;
        private SqlDatabaseTestActions PayScheduleExistsForEachGradeInInventory_NOData;
        private SqlDatabaseTestActions PayScheduleExistsForEachGradeInInventory_NWOData;
        private SqlDatabaseTestActions PayScheduleExistsForEachGradeInInventory_REData;
        private SqlDatabaseTestActions PayScheduleExistsForEachGradeInInventory_ROData;
        private SqlDatabaseTestActions PayScheduleExistsForEachGradeInInventory_RWOData;
    }
}
