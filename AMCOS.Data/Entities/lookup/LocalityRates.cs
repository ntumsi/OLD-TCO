namespace AMCOS.Data.Entities
{
    using System.ComponentModel.DataAnnotations;
    using System.ComponentModel.DataAnnotations.Schema;

    [Table("lookup.LocalityRates")]
    public class LocalityRates
    {
        [DatabaseGenerated(DatabaseGeneratedOption.None)]
        public int Id { get; set; }

        [Required]
        [StringLength(100)]
        public string Description { get; set; }

        [StringLength(200)]
        public string Location { get; set; }

        [Column(TypeName = "numeric")]
        public decimal? Amount { get; set; }

        [StringLength(6)]
        public string StateName { get; set; }

        [StringLength(8)]
        public string AreaCode { get; set; }

        [StringLength(2)]
        public string StateCode { get; set; }

        [StringLength(3)]
        public string CountyCode { get; set; }

        [StringLength(4)]
        public string CityCode { get; set; }

        public int? LocalityId { get; set; }

        public bool? IsLocalityPayArea { get; set; }

        public byte? SortOrder { get; set; }
    }
}
