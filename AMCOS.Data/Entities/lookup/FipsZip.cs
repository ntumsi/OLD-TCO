namespace AMCOS.Data.Entities
{
    using System.ComponentModel.DataAnnotations;
    using System.ComponentModel.DataAnnotations.Schema;

    [Table("lookup.FIPS_ZIP")]
    public class FIPSZip
    {
        [Key]
        [Column(Order = 0)]
        [StringLength(50)]
        public string FIPSCode { get; set; }

        [Key]
        [Column(Order = 1)]
        [StringLength(5)]
        public string ZipCode { get; set; }

        [StringLength(255)]
        public string City { get; set; }

        [StringLength(255)]
        public string County { get; set; }

        [StringLength(50)]
        public string State { get; set; }

        [StringLength(50)]
        public string StateName { get; set; }

        [StringLength(50)]
        public string StateNameCapitalized { get; set; }
    }
}
