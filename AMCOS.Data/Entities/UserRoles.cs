namespace AMCOS.DataAccess.Entities
{
    using System.ComponentModel.DataAnnotations;
    using System.ComponentModel.DataAnnotations.Schema;
    using Microsoft.EntityFrameworkCore;

    [PrimaryKey(nameof(UserId), nameof(RoleId))]
    [Table("webuser.User_Roles")]
    public partial class UserRoles
    {
        [Column(Order = 0)]
        [StringLength(50)]
        public string UserId { get; set; }

        [Column(Order = 1)]
        [StringLength(50)]
        public string RoleId { get; set; }
    }
}
