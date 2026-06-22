namespace AMCOS.Data.Entities
{
    using System.ComponentModel.DataAnnotations;
    using System.ComponentModel.DataAnnotations.Schema;

    [Table("lookup.AMCOSVersion")]
    public class AMCOSVersion
    {
        public int Id { get; set; }

        [StringLength(50)]
        public string Description { get; set; }
    }
}
