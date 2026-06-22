namespace AMCOS.Data.Entities
{
    using System.ComponentModel.DataAnnotations;
    using System.ComponentModel.DataAnnotations.Schema;

    [Table("lookup.Organization")]
    public class Organization
    {
        [Key]
        [Column(Order = 0)]
        [StringLength(50)]
        public string OrganizationName { get; set; }

        [StringLength(250)]
        public string OrganizationDescription { get; set; }

        [StringLength(20)]
        public string OrganizationType { get; set; }
    }
}
