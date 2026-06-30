namespace AMCOS.DataAccess.Entities
{
    using System.ComponentModel.DataAnnotations;
    using System.ComponentModel.DataAnnotations.Schema;
    using Microsoft.EntityFrameworkCore;

    [PrimaryKey(nameof(UserId), nameof(ProjectId), nameof(CategoryId), nameof(SkillId), nameof(PayPlan), nameof(CategoryGroupCode), nameof(CategorySubgroupCode), nameof(GradeType), nameof(GradeLevel))]
    [Table("PMCategorySkill", Schema = "webuser")]
    public partial class PMCategorySkill
    {
        [Column(Order = 0)]
        [StringLength(50)]
        public string UserId { get; set; }

        [Column(Order = 1)]
        [DatabaseGenerated(DatabaseGeneratedOption.None)]
        public int ProjectId { get; set; }

        [Column(Order = 2)]
        [DatabaseGenerated(DatabaseGeneratedOption.None)]
        public int CategoryId { get; set; }

        [Column(Order = 3)]
        public int SkillId { get; set; }

        [Column(Order = 4)]
        [StringLength(3)]
        public string PayPlan { get; set; }

        [Column(Order = 5)]
        [StringLength(10)]
        public string CategoryGroupCode { get; set; }

        [Column(Order = 6)]
        [StringLength(10)]
        public string CategorySubgroupCode { get; set; }

        [Column(Order = 7)]
        [StringLength(3)]
        public string GradeType { get; set; }

        [Column(Order = 8)]
        public byte GradeLevel { get; set; }

        [StringLength(5)]
        public string Type { get; set; }

        [StringLength(50)]
        public string AreaCode { get; set; }

        public int? LocalityId { get; set; }

        [StringLength(4)]
        public string SpecialRateTableNumber { get; set; }

        [StringLength(50)]
        public string StateCountry { get; set; }

        [StringLength(50)]
        public string FunctionalArea { get; set; }

        [StringLength(50)]
        public string CostCenter { get; set; }

        public short? ActiveDays { get; set; }

        public double? OverheadPct { get; set; }
    }
}
