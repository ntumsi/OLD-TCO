using System;

namespace AMCOS.Data.Entities
{
    public class ProjectAddUnitAudit
    {
        public string UserId { get; set; }
        public DateTime CreateDate { get; set; }
        public string CategoryId { get; set; }
        public string UIC { get; set; }
        public string ExcludedPayPlans { get; set; }
        public string DataAction { get; set; }
        public string NewSubprojectName { get; set; }
        public string UnitLocation { get; set; }
        public string MtoeProjectInventoryYear { get; set; }
        public string ProjectExtendsSacsYears { get; set; }
        public string ContractorOverheadPercent { get; set; }
    }
}
