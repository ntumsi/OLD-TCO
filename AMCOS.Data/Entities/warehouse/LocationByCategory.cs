namespace AMCOS.Data.Entities
{
    public class LocationByCategory
    {
        public int Id { get; set; }
        public string PayPlan { get; set; }
        public string CategoryGroupCode { get; set; }
        public string CategorySubgroupCode { get; set; }
        public string CareerProgramNumber { get; set; }
        public int LocationId { get; set; }
        public string OconusMHA { get; set; }
        public string ConusMHA { get; set; }
        public string Installation { get; set; }
        public string LocalityPayArea { get; set; }
        public string SpecialPayArea { get; set; }
        public string Country { get; set; }
        public string WageSchedule { get; set; }
        public string CityCounty { get; set; }
        public string MSA { get; set; }
        public string STRL { get; set; }
        public string CivOverseas { get; set; }
    }
}
