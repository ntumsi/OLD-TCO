using Microsoft.Data.Tools.Schema.Sql.UnitTesting;
using Microsoft.VisualStudio.TestTools.UnitTesting;

namespace AMCOS.Tests
{
    [TestClass()]
    public class InventoryTest : SqlDatabaseTestClass
    {

        public InventoryTest()
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

        #region Designer support code

        /// <summary> 
        /// Required method for Designer support - do not modify 
        /// the contents of this method with the code editor.
        /// </summary>
        private void InitializeComponent()
        {
            Microsoft.Data.Tools.Schema.Sql.UnitTesting.SqlDatabaseTestAction test_O9ExistsInInventoryForARNGTest_TestAction;
            System.ComponentModel.ComponentResourceManager resources = new System.ComponentModel.ComponentResourceManager(typeof(InventoryTest));
            Microsoft.Data.Tools.Schema.Sql.UnitTesting.Conditions.ScalarValueCondition scalarValueCondition2;
            Microsoft.Data.Tools.Schema.Sql.UnitTesting.SqlDatabaseTestAction test_O9ExistsInInventoryForUSARTest_TestAction;
            Microsoft.Data.Tools.Schema.Sql.UnitTesting.Conditions.ScalarValueCondition scalarValueCondition3;
            Microsoft.Data.Tools.Schema.Sql.UnitTesting.SqlDatabaseTestAction test_AtLeastSix010ExistsInInventoryForActiveArmyTest_TestAction;
            Microsoft.Data.Tools.Schema.Sql.UnitTesting.Conditions.ScalarValueCondition scalarValueCondition1;
            Microsoft.Data.Tools.Schema.Sql.UnitTesting.SqlDatabaseTestAction test_O10ExistsInInventoryForARNGTest_TestAction;
            Microsoft.Data.Tools.Schema.Sql.UnitTesting.Conditions.ScalarValueCondition scalarValueCondition4;
            this.test_O9ExistsInInventoryForARNGTestData = new Microsoft.Data.Tools.Schema.Sql.UnitTesting.SqlDatabaseTestActions();
            this.test_O9ExistsInInventoryForUSARTestData = new Microsoft.Data.Tools.Schema.Sql.UnitTesting.SqlDatabaseTestActions();
            this.test_AtLeastSix010ExistsInInventoryForActiveArmyTestData = new Microsoft.Data.Tools.Schema.Sql.UnitTesting.SqlDatabaseTestActions();
            this.test_O10ExistsInInventoryForARNGTestData = new Microsoft.Data.Tools.Schema.Sql.UnitTesting.SqlDatabaseTestActions();
            test_O9ExistsInInventoryForARNGTest_TestAction = new Microsoft.Data.Tools.Schema.Sql.UnitTesting.SqlDatabaseTestAction();
            scalarValueCondition2 = new Microsoft.Data.Tools.Schema.Sql.UnitTesting.Conditions.ScalarValueCondition();
            test_O9ExistsInInventoryForUSARTest_TestAction = new Microsoft.Data.Tools.Schema.Sql.UnitTesting.SqlDatabaseTestAction();
            scalarValueCondition3 = new Microsoft.Data.Tools.Schema.Sql.UnitTesting.Conditions.ScalarValueCondition();
            test_AtLeastSix010ExistsInInventoryForActiveArmyTest_TestAction = new Microsoft.Data.Tools.Schema.Sql.UnitTesting.SqlDatabaseTestAction();
            scalarValueCondition1 = new Microsoft.Data.Tools.Schema.Sql.UnitTesting.Conditions.ScalarValueCondition();
            test_O10ExistsInInventoryForARNGTest_TestAction = new Microsoft.Data.Tools.Schema.Sql.UnitTesting.SqlDatabaseTestAction();
            scalarValueCondition4 = new Microsoft.Data.Tools.Schema.Sql.UnitTesting.Conditions.ScalarValueCondition();
            // 
            // test_O9ExistsInInventoryForARNGTest_TestAction
            // 
            test_O9ExistsInInventoryForARNGTest_TestAction.Conditions.Add(scalarValueCondition2);
            resources.ApplyResources(test_O9ExistsInInventoryForARNGTest_TestAction, "test_O9ExistsInInventoryForARNGTest_TestAction");
            // 
            // scalarValueCondition2
            // 
            scalarValueCondition2.ColumnNumber = 1;
            scalarValueCondition2.Enabled = true;
            scalarValueCondition2.ExpectedValue = "True";
            scalarValueCondition2.Name = "scalarValueCondition2";
            scalarValueCondition2.NullExpected = false;
            scalarValueCondition2.ResultSet = 1;
            scalarValueCondition2.RowNumber = 1;
            // 
            // test_O9ExistsInInventoryForUSARTest_TestAction
            // 
            test_O9ExistsInInventoryForUSARTest_TestAction.Conditions.Add(scalarValueCondition3);
            resources.ApplyResources(test_O9ExistsInInventoryForUSARTest_TestAction, "test_O9ExistsInInventoryForUSARTest_TestAction");
            // 
            // scalarValueCondition3
            // 
            scalarValueCondition3.ColumnNumber = 1;
            scalarValueCondition3.Enabled = true;
            scalarValueCondition3.ExpectedValue = "True";
            scalarValueCondition3.Name = "scalarValueCondition3";
            scalarValueCondition3.NullExpected = false;
            scalarValueCondition3.ResultSet = 1;
            scalarValueCondition3.RowNumber = 1;
            // 
            // test_AtLeastSix010ExistsInInventoryForActiveArmyTest_TestAction
            // 
            test_AtLeastSix010ExistsInInventoryForActiveArmyTest_TestAction.Conditions.Add(scalarValueCondition1);
            resources.ApplyResources(test_AtLeastSix010ExistsInInventoryForActiveArmyTest_TestAction, "test_AtLeastSix010ExistsInInventoryForActiveArmyTest_TestAction");
            // 
            // scalarValueCondition1
            // 
            scalarValueCondition1.ColumnNumber = 1;
            scalarValueCondition1.Enabled = true;
            scalarValueCondition1.ExpectedValue = "True";
            scalarValueCondition1.Name = "scalarValueCondition1";
            scalarValueCondition1.NullExpected = false;
            scalarValueCondition1.ResultSet = 1;
            scalarValueCondition1.RowNumber = 1;
            // 
            // test_O10ExistsInInventoryForARNGTest_TestAction
            // 
            test_O10ExistsInInventoryForARNGTest_TestAction.Conditions.Add(scalarValueCondition4);
            resources.ApplyResources(test_O10ExistsInInventoryForARNGTest_TestAction, "test_O10ExistsInInventoryForARNGTest_TestAction");
            // 
            // scalarValueCondition4
            // 
            scalarValueCondition4.ColumnNumber = 1;
            scalarValueCondition4.Enabled = true;
            scalarValueCondition4.ExpectedValue = "True";
            scalarValueCondition4.Name = "scalarValueCondition4";
            scalarValueCondition4.NullExpected = false;
            scalarValueCondition4.ResultSet = 1;
            scalarValueCondition4.RowNumber = 1;
            // 
            // test_O9ExistsInInventoryForARNGTestData
            // 
            this.test_O9ExistsInInventoryForARNGTestData.PosttestAction = null;
            this.test_O9ExistsInInventoryForARNGTestData.PretestAction = null;
            this.test_O9ExistsInInventoryForARNGTestData.TestAction = test_O9ExistsInInventoryForARNGTest_TestAction;
            // 
            // test_O9ExistsInInventoryForUSARTestData
            // 
            this.test_O9ExistsInInventoryForUSARTestData.PosttestAction = null;
            this.test_O9ExistsInInventoryForUSARTestData.PretestAction = null;
            this.test_O9ExistsInInventoryForUSARTestData.TestAction = test_O9ExistsInInventoryForUSARTest_TestAction;
            // 
            // test_AtLeastSix010ExistsInInventoryForActiveArmyTestData
            // 
            this.test_AtLeastSix010ExistsInInventoryForActiveArmyTestData.PosttestAction = null;
            this.test_AtLeastSix010ExistsInInventoryForActiveArmyTestData.PretestAction = null;
            this.test_AtLeastSix010ExistsInInventoryForActiveArmyTestData.TestAction = test_AtLeastSix010ExistsInInventoryForActiveArmyTest_TestAction;
            // 
            // test_O10ExistsInInventoryForARNGTestData
            // 
            this.test_O10ExistsInInventoryForARNGTestData.PosttestAction = null;
            this.test_O10ExistsInInventoryForARNGTestData.PretestAction = null;
            this.test_O10ExistsInInventoryForARNGTestData.TestAction = test_O10ExistsInInventoryForARNGTest_TestAction;
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
        [TestMethod()]
        public void test_O9ExistsInInventoryForARNGTest()
        {
            SqlDatabaseTestActions testActions = this.test_O9ExistsInInventoryForARNGTestData;
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
        public void test_O9ExistsInInventoryForUSARTest()
        {
            SqlDatabaseTestActions testActions = this.test_O9ExistsInInventoryForUSARTestData;
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
        public void test_AtLeastSix010ExistsInInventoryForActiveArmyTest()
        {
            SqlDatabaseTestActions testActions = this.test_AtLeastSix010ExistsInInventoryForActiveArmyTestData;
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
        [Ignore]
        [TestMethod()]
        public void test_O10ExistsInInventoryForARNGTest()
        {
            SqlDatabaseTestActions testActions = this.test_O10ExistsInInventoryForARNGTestData;
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

        private SqlDatabaseTestActions test_O9ExistsInInventoryForARNGTestData;
        private SqlDatabaseTestActions test_O9ExistsInInventoryForUSARTestData;
        private SqlDatabaseTestActions test_AtLeastSix010ExistsInInventoryForActiveArmyTestData;
        private SqlDatabaseTestActions test_O10ExistsInInventoryForARNGTestData;
    }
}
