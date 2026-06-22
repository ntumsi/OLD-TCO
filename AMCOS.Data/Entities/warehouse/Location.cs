using System.Collections.Generic;

namespace AMCOS.Data.Entities
{
    public class Location
    {
        public int LocationId { get; set; }
        public string SourceSystemCode { get; set; }
        public string LocationType { get; set; }
        public string DisplayName { get; set; }
        public ICollection<PaySchedules> PaySchedules { get; }
        public ICollection<Inventory> Inventory { get; }
    }
}