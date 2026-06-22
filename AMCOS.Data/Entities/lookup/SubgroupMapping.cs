using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace AMCOS.Data.Entities
{
    public class SubgroupMapping
    {
        public string PayPlan { get; set; }
        public string CategorySubgroupCode { get; set; }
        public string ToPayPlan { get; set; }
        public string ToCategorySubgroupCode { get; set; }
        public int AmcosVersionIdStart { get; set; }
        public int AmcosVersionIdEnd { get; set; }

    }
}
