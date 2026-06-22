using System.Collections.Generic;

namespace AMCOS.Data.Entities
{
    public class CategoryGroup
    {
        public string PayPlan { get; set; }
        public string CategoryGroupCode { get; set; }
        public string CategoryGroupDescription { get; set; }
        public virtual ICollection<Costs> Costs { get; }
    }
}

