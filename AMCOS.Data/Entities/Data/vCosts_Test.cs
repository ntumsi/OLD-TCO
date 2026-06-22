namespace AMCOS.Data.Entities
{
    using System.ComponentModel.DataAnnotations;
    using System.ComponentModel.DataAnnotations.Schema;

    [Table("data.vCosts_Test")]
    public class VCostsTest
    {
        [Key]
        [Column(Order = 0)]
        [StringLength(3)]
        public string PayPlan { get; set; }

        [StringLength(4)]
        public string CategoryGroupCode { get; set; }

        [StringLength(4)]
        public string CategorySubgroupCode { get; set; }

        [Key]
        [Column(Order = 1)]
        [StringLength(3)]
        public string WageArea { get; set; }

        public int? Type { get; set; }

        [Key]
        [Column(Order = 2)]
        [StringLength(25)]
        public string Appn { get; set; }

        [Key]
        [Column(Order = 3)]
        [StringLength(50)]
        public string CostElementCategory { get; set; }

        [Key]
        [Column(Order = 4)]
        [StringLength(300)]
        public string CostElementName { get; set; }

        public int? Amortized { get; set; }

        public int? Model { get; set; }

        [Key]
        [Column(Order = 5)]
        [DatabaseGenerated(DatabaseGeneratedOption.None)]
        public int CostElementId { get; set; }

        [Key]
        [Column(Order = 6)]
        [StringLength(3)]
        public string GradeType { get; set; }

        [Key]
        [Column(Order = 7)]
        public byte GradeLevel { get; set; }

        public double? Amount { get; set; }
    }
}
