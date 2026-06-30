namespace AMCOS.Data.Entities
{
    using System.ComponentModel.DataAnnotations;
    using System.ComponentModel.DataAnnotations.Schema;

    [Table("WageArea", Schema = "lookup")]
    public class WageArea
    {
        [Key]
        [Column("WageArea")]
        [StringLength(3)]
        public string WageArea1 { get; set; }

        [StringLength(250)]
        public string Description { get; set; }
    }
}
