namespace AMCOS.Data.Entities
{
    public class CostSummaryElement
    {
        public int SummaryId { get; set; }
        public int CostElementId { get; set; }
        public virtual CostElement CostElement { get; set; }
        public virtual CostSummary CostSummary { get; set; }
    }
}
