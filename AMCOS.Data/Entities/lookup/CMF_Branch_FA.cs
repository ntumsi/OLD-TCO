namespace AMCOS.Data.Entities
{
    using System.ComponentModel.DataAnnotations;
    using System.ComponentModel.DataAnnotations.Schema;

    [Table("lookup.CMF_Branch_FA")]
    public class CMFBranchFA
    {
        [Key]
        [Column(Order = 0)]
        [StringLength(2)]
        public string Code { get; set; }

        [Key]
        [Column(Order = 1)]
        [StringLength(1)]
        public string GradeType { get; set; }

        [Required]
        [StringLength(250)]
        public string Description { get; set; }

        [StringLength(25)]
        public string CodeType { get; set; }

        [Column(TypeName = "numeric")]
        public decimal? CONUSTourLength { get; set; }
    }
}
