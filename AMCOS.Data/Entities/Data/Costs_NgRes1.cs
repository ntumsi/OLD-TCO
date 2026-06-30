namespace AMCOS.Data.Entities
{
    using System.ComponentModel.DataAnnotations;
    using System.ComponentModel.DataAnnotations.Schema;
    using Microsoft.EntityFrameworkCore;

    [PrimaryKey(nameof(PayPlan), nameof(CategoryGroupCode), nameof(CategorySubgroupCode), nameof(CostElementId), nameof(GradeType), nameof(GradeLevel))]
    [Table("Costs_NgRes1", Schema = "data")]
    public class CostsNGRes1
    {
        [Column(Order = 0)]
        [StringLength(5)]
        public string PayPlan { get; set; }

        [Column(Order = 1)]
        [StringLength(6)]
        public string CategoryGroupCode { get; set; }

        [Column(Order = 2)]
        [StringLength(6)]
        public string CategorySubgroupCode { get; set; }

        public int? SpecialRateTableNumber { get; set; }

        public int? WageArea { get; set; }

        [Column(Order = 3)]
        [DatabaseGenerated(DatabaseGeneratedOption.None)]
        public int CostElementId { get; set; }

        [Column(Order = 4)]
        [StringLength(3)]
        public string GradeType { get; set; }

        [Column(Order = 5)]
        [DatabaseGenerated(DatabaseGeneratedOption.None)]
        public int GradeLevel { get; set; }

        public double? Amount { get; set; }
    }
}
