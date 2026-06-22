using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace AMCOS.Data.Entities
{
    public partial class CivLocationPerDiem
    {
        public int LocationId { get; set; }
        public string SourceSystemCode { get; set; }
        public string LocationType { get; set; }
        public string DisplayName { get; set; }
        public System.Data.Entity.Spatial.DbGeography Coordinates { get; set; }
        public Nullable<int> MaxLodgingRate { get; set; }
        public Nullable<int> MIERate { get; set; }
        public Nullable<int> AmcosVersionId { get; set; }
    }
}
