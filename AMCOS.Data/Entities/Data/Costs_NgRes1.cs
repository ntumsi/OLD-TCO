namespace AMCOS.Data.Entities
{
    using System.ComponentModel.DataAnnotations;
    using System.ComponentModel.DataAnnotations.Schema;

    [Table("data.Costs_NgRes1")]
    public class CostsNGRes1
    {
        [Key]
        [Column(Order = 0)]
        [StringLength(5)]
        public string PayPlan { get; set; }

        [Key]
        [Column(Order = 1)]
        [StringLength(6)]
        public string CategoryGroupCode { get; set; }

        [Key]
        [Column(Order = 2)]
        [StringLength(6)]
        public string CategorySubgroupCode { get; set; }

        public int? SpecialRateTableNumber { get; set; }

        public int? WageArea { get; set; }

        [Key]
        [Column(Order = 3)]
        [DatabaseGenerated(DatabaseGeneratedOption.None)]
        public int CostElementId { get; set; }

        [Key]
        [Column(Order = 4)]
        [StringLength(3)]
        public string GradeType { get; set; }

        [Key]
        [Column(Order = 5)]
        [DatabaseGenerated(DatabaseGeneratedOption.None)]
        public int GradeLevel { get; set; }

        public double? Amount { get; set; }
    }
}
