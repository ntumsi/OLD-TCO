using System.Collections.Generic;

namespace AMCOS.Data.Entities
{
    public class SOCStructure
    {
        public string OccupationCode { get; set; }
        public string GroupLevel { get; set; }
        public string OccupationTitle { get; set; }
        public string Definition { get; set; }
        public int AmcosVersionIdStart { get; set; }
        public int AmcosVersionIdEnd { get; set; }
        public virtual ICollection<OccupationalEmploymentStatisticsMetro> OccupationalEmploymentStatisticsMetros { get; }
    }
}
