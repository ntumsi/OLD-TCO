namespace AMCOS.DataAccess.Entities
{
    using System;
    using System.Collections.Generic;
    using System.ComponentModel.DataAnnotations;
    using System.ComponentModel.DataAnnotations.Schema;
    using System.Data.Entity.Spatial;

    [Table("webuser.AMCOSUser")]
    public partial class AMCOSUser
    {
        [Key]
        [StringLength(50)]
        public string UserId { get; set; }

        [Required]
        [StringLength(50)]
        public string FirstName { get; set; }

        [StringLength(50)]
        public string MiddleName { get; set; }

        [Required]
        [StringLength(50)]
        public string LastName { get; set; }

        [Required]
        [StringLength(50)]
        public string Email { get; set; }

        [StringLength(50)]
        public string ComPhone { get; set; }

        [StringLength(100)]
        public string OfficeName { get; set; }

        [StringLength(50)]
        public string MACOM { get; set; }

        public DateTime LastLogin { get; set; }

        public DateTime DateCreated { get; set; }

        public DateTime LastUpdate { get; set; }

        public short? AccessStatus { get; set; }

        [StringLength(50)]
        public string AKOId { get; set; }

        [StringLength(50)]
        public string ArmyRank { get; set; }

        [StringLength(100)]
        public string CompanyName { get; set; }

        [StringLength(50)]
        public string ArmyAccountType { get; set; }

        [StringLength(5)]
        public string Prefix { get; set; }

        [StringLength(50)]
        public string Dsn { get; set; }

        [StringLength(14)]
        public string UserStatus { get; set; }

        [StringLength(50)]
        public string SponsorUserId { get; set; }

        [StringLength(10)]
        public string SelfAccountType { get; set; }

        public DateTime? LastApprovedDate { get; set; }

        public DateTime? LastDeniedDate { get; set; }

        [StringLength(50)]
        public string DodId { get; set; }

        [StringLength(30)]
        public string InternationalNo { get; set; }
    }
}
