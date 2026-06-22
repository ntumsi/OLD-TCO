namespace AMCOS.DataAccess.Entities
{
    using System;
    using System.ComponentModel.DataAnnotations;
    using System.ComponentModel.DataAnnotations.Schema;

    [Table("webuser.User_Login_History_DeletedUsers")]
    public partial class UserLoginHistoryDeletedUsers
    {
        [Key]
        [Column(Order = 0)]
        [StringLength(50)]
        public string UserId { get; set; }

        [Key]
        [Column(Order = 1)]
        public DateTime LoginDateTime { get; set; }

        [StringLength(50)]
        public string Browser { get; set; }

        [StringLength(50)]
        public string BrowserVersion { get; set; }
    }
}
