namespace AMCOS.Data.Entities
{
    using System.ComponentModel.DataAnnotations;
    using System.ComponentModel.DataAnnotations.Schema;
    using Microsoft.EntityFrameworkCore;

    [PrimaryKey(nameof(FIPSCode), nameof(ZipCode))]
    [Table("FIPS_ZIP", Schema = "lookup")]
    public class FIPSZip
    {
        [Column(Order = 0)]
        [StringLength(50)]
        public string FIPSCode { get; set; }

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
