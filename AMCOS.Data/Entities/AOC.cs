namespace AMCOS.DataAccess.Entities
{
    using System.ComponentModel.DataAnnotations;
    using System.ComponentModel.DataAnnotations.Schema;

    [Table("AOC", Schema = "lookup")]
    public partial class AOC
    {
        [Key]
        [Column("AOC")]
        [StringLength(3)]
        public string AOC1 { get; set; }

        [Required]
        [StringLength(250)]
        public string Description { get; set; }
    }
}
