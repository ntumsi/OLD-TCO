namespace AMCOS.Data.Entities
{
    using System.Collections.Generic;

    public class CostElement
    {
        public int CostElementId { get; set; }
        public string PayPlan { get; set; }
        public string Appn { get; set; }
        public string CostElementCategory { get; set; }
        public string CostElementName { get; set; }
        public int? Amort { get; set; }
        public int? Model { get; set; }
        public bool? Locality { get; set; }
        public string Description { get; set; }
        public string BusinessLogic { get; set; }
        public string BasisOfComputation { get; set; }
        public string Source { get; set; }
        public int? ShowOrder { get; set; }
        public string ArmyCesTitle { get; set; }
        public string OsdCapeCesTitle { get; set; }
        public virtual ICollection<CostSummaryElement> CostSummaryElements { get; }
    }
}
