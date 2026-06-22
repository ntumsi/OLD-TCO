namespace AMCOS.Data.Entities
{
    public class PaySchedules
    {
        public string PayPlan { get; set; }
        public string CategoryGroupCode { get; set; }
        public string CategorySubgroupCode { get; set; }
        public int LocationId { get; set; }
        public string Strl { get; set; }
        public string GradeType { get; set; }
        public byte GradeLevel { get; set; }
        public int Step { get; set; }
        public int YOS { get; set; }        
        public decimal? Rate { get; set; }
        public string RateType { get; set; }
        public int AmcosVersionId { get; set; }
        public virtual Location LocationLookup { get; set; }
    }
}