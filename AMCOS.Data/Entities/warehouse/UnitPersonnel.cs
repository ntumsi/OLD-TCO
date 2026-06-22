namespace AMCOS.Data.Entities
{
    public class UnitPersonnel
    {
        public string UIC { get; set; }
        public string UICTitle { get; set; }
        public string PayPlan { get; set; }
        public string CategoryGroupCode { get; set; }
        public string CategorySubgroupCode { get; set; }
        public int LocationId { get; set; }
        public string LocationText { get; set; }
        public string STRL { get; set; }
        public byte GradeLevel { get; set; }
        public string DependentStatus { get; set; }
        public int NumberOfDependents { get; set; }
        public short ActiveDutyDays { get; set; }
        public double OverheadPercent { get; set; }
        public int Inventory { get; set; }
        public string UnitYear { get; set; }
        public string AsOf { get; set; }
        public string AuthorizationDocument { get; set; }
    }
}
