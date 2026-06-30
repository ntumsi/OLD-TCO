namespace AMCOS.Data.Entities
{
    using System.ComponentModel.DataAnnotations;
    using System.ComponentModel.DataAnnotations.Schema;
    using Microsoft.EntityFrameworkCore;

    [PrimaryKey(nameof(PayPlan), nameof(CategoryGroupCode), nameof(CategorySubgroupCode), nameof(CostElementId), nameof(GradeType), nameof(GradeLevel))]
    [Table("Costs_Test", Schema = "data")]
    public class CostsTest
    {
        [Column(Order = 0)]
        [StringLength(3)]
        public string PayPlan { get; set; }

        [Column(Order = 1)]
        [StringLength(4)]
        public string CategoryGroupCode { get; set; }

        [Column(Order = 2)]
        [StringLength(4)]
        public string CategorySubgroupCode { get; set; }

        [StringLength(4)]
        public string SpecialRateTableNumber { get; set; }

        [StringLength(3)]
        public string WageArea { get; set; }

        [Column(Order = 3)]
        [DatabaseGenerated(DatabaseGeneratedOption.None)]
        public int CostElementId { get; set; }

        [Column(Order = 4)]
        [StringLength(3)]
        public string GradeType { get; set; }

        [Column(Order = 5)]
        public byte GradeLevel { get; set; }

        public double? Amount { get; set; }
    }
}
