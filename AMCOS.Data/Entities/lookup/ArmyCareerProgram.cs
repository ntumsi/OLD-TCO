using System.Collections.Generic;

namespace AMCOS.Data.Entities
{
    public class ArmyCareerProgram
    {
        public string CareerProgramNumber { get; set; }
        public string Title { get; set; }
        public int AmcosVersionIdStart { get; set; }
        public int AmcosVersionIdEnd { get; set; }
        public virtual ICollection<Costs> Costs { get; }
    }
}
