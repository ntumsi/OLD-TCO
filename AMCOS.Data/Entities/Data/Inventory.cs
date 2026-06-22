namespace AMCOS.Data.Entities
{
    public class Inventory
    {
        public string PayPlan { get; set; }
        public string CategoryGroupCode { get; set; }
        public string CategorySubgroupCode { get; set; }
        public string Strl { get; set; }
        public int LocationId { get; set; }
        public string GradeType { get; set; }
        public byte GradeLevel { get; set; }
        public int Step { get; set; }
        public int? YOS { get; set; }
        public int InventoryAmount { get; set; }
        public int AmcosVersionId { get; set; }
        public virtual Location LocationLookup { get; set; }
    }
}
