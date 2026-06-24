namespace AMCOS.Data.Entities
{
    using System.ComponentModel.DataAnnotations;
    using System.ComponentModel.DataAnnotations.Schema;
    using Microsoft.EntityFrameworkCore;

    [PrimaryKey(nameof(Appn), nameof(CostElementCategory), nameof(CostElementId), nameof(CostElementName))]
    [Table("compare.CostsProduction")]
    public class CostsGPProd
    {
        [StringLength(5)]
        public string JobSeries { get; set; }

        [StringLength(50)]
        public string StateCountry { get; set; }

        [StringLength(50)]
        public string FunctionalArea { get; set; }

        [StringLength(50)]
        public string CostCenter { get; set; }

        [StringLength(2)]
        public string GradeLevel { get; set; }

        [StringLength(10)]
        public string PersonnelNumber { get; set; }

        [Column(Order = 0)]
        [StringLength(25)]
        public string Appn { get; set; }

        [Column(Order = 1)]
        [StringLength(50)]
        public string CostElementCategory { get; set; }

        [Column(Order = 2)]
        [DatabaseGenerated(DatabaseGeneratedOption.None)]
        public int CostElementId { get; set; }

        [Column(Order = 3)]
        [StringLength(300)]
        public string CostElementName { get; set; }

        public double? Amount { get; set; }
    }
}
