namespace AMCOS.DataAccess.Entities
{
    using System;
    using System.Collections.Generic;
    using System.ComponentModel.DataAnnotations;
    using System.ComponentModel.DataAnnotations.Schema;
    using System.Data.Entity.Spatial;

    [Table("lookup.FIPS_ZIP")]
    public partial class FIPSZip
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
