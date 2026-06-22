using AMCOS.Data;
using AMCOS.Data.Entities;
using System.Collections.Generic;
using System.Collections.ObjectModel;
using System.Data;
using Npgsql;
using NpgsqlTypes;
using System.Linq;

namespace AMCOS.Logic
{
    public class ProjectCategorySkill
    {
        public string UserId { get; set; }
        public int ProjectId { get; set; }
        public int CategoryId { get; set; }
        public string PayPlan { get; set; }
        public string CategoryGroupCode { get; set; }
        public string CategorySubgroupCode { get; set; }
        public string CareerProgramNumber { get; set; }
        public int LocationId { get; set; }
        public string STRL { get; set; }
        public byte GradeLevel { get; set; }
        public string DependentStatus { get; set; }
        public short? ActiveDutyDays { get; set; }
        public double OverheadPercent { get; set; }
        public ProjectCategorySkill()
        {
            //Default constructor
        }
        public ProjectCategorySkill(int categoryId, string payPlan, string categoryGroupCode, string categorySubgroupCode, string careerProgramNumber, int locationId, string sTRL, byte gradeLevel, string dependentStatus, short? activeDutyDays, double overheadPercent)
        {
            CategoryId = categoryId;
            PayPlan = payPlan;
            CategoryGroupCode = categoryGroupCode;
            CategorySubgroupCode = categorySubgroupCode;
            CareerProgramNumber = careerProgramNumber;
            LocationId = locationId;
            STRL = sTRL;
            GradeLevel = gradeLevel;
            DependentStatus = dependentStatus;
            ActiveDutyDays = activeDutyDays;
            OverheadPercent = overheadPercent;
        }

        
        public PMCategorySkill GetSkill(int skillId)
        {
            using (var context = new ApplicationDbContext())
            {
                return context.PMCategorySkill.AsNoTracking()
                    .Where(c => c.SkillId == skillId)
                    .First();
            }
        }
        
        public Collection<string> GetPayPlans(int categoryId)
        {
            using (var context = new ApplicationDbContext())
            {
                var query = from c in context.PMCategorySkill
                            where c.CategoryId == categoryId
                            select c.PayPlan;
                query.Distinct();

                Collection<string> payPlanList = new Collection<string>();
                foreach (var PayPlan in query)
                {
                    payPlanList.Add(PayPlan.ToString());
                }

                return payPlanList;
            }
        }
        private static PMCategorySkill MapSkill(NpgsqlDataReader reader)
        {
            PMCategorySkill skill = new PMCategorySkill();

            if (!reader.IsDBNull(reader.GetOrdinal("SkillID")))
            {
                skill.SkillId = reader.GetInt32(reader.GetOrdinal("SkillID"));
            }

            if (!reader.IsDBNull(reader.GetOrdinal("CategoryID")))
            {
                skill.CategoryId = reader.GetInt32(reader.GetOrdinal("CategoryID"));
            }

            if (!reader.IsDBNull(reader.GetOrdinal("PayPlan")))
            {
                skill.PayPlan = reader.GetString(reader.GetOrdinal("PayPlan"));
            }

            if (!reader.IsDBNull(reader.GetOrdinal("CategoryGroupCode")))
            {
                skill.CategoryGroupCode = reader.GetString(reader.GetOrdinal("CategoryGroupCode"));
            }

            if (!reader.IsDBNull(reader.GetOrdinal("CategorySubgroupCode")))
            {
                skill.CategorySubgroupCode = reader.GetString(reader.GetOrdinal("CategorySubgroupCode"));
            }

            if (!reader.IsDBNull(reader.GetOrdinal("GradeLevel")))
            {
                skill.GradeLevel = reader.GetByte(reader.GetOrdinal("GradeLevel"));
            }

            if (!reader.IsDBNull(reader.GetOrdinal("ActiveDutyDays")))
                if (reader.GetInt16(reader.GetOrdinal("ActiveDutyDays")) != 0)
                {
                    skill.ActiveDutyDays = reader.GetInt16(reader.GetOrdinal("ActiveDutyDays"));
                }

            if (!reader.IsDBNull(reader.GetOrdinal("OverheadPercent")))
                if (skill.PayPlan == "CCE")
                {
                    skill.OverheadPercent = reader.GetDouble(reader.GetOrdinal("OverheadPercent"));
                }

            return skill;
        }
        private static string GradeType(string payPlan)
        {
            switch (payPlan)
            {
                case "AE":
                case "RE":
                case "NE":
                    return "E";
                case "AO":
                case "RO":
                case "NO":
                    return "O";
                case "AWO":
                case "RWO":
                case "NWO":
                    return "W";
                default:
                    return payPlan;
            }
        }
    }
}
