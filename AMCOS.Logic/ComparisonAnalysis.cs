using AMCOS.Data;
using System;
using System.Collections.Generic;
using System.Data;
using System.Linq;

namespace AMCOS.Logic
{
    public class ComparisonAnalysis
    {
        public static DataTable GetInternalTestInventoryGP(string payPlan, string categoryGroupCode, string categorySubgroupCode, string userId)
        {
            DataTable dt = new DataTable();
            string sqlStatement = "select GradeLevel, sum(Inventory) as Internal_Test from data.Inventory where 1=1 ";
            bool[] applyFilter = { true, true, (categorySubgroupCode != "__ALL__") };
            string[] columnNames = { "PayPlan", "CategoryGroupCode", "CategorySubGroupCode" };
            string[] columnValues = { payPlan, categoryGroupCode, categorySubgroupCode };
            string endSQL = " group by GradeLevel order by GradeLevel";

            try
            {
                dt = DataAccessUtility.GetDataTableByDynamicSql(sqlStatement, applyFilter, columnNames, columnValues, endSQL);
            }
            catch (Exception ex)
            {
                LogHelper logHelper = new LogHelper();
                logHelper.LogError(ex.Message, userId);
                throw;
            }
            return dt;
        }
        public static DataTable GetProductionInventoryGP(string payPlan, string categoryGroupCode, string categorySubgroupCode, string userId)
        {
            DataTable dt = new DataTable();
            string sqlStatement = "select GradeLevel, sum(Inventory) as Production from load_inventory.Inventory_Production where 1=1 ";
            bool[] applyFilter = { true, true, (categorySubgroupCode != "__ALL__") };
            string[] columnNames = { "PayPlan", "CategoryGroupCode", "CategorySubGroupCode" };
            string[] columnValues = { payPlan, categoryGroupCode, categorySubgroupCode };
            string endSQL = " group by GradeLevel order by GradeLevel";

            try
            {
                dt = DataAccessUtility.GetDataTableByDynamicSql(sqlStatement, applyFilter, columnNames, columnValues, endSQL);
            }
            catch (Exception ex)
            {
                LogHelper logHelper = new LogHelper();
                logHelper.LogError(ex.Message, userId);
                throw;
            }
            return dt;
        }
        public static DataTable GetInternalTestInventory(string payPlan, string categoryGroupCode, string categorySubgroupCode, string userId)
        {
            DataTable dt = new DataTable();
            string sqlStatement = "select GradeLevel, sum(Inventory) as Internal_Test from data.Inventory where 1=1 ";
            bool[] applyFilter = { true, (categoryGroupCode != "__ALL__"), (categorySubgroupCode != "__ALL__") };
            string[] columnNames = { "PayPlan", "CategoryGroupCode", "CategorySubGroupCode" };
            string[] columnValues = { payPlan, categoryGroupCode, categorySubgroupCode };
            string endSQL = " group by GradeLevel order by GradeLevel";

            try
            {
                dt = DataAccessUtility.GetDataTableByDynamicSql(sqlStatement, applyFilter, columnNames, columnValues, endSQL);
            }
            catch (Exception ex)
            {
                LogHelper logHelper = new LogHelper();
                logHelper.LogError(ex.Message, userId);
                throw;
            }
            return dt;
        }
        public static DataTable GetProductionInventory(string payPlan, string categoryGroupCode, string categorySubgroupCode, string userId)
        {
            DataTable dt = new DataTable();
            string sqlStatement = "select GradeLevel, sum(Inventory) as Production from load_inventory.Inventory_Production where 1=1 ";
            bool[] applyFilter = { true, (categoryGroupCode != "__ALL__"), (categorySubgroupCode != "__ALL__") };
            string[] columnNames = { "PayPlan", "CategoryGroupCode", "CategorySubGroupCode" };
            string[] columnValues = { payPlan, categoryGroupCode, categorySubgroupCode };
            string endSQL = " group by GradeLevel order by GradeLevel";

            try
            {
                dt = DataAccessUtility.GetDataTableByDynamicSql(sqlStatement, applyFilter, columnNames, columnValues, endSQL);
            }
            catch (Exception ex)
            {
                LogHelper logHelper = new LogHelper();
                logHelper.LogError(ex.Message, userId);
                throw;
            }
            return dt;
        }        
    }
}
