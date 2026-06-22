namespace AMCOS.Data.Entities
{
    public class ViewPMCategorySkill
    {
        public string UserId { get; set; }
        public int ProjectId { get; set; }
        public string ProjectName { get; set; }
        public string CategoryName { get; set; }
        public int CategoryId { get; set; }
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
    }
}
