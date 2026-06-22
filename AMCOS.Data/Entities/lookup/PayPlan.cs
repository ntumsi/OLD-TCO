using System.Collections.Generic;

namespace AMCOS.Data.Entities
{
    public class PayPlan
    {
        public string Name { get; set; }
        public int AmcosVersionIdStart { get; set; }
        public int AmcosVersionIdEnd { get; set; }
        public string DisplayTitle { get; set; }
        public string GroupTitle { get; set; }
        public string Description { get; set; }
        public string CategoryGroupLabel { get; set; }
        public string CategorySubgroupLabel { get; set; }
        public bool IncludeArmyCareerPrograms { get; set; }
        public string Explanation { get; set; }
        public decimal? DisplaySequence { get; set; }
        public ICollection<Costs> Costs { get; }
    }
}
