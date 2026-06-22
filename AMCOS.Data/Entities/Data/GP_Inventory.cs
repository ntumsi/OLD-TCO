namespace AMCOS.Data.Entities
{
    using System.ComponentModel.DataAnnotations;
    using System.ComponentModel.DataAnnotations.Schema;

    [Table("data.GP_Inventory")]
    public class GPInventory
    {
        [Key]
        [Column(Order = 0)]
        [StringLength(5)]
        public string JobSeries { get; set; }

        [Key]
        [Column(Order = 1)]
        [StringLength(50)]
        public string StateCountry { get; set; }

        [Key]
        [Column(Order = 2)]
        [StringLength(50)]
        public string FunctionalArea { get; set; }

        [Key]
        [Column(Order = 3)]
        [StringLength(50)]
        public string CostCenter { get; set; }

        [Key]
        [Column(Order = 4)]
        public byte GradeLevel { get; set; }

        public byte? Step { get; set; }

        public int? PersonCount { get; set; }
    }
}
