using System;
using System.ComponentModel.DataAnnotations.Schema;

namespace AMCOS.Data.Entities
{
    [Serializable]
    public class AMCOSUser
    {  
        public string UserId { get; set; }
        public string FirstName { get; set; }
        public string MiddleName { get; set; }
        public string LastName { get; set; }
        public string Email { get; set; }
        public string CACEmail { get; set; }
        public string Cn { get; set; }
        public string Prefix { get; set; }
        public string AKOId { get; set; }
        public string DodId { get; set; }
        public string ComPhone { get; set; }
        public string Dsn { get; set; }
        public string InternationalNo { get; set; }
        public string ArmyAccountType { get; set; }
        public string ArmyRank { get; set; }
        public string OfficeName { get; set; }
        public string CompanyName { get; set; }
        public string Macom { get; set; }
        public short? AccessStatus { get; set; }
        public string UserStatus { get; set; }
        public string UserRole { get; set; }
        public string SelfAccountType { get; set; }
        public string SponsorUserId { get; set; }
        public DateTime? LastLogin { get; set; }
        public DateTime DateCreated { get; set; }
        public DateTime LastUpdate { get; set; }    
        public DateTime? LastApprovedDate { get; set; }
        public DateTime? LastDeniedDate { get; set; }

        [NotMapped]
        public string FullName => (Prefix + " " + FirstName + " " + LastName).TrimStart();
    }
}
