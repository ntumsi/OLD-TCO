namespace AMCOS.Data.Entities
{
    using System.ComponentModel.DataAnnotations;
    using System.ComponentModel.DataAnnotations.Schema;
    using Microsoft.EntityFrameworkCore;

    [PrimaryKey(nameof(Appn), nameof(CostElementCategory), nameof(CostElementName), nameof(CostElementId))]
    [Table("data.vCosts_Prod")]
    public class VCostsProd
    {
        [StringLength(5)]
        public string PayPlan { get; set; }

        [StringLength(6)]
        public string CategoryGroupCode { get; set; }

        [StringLength(6)]
        public string CategorySubgroupCode { get; set; }

        [StringLength(5)]
        public string WageArea { get; set; }

        public int? Type { get; set; }

        [Column(Order = 0)]
        [StringLength(25)]
        public string Appn { get; set; }

        [Column(Order = 1)]
        [StringLength(50)]
        public string CostElementCategory { get; set; }

        [Column(Order = 2)]
        [StringLength(300)]
        public string CostElementName { get; set; }

        public int? Amortized { get; set; }

        public int? Model { get; set; }

        [Column(Order = 3)]
        [DatabaseGenerated(DatabaseGeneratedOption.None)]
        public int CostElementId { get; set; }

        [StringLength(3)]
        public string GradeType { get; set; }

        public byte? GradeLevel { get; set; }

        public double? Amount { get; set; }
    }
}
