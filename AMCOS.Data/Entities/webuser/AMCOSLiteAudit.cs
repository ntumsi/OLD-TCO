using System;

namespace AMCOS.Data.Entities
{
    public class AMCOSLiteAudit
    {
        public string UserId { get; set; }
        public DateTime CreateDate { get; set; }
        public string PageAction { get; set; }
        public string PageElement { get; set; }
        public string PayPlan { get; set; }
        public string CostSummaryName { get; set; }
        public string CategoryGroupCode { get; set; }
        public string CategorySubgroupCode { get; set; }
        public string CareerProgramNumber { get; set; }
        public int LocationId { get; set; }
        public string LocationText { get; set; }
        public string STRL { get; set; }
        public string DependentStatus { get; set; }
        public int NumberOfDependents { get; set; }
        public float? OverheadPercent { get; set; }
        public string InflationConversionType { get; set; }
        public string InflationYear { get; set; }
    }
}
