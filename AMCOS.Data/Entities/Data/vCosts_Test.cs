namespace AMCOS.Data.Entities
{
    using System.ComponentModel.DataAnnotations;
    using System.ComponentModel.DataAnnotations.Schema;
    using Microsoft.EntityFrameworkCore;

    [PrimaryKey(nameof(PayPlan), nameof(WageArea), nameof(Appn), nameof(CostElementCategory), nameof(CostElementName), nameof(CostElementId), nameof(GradeType), nameof(GradeLevel))]
    [Table("vCosts_Test", Schema = "data")]
    public class VCostsTest
    {
        [Column(Order = 0)]
        [StringLength(3)]
        public string PayPlan { get; set; }

        [StringLength(4)]
        public string CategoryGroupCode { get; set; }

        [StringLength(4)]
        public string CategorySubgroupCode { get; set; }

        [Column(Order = 1)]
        [StringLength(3)]
        public string WageArea { get; set; }

        public int? Type { get; set; }

        [Column(Order = 2)]
        [StringLength(25)]
        public string Appn { get; set; }

        [Column(Order = 3)]
        [StringLength(50)]
        public string CostElementCategory { get; set; }

        [Column(Order = 4)]
        [StringLength(300)]
        public string CostElementName { get; set; }

        public int? Amortized { get; set; }

        public int? Model { get; set; }

        [Column(Order = 5)]
        [DatabaseGenerated(DatabaseGeneratedOption.None)]
        public int CostElementId { get; set; }

        [Column(Order = 6)]
        [StringLength(3)]
        public string GradeType { get; set; }

        [Column(Order = 7)]
        public byte GradeLevel { get; set; }

        public double? Amount { get; set; }
    }
}
