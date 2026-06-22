using System;
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace AMCOS.DataAccess.Entities
{
    [Table("webuser.AMCOSLiteAudit")]
    public partial class AMCOSLiteAudit
    {
        [Key]
        [Column(Order = 0)]
        [StringLength(50)]
        public string UserId { get; set; }

        [Key]
        [Column(Order = 1)]
        public DateTime CreateDate { get; set; }

        [Key]
        [Column(Order = 2)]
        [StringLength(50)]
        public string PageAction { get; set; }

        [Key]
        [Column(Order = 3)]
        [StringLength(50)]
        public string PageElement { get; set; }

        [StringLength(3)]
        public string PayPlan { get; set; }

        public int CostSummaryId { get; set; }

        [StringLength(7)]
        public string CategoryGroupCode { get; set; }

        [StringLength(7)]
        public string CategorySubgroupCode { get; set; }

        public int? LocalityRateId { get; set; }

        [StringLength(4)]
        public string SpecialRateTableNumber { get; set; }

        [StringLength(7)]
        public string WageArea { get; set; }

        [StringLength(9)]
        public string MetroAreaCode { get; set; }

        public float? OverheadPercentage { get; set; }

        [StringLength(50)]
        public string StateCountry { get; set; }

        [StringLength(50)]
        public string FunctionalAreaCode { get; set; }

        [StringLength(50)]
        public string CostCenterCode { get; set; }

        [StringLength(25)]
        public string InflationConversionType { get; set; }

        [StringLength(4)]
        public string InflationYear { get; set; }
    }
}
