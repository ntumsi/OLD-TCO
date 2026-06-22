using System.Collections.Generic;

namespace AMCOS.Data.Entities
{
    public class PMCategorySkill
    {
        public int SkillId { get; set; }
        public int CategoryId { get; set; }
        public string Uic { get; set; }
        public string PayPlan { get; set; }
        public string CategoryGroupCode { get; set; }
        public string CategorySubgroupCode { get; set; }
        public string CareerProgramNumber { get; set; }
        public int LocationId { get; set; }
        public string LocationText { get; set; }
        public string STRL { get; set; }
        public byte GradeLevel { get; set; }
        public string DependentStatus { get; set; }
        public int NumberOfDependents { get; set; }
        public short ActiveDutyDays { get; set; }
        public double OverheadPercent { get; set; }

        public string Grade
        {
            get
            {
                switch (PayPlan)
                {
                    case "SES":
                        switch (GradeLevel)
                        {
                            case 1:
                                return "MIN";
                            case 2:
                                return "AVG";
                            case 3:
                                return "MAX";
                            default:
                                return "";
                        }
                    case "CCE":
                        switch (GradeLevel)
                        {
                            case 1:
                                return "A_PCT10";
                            case 2:
                                return "A_PCT25";
                            case 3:
                                return "A_MEDIAN";
                            case 4:
                                return "A_PCT75";
                            case 5:
                                return "A_PCT90";
                            default:
                                return "";
                        }
                    default:
                        return PayPlan.ToString() + GradeLevel.ToString();
                }
            }
        }
        public virtual ICollection<PMCategorySkillInventory> Inventories { get; }
    }
}
