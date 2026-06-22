namespace AMCOS.Data.Entities
{
    using System.Collections.Generic;

    public class CostSummary
    {
        public int SummaryId { get; set; }
        public string PayPlan { get; set; }
        public string Name { get; set; }
        public virtual ICollection<CostSummaryElement> CostSummaryElements { get; }
    }
}
