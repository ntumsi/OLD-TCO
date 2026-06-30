using AMCOS.Data;
using System;
using System.Collections.Generic;
using System.Data;
using Npgsql;
using NpgsqlTypes;
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
        // The web.GetPayPlanCrosswalk* functions return (result_set_name, row_data jsonb);
        // StoredFunction unpacks the jsonb (V1..Vn columns) into a flat DataTable. The old
        // CommandType.StoredProcedure path produced CALL (invalid on a function).
        public DataTable GetCostsAE()
        {
            return Helpers.StoredFunction.QueryAsTable("web.GetPayPlanCrosswalkAE",
                new NpgsqlParameter("@categorySubgroupCode", CategorySubgroupCode),
                new NpgsqlParameter("@gradeLevel", (short)GradeLevel),
                new NpgsqlParameter("@amcosVersionId", AmcosVersionId));
        }
        public DataTable GetCostsAO()
        {
            return Helpers.StoredFunction.QueryAsTable("web.GetPayPlanCrosswalkAO",
                new NpgsqlParameter("@categorySubgroupCode", CategorySubgroupCode),
                new NpgsqlParameter("@gradeLevel", (short)GradeLevel),
                new NpgsqlParameter("@amcosVersionId", AmcosVersionId));
        }
        public DataTable GetCostsAWO()
        {
            return Helpers.StoredFunction.QueryAsTable("web.GetPayPlanCrosswalkAWO",
                new NpgsqlParameter("@categorySubgroupCode", CategorySubgroupCode),
                new NpgsqlParameter("@gradeLevel", (short)GradeLevel),
                new NpgsqlParameter("@amcosVersionId", AmcosVersionId));
        }
        public DataTable GetCostsGS()
        {
            return Helpers.StoredFunction.QueryAsTable("web.GetPayPlanCrosswalkGS",
                new NpgsqlParameter("@categorySubgroupCode", CategorySubgroupCode),
                new NpgsqlParameter("@gradeLevel", (short)GradeLevel),
                new NpgsqlParameter("@LocationId", LocationId),
                new NpgsqlParameter("@amcosVersionId", AmcosVersionId));
        }
        public DataTable GetCostsWage()
        {
            return Helpers.StoredFunction.QueryAsTable("web.GetPayPlanCrosswalkWage",
                new NpgsqlParameter("@PayPlan", PayPlan),
                new NpgsqlParameter("@LocationId", LocationId),
                new NpgsqlParameter("@GradeLevel", (short)GradeLevel),
                new NpgsqlParameter("@AmcosVersionId", AmcosVersionId));
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
