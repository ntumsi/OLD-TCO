using System.Collections.Generic;

namespace AMCOS.Data.Entities
{
    public class Category
    {
        public string PayPlan { get; set; }
        public string CategoryGroupCode { get; set; }
        public string CategoryGroupDescription { get; set; }
        public string CategoryGroupDisplay { get; set; }
        public string CategorySubgroupCode { get; set; }
        public string CategorySubgroupDescription { get; set; }
        public string CategorySubgroupDisplay { get; set; }
        public string CareerProgramNumber { get; set; }
        public string CareerProgramDescription { get; set; }
        public string CareerProgramDisplay { get; set; }
        public virtual ICollection<Costs> Costs { get; }
    }
}
