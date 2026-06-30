using System;
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;
using Microsoft.EntityFrameworkCore;

namespace AMCOS.Data.Entities
{
    [PrimaryKey(nameof(PayPlan), nameof(CMF), nameof(MOS), nameof(CostElementId), nameof(GradeType), nameof(GradeLevel), nameof(WeaponSystemId))]
    [Table("Costs_AE", Schema = "crunch")]
    public class CostsAE
    {
        [Required]
        [StringLength(3)]
        [Column(Order = 0)]
        public string PayPlan { get; set; }
        [Required]
        [Column(TypeName ="nchar",Order = 1)]
        [StringLength(2)]
        public string CMF { get; set; }
        [Required]
        [StringLength(3)]
        [Column(Order = 2)]
        public string MOS { get; set; }
        [Required]
        [Column(Order = 3)]
        public int CostElementId { get; set; }
        [Required]
        [StringLength(3)]
        [Column(Order = 4)]
        public string GradeType { get; set; }
        [Required]
        [Column(Order = 5)]
        public byte GradeLevel { get; set; }
        [Required]
        [Column(Order = 6)]
        public int WeaponSystemId { get; set; }
        [Required]
        public decimal Amount { get; set; }
        [Column(TypeName = "smalldatetime")]
        public DateTime CrunchTime { get; set; }
    }
}
