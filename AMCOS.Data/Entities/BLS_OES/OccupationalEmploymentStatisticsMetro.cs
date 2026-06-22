namespace AMCOS.Data.Entities
{
    public class OccupationalEmploymentStatisticsMetro
    {
        public string SOC { get; set; }
        public string MSACode { get; set; }
        public int Tot_Emp { get; set; }
        public decimal Emp_Prse { get; set; }
        public decimal A_Mean { get; set; }
        public decimal Mean_Prse { get; set; }
        public decimal A_Pct10 { get; set; }
        public decimal A_Pct25 { get; set; }
        public decimal A_Median { get; set; }
        public decimal A_Pct75 { get; set; }
        public decimal A_Pct90 { get; set; }
        public int AmcosVersionId { get; set; }
        public virtual SOCStructure SOCStructure { get; set; }
        public virtual MetropolitanStatisticalArea MetropolitanStatisticalArea { get; set; }
    }
}