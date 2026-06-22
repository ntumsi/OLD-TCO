using System;
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace AMCOS.Data.Entities
{
    [Table("crunch.Costs_AO")]
    public class CostsAO
    {
        [Required]
        [StringLength(3)]
        [Key]
        [Column(Order = 0)]
        public string PayPlan { get; set; }
        [Required]
        [Column(TypeName = "nchar", Order = 1)]
        [StringLength(2)]
        [Key]
        public string CMF { get; set; }
        [Required]
        [StringLength(3)]
        [Key]
        [Column(Order = 2)]
        public string AOC { get; set; }
        [Required]
        [Key]
        [Column(Order = 3)]
        public int CostElementId { get; set; }
        [Required]
        [StringLength(3)]
        [Key]
        [Column(Order = 4)]
        public string GradeType { get; set; }
        [Required]
        [Key]
        [Column(Order = 5)]
        public byte GradeLevel { get; set; }
        [Required]
        [Key]
        [Column(Order = 6)]
        public int WeaponSystemId { get; set; }
        [Required]
        public decimal Amount { get; set; }
        [Column(TypeName = "smalldatetime")]
        public DateTime CrunchTime { get; set; }
    }
}
