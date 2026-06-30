namespace AMCOS.Data.Entities
{
    using System.ComponentModel.DataAnnotations;
    using System.ComponentModel.DataAnnotations.Schema;
    using Microsoft.EntityFrameworkCore;

    [PrimaryKey(nameof(LocalityId), nameof(FIPS))]
    [Table("LocalityPayArea_FIPS", Schema = "lookup")]
    public class LocalityPayAreaFIPS
    {
        [Column(Order = 0)]
        [DatabaseGenerated(DatabaseGeneratedOption.None)]
        public int LocalityId { get; set; }

        [StringLength(100)]
        public string PayArea { get; set; }

        [StringLength(150)]
        public string PlaceName { get; set; }

        [Column(Order = 1)]
        [StringLength(10)]
        public string FIPS { get; set; }
    }
}
