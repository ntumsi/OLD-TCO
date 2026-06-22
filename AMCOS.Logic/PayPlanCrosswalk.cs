using AMCOS.Data;
using System;
using System.Collections.Generic;
using System.Configuration;
using System.Data;
using System.Data.SqlClient;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace AMCOS.Logic
{
    public class PayPlanCrosswalk
    {
        //Default constructor
        public PayPlanCrosswalk()
        {            
        }
        public PayPlanCrosswalk(string categorySubgroupCode, byte gradeLevel, int amcosVersionId)
        {
            CategorySubgroupCode = categorySubgroupCode;
            GradeLevel = gradeLevel;
            AmcosVersionId = amcosVersionId;
        }

        public PayPlanCrosswalk(string categorySubgroupCode, byte gradeLevel, int locationId, int amcosVersionId)
        {
            CategorySubgroupCode = categorySubgroupCode;
            GradeLevel = gradeLevel;
            LocationId = locationId;
            AmcosVersionId = amcosVersionId;
        }
        public PayPlanCrosswalk(string payPlan, int locationId, byte gradeLevel, int amcosVersionId)
        {
            PayPlan = payPlan;
            LocationId = locationId;
            GradeLevel = gradeLevel;
            AmcosVersionId = amcosVersionId;
        }
        public string PayPlan { get; set; }
        public string CategorySubgroupCode { get; set; }
        public int LocationId { get; set; }
        public byte GradeLevel { get; set; }
        public int AmcosVersionId { get; set; }
        public DataTable GetCostsAE()
        {
            DataTable payPlanCrosswalk = new DataTable();
            string sqlStatement = "web.GetPayPlanCrosswalkAE";

            using (SqlConnection connection = new SqlConnection(ConfigurationManager.ConnectionStrings["AmcosAdo"].ConnectionString))
            {
                connection.Open();
                SqlDataAdapter adapter = new SqlDataAdapter();
                using (SqlCommand command = new SqlCommand(sqlStatement, connection))
                {
                    command.Parameters.AddWithValue("@categorySubgroupCode", CategorySubgroupCode);
                    command.Parameters.AddWithValue("@gradeLevel", GradeLevel);
                    command.Parameters.AddWithValue("@amcosVersionId", AmcosVersionId);
                    command.CommandType = CommandType.StoredProcedure;
                    adapter.SelectCommand = command;
                    adapter.Fill(payPlanCrosswalk);
                }
            }
            return payPlanCrosswalk;
        }
        public DataTable GetCostsAO()
        {
            DataTable payPlanCrosswalk = new DataTable();
            string sqlStatement = "web.GetPayPlanCrosswalkAO";

            using (SqlConnection connection = new SqlConnection(ConfigurationManager.ConnectionStrings["AmcosAdo"].ConnectionString))
            {
                connection.Open();
                SqlDataAdapter adapter = new SqlDataAdapter();
                using (SqlCommand command = new SqlCommand(sqlStatement, connection))
                {
                    command.Parameters.AddWithValue("@categorySubgroupCode", CategorySubgroupCode);
                    command.Parameters.AddWithValue("@gradeLevel", GradeLevel);
                    command.Parameters.AddWithValue("@amcosVersionId", AmcosVersionId);
                    command.CommandType = CommandType.StoredProcedure;
                    adapter.SelectCommand = command;
                    adapter.Fill(payPlanCrosswalk);
                }
            }
            return payPlanCrosswalk;
        }
        public DataTable GetCostsAWO()
        {
            DataTable payPlanCrosswalk = new DataTable();
            string sqlStatement = "web.GetPayPlanCrosswalkAWO";

            using (SqlConnection connection = new SqlConnection(ConfigurationManager.ConnectionStrings["AmcosAdo"].ConnectionString))
            {
                connection.Open();
                SqlDataAdapter adapter = new SqlDataAdapter();
                using (SqlCommand command = new SqlCommand(sqlStatement, connection))
                {
                    command.Parameters.AddWithValue("@categorySubgroupCode", CategorySubgroupCode);
                    command.Parameters.AddWithValue("@gradeLevel", GradeLevel);
                    command.Parameters.AddWithValue("@amcosVersionId", AmcosVersionId);
                    command.CommandType = CommandType.StoredProcedure;
                    adapter.SelectCommand = command;
                    adapter.Fill(payPlanCrosswalk);
                }
            }
            return payPlanCrosswalk;
        }
        public DataTable GetCostsGS()
        {
            DataTable payPlanCrosswalk = new DataTable();
            string sqlStatement = "web.GetPayPlanCrosswalkGS";

            using (SqlConnection connection = new SqlConnection(ConfigurationManager.ConnectionStrings["AmcosAdo"].ConnectionString))
            {
                connection.Open();
                SqlDataAdapter adapter = new SqlDataAdapter();
                using (SqlCommand command = new SqlCommand(sqlStatement, connection))
                {
                    command.Parameters.AddWithValue("@categorySubgroupCode", CategorySubgroupCode);
                    command.Parameters.AddWithValue("@gradeLevel", GradeLevel);
                    command.Parameters.AddWithValue("@LocationId", LocationId);
                    command.Parameters.AddWithValue("@amcosVersionId", AmcosVersionId);
                    command.CommandType = CommandType.StoredProcedure;
                    adapter.SelectCommand = command;
                    adapter.Fill(payPlanCrosswalk);
                }
            }
            return payPlanCrosswalk;
        }
        public DataTable GetCostsWage()
        {
            DataTable payPlanCrosswalk = new DataTable();
            string sqlStatement = "web.GetPayPlanCrosswalkWage";

            using (SqlConnection connection = new SqlConnection(ConfigurationManager.ConnectionStrings["AmcosAdo"].ConnectionString))
            {
                connection.Open();
                SqlDataAdapter adapter = new SqlDataAdapter();
                using (SqlCommand command = new SqlCommand(sqlStatement, connection))
                {
                    command.Parameters.AddWithValue("@PayPlan", PayPlan);
                    command.Parameters.AddWithValue("@LocationId", LocationId);
                    command.Parameters.AddWithValue("@GradeLevel", GradeLevel);
                    command.Parameters.AddWithValue("@AmcosVersionId", AmcosVersionId);
                    command.CommandType = CommandType.StoredProcedure;
                    adapter.SelectCommand = command;
                    adapter.Fill(payPlanCrosswalk);
                }
            }
            return payPlanCrosswalk;
        }
        public string GetSocDefinition(string occupationCode)
        {
            using (var context = new ApplicationDbContext())
            {
                return (from s in context.SOCStructure.AsNoTracking()
                        where s.GroupLevel == "Detailed"
                        where s.OccupationCode == occupationCode
                        select s.Definition).FirstOrDefault();
            }
        }
    }
}
