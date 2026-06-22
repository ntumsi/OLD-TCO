namespace AMCOS.Data.Entities
{
    using System.ComponentModel.DataAnnotations;
    using System.ComponentModel.DataAnnotations.Schema;

    [Table("load_inventory.Inventory_Production")]
    public class InventoryProduction
    {
        [Key]
        [Column(Order = 0)]
        [StringLength(3)]
        public string PayPlan { get; set; }

        [Key]
        [Column(Order = 1)]
        [StringLength(40)]
        public string CategoryGroupCode { get; set; }

        [Key]
        [Column(Order = 2)]
        [StringLength(20)]
        public string CategorySubgroupCode { get; set; }

        [Key]
        [Column(Order = 3)]
        [StringLength(5)]
        public string TableNumber_Area { get; set; }

        [Key]
        [Column(Order = 4)]
        [DatabaseGenerated(DatabaseGeneratedOption.None)]
        public int Quality { get; set; }

        [Key]
        [Column(Order = 5)]
        [StringLength(4)]
        public string GradeType { get; set; }

        [Key]
        [Column(Order = 6)]
        public byte GradeLevel { get; set; }

        [Key]
        [Column(Order = 7)]
        public byte YOS { get; set; }

        [Key]
        [Column(Order = 8)]
        [DatabaseGenerated(DatabaseGeneratedOption.None)]
        public int Inventory { get; set; }
    }
}
