namespace AMCOS.Data.Entities
{
    using System.ComponentModel.DataAnnotations;
    using System.ComponentModel.DataAnnotations.Schema;

    [Table("lookup.LocalityPayArea_FIPS")]
    public class LocalityPayAreaFIPS
    {
        [Key]
        [Column(Order = 0)]
        [DatabaseGenerated(DatabaseGeneratedOption.None)]
        public int LocalityId { get; set; }

        [StringLength(100)]
        public string PayArea { get; set; }

        [StringLength(150)]
        public string PlaceName { get; set; }

        [Key]
        [Column(Order = 1)]
        [StringLength(10)]
        public string FIPS { get; set; }
    }
}
