using System.Collections.Generic;

namespace AMCOS.Data.Entities
{
    public class CategorySubgroup
    {
        public string PayPlan { get; set; }
        public string CategoryGroupCode { get; set; }
        public string CategoryGroupDescription { get; set; }
        public string CategorySubgroupCode { get; set; }
        public string CategorySubgroupDescription { get; set; }
        public virtual ICollection<Costs> Costs { get; }
    }
}
