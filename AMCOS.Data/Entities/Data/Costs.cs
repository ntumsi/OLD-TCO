using System;

namespace AMCOS.Data.Entities
{
    public class Costs
    {
        public long RowId { get; set; }
        public string PayPlan { get; set; }
        public string CategoryGroupCode { get; set; }
        public string CategorySubgroupCode { get; set; }
        public string CareerProgramNumber { get; set; }
        public int LocationId { get; set; }
        public string STRL { get; set; }
        public int CostElementId { get; set; }
        public int? WeaponSystemId { get; set; }
        public string GradeType { get; set; }
        public byte GradeLevel { get; set; }
        public string DependentStatus { get; set; }
        public double? Amount { get; set; }
        public DateTime CrunchTime { get; set; }
        public int AmcosVersionId { get; set; }
        public string AppropriationGroup { get; set; }
        public string Appn { get; set; }
        public string CostElementCategory { get; set; }
        public string CostElementName { get; set; }
        public string Description { get; set; }
        public string ArmyCesTitle { get; set; }
        public string OsdCapeCesTitle { get; set; }
        public int? Amort { get; set; }
        public int? Model { get; set; }
        public bool? Locality { get; set; }
        public bool? ApplyInflation { get; set; }
        public bool IsLocationSpecific { get; set; }
        public int? ShowOrder { get; set; }
        public virtual Category CategoryLookup { get; set; }
        public virtual CategoryGroup CategoryGroupLookup { get; set; }
        public virtual CategorySubgroup CategorySubgroupLookup { get; set; }
        public virtual ArmyCareerProgram CareerProgramLookup { get; set; }
    }
}