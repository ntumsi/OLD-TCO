namespace AMCOS.Data.Entities
{
    using System.ComponentModel.DataAnnotations;
    using System.ComponentModel.DataAnnotations.Schema;

    [Table("WOMOS", Schema = "lookup")]
    public class WOMOS
    {
        [Key]
        [Column("WOMOS")]
        [StringLength(4)]
        public string WOMOS1 { get; set; }

        [StringLength(250)]
        public string Description { get; set; }
    }
}
