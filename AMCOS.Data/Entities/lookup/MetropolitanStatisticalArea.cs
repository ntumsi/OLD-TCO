namespace AMCOS.Data.Entities
{
    using System.Collections.Generic;

    public class MetropolitanStatisticalArea
    {
        public string MSACode { get; set; }
        public string MSAName { get; set; }
        public int AmcosVersionIdStart { get; set; }
        public int AmcosVersionIdEnd { get; set; }
        public virtual ICollection<OccupationalEmploymentStatisticsMetro> OccupationalEmploymentStatisticsMetros { get; }
    }
}