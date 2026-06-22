namespace AMCOS.Data.Entities
{
    public class PayScheduleMinMax
    {
        public string PayPlan { get; set; }
        public string CategoryGroupCode { get; set; }
        public string CategorySubgroupCode { get; set; }
        public string CareerProgramNumber { get; set; }
        public int LocationId { get; set; }
        public string Strl { get; set; }
        public int GradeLevel { get; set; }
        public decimal MinRate { get; set; }
        public decimal MaxRate { get; set; }
        public int AmcosVersionId { get; set; }
    }
}
