namespace AMCOS.Data.Entities
{
    using System.Collections.Generic;

    public class GFEBSFunctionalArea
    {
        public string FunctionalAreaCode { get; set; }
        public string FunctionalAreaText { get; set; }
        public virtual ICollection<Costs> Costs { get; }
    }
}