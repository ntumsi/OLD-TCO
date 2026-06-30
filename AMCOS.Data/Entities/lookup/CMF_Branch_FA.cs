namespace AMCOS.Data.Entities
{
    using System.ComponentModel.DataAnnotations;
    using System.ComponentModel.DataAnnotations.Schema;
    using Microsoft.EntityFrameworkCore;

    [PrimaryKey(nameof(Code), nameof(GradeType))]
    [Table("CMF_Branch_FA", Schema = "lookup")]
    public class CMFBranchFA
    {
        [Column(Order = 0)]
        [StringLength(2)]
        public string Code { get; set; }

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
