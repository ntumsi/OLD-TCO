namespace AMCOS.DataAccess.Entities
{
    using System.ComponentModel.DataAnnotations;
    using System.ComponentModel.DataAnnotations.Schema;

    [Table("lookup.Role")]
    public partial class Role
    {
        [StringLength(50)]
        public string RoleId { get; set; }

        [StringLength(50)]
        public string Description { get; set; }
    }
}
