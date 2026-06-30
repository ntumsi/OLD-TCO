namespace AMCOS.DataAccess.Entities
{
    using System;
    using System.ComponentModel.DataAnnotations;
    using System.ComponentModel.DataAnnotations.Schema;
    using Microsoft.EntityFrameworkCore;

    [PrimaryKey(nameof(UserId), nameof(LoginDateTime))]
    [Table("User_Login_History", Schema = "webuser")]
    public partial class UserLoginHistory
    {
        [Column(Order = 0)]
        [StringLength(50)]
        public string UserId { get; set; }

        [Column(Order = 1)]
        public DateTime LoginDateTime { get; set; }

        [StringLength(50)]
        public string Browser { get; set; }

        [StringLength(50)]
        public string BrowserVersion { get; set; }
    }
}
