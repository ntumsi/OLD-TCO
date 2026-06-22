namespace AMCOS.DataAccess.Entities
{
    using System.ComponentModel.DataAnnotations;
    using System.ComponentModel.DataAnnotations.Schema;

    [Table("webuser.User_Roles")]
    public partial class UserRoles
    {
        [Key]
        [Column(Order = 0)]
        [StringLength(50)]
        public string UserId { get; set; }

        [Key]
        [Column(Order = 1)]
        [StringLength(50)]
        public string RoleId { get; set; }
    }
}
