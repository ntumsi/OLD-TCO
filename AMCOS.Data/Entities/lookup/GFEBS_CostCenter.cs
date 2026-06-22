namespace AMCOS.Data.Entities
{
    using System.Collections.Generic;

    public class GFEBSCostCenter
    {
        public string CostCenterCode { get; set; }
        public string CostCenterText { get; set; }
        public virtual ICollection<Costs> Costs { get; }
    }
}