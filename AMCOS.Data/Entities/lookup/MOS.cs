namespace AMCOS.Data.Entities
{
    using System.ComponentModel.DataAnnotations;
    using System.ComponentModel.DataAnnotations.Schema;

    [Table("lookup.MOS")]
    public class MOS
    {
        [Key]
        [Column("MOS")]
        [StringLength(3)]
        public string MOS1 { get; set; }

        [StringLength(250)]
        public string Description { get; set; }

        [Column(TypeName = "numeric")]
        public decimal? CONUSTourLength { get; set; }
    }
}
