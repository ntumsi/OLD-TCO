namespace AMCOS.Data.Entities
{
    using System.ComponentModel.DataAnnotations;
    using System.ComponentModel.DataAnnotations.Schema;
    using Microsoft.EntityFrameworkCore;

    [PrimaryKey(nameof(PayPlan), nameof(CategoryGroupCode), nameof(CategorySubgroupCode), nameof(TableNumber_Area), nameof(Quality), nameof(GradeType), nameof(GradeLevel), nameof(YOS), nameof(Inventory))]
    [Table("load_inventory.Inventory_Production")]
    public class InventoryProduction
    {
        [Column(Order = 0)]
        [StringLength(3)]
        public string PayPlan { get; set; }

        [Column(Order = 1)]
        [StringLength(40)]
        public string CategoryGroupCode { get; set; }

        [Column(Order = 2)]
        [StringLength(20)]
        public string CategorySubgroupCode { get; set; }

        [Column(Order = 3)]
        [StringLength(5)]
        public string TableNumber_Area { get; set; }

        [Column(Order = 4)]
        [DatabaseGenerated(DatabaseGeneratedOption.None)]
        public int Quality { get; set; }

        [Column(Order = 5)]
        [StringLength(4)]
        public string GradeType { get; set; }

        [Column(Order = 6)]
        public byte GradeLevel { get; set; }

        [Column(Order = 7)]
        public byte YOS { get; set; }

        [Column(Order = 8)]
        [DatabaseGenerated(DatabaseGeneratedOption.None)]
        public int Inventory { get; set; }
    }
}
