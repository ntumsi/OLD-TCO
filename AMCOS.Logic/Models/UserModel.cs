using AMCOS.Data.Entities;
using AMCOS.Logic.Helpers;

using System;

namespace AMCOS.Logic.Models
{
    public class UserModel : ICredentials
    {
        /// <summary>
        /// default constructor
        /// </summary>
        public UserModel() 
        {
            
            AMCOSUser = new AMCOSUser();
          
        }
        /// <summary>
        /// Userful for creating sponsor users only
        /// </summary>
        /// <param name="user"></param>
        public UserModel(AMCOSUser user)
        {
            AMCOSUser = user ?? throw new ArgumentNullException("user");

        }
        /// <summary>
        /// constructor populates fields on instantiation use only when user does not exist in the database
        /// </summary>
        /// <param name="userName"></param>
        /// <param name="dodEdiPersonId"></param>
        /// <param name="enterpriseEmailAddress"></param>
        /// <param name="firstName"></param>
        /// <param name="lastName"></param>
        /// <param name="armyRank"></param>
        /// <param name="armyAcctType"></param>
        public UserModel(ICredentials credentials, string email, AMCOSUser user = null)
        {
            
            if(user == null)
            {
                AMCOSUser = new AMCOSUser();
            }
            else
            {
                AMCOSUser = user;
            }
            Email = email;
            UserAdministration.AddUserCredentialsToModel(this, credentials);
        }
                      
        public string GetFullName(bool IncludeMiddle = false)
        {
            if (IncludeMiddle)
            {
                return (Prefix + " " + FirstName + " " + MiddleName + " " + LastName).TrimStart();
            }
            else
            {
                return (Prefix + " " + FirstName + " " + LastName).TrimStart();

            }
        }
        public string UserId { get => AMCOSUser.UserId; set => AMCOSUser.UserId = value; }
        public string FirstName { get => AMCOSUser.FirstName; set => AMCOSUser.FirstName = value?.Trim(); }
        public string MiddleName { get => AMCOSUser.MiddleName; set => AMCOSUser.MiddleName = string.IsNullOrWhiteSpace(value) ? null : value.Trim(); }
        public string LastName { get => AMCOSUser.LastName; set => AMCOSUser.LastName = value?.Trim(); }       
        public string Email
        {
            get
            {
                return AMCOSUser.Email ?? "";
            }
            set
            {
                AMCOSUser.Email = value?.Trim();
            }
        }
        public string CACEmail { get => AMCOSUser.CACEmail; set => AMCOSUser.CACEmail = value?.Trim(); }
        public string Prefix { get => AMCOSUser.Prefix; set => AMCOSUser.Prefix = string.IsNullOrWhiteSpace(value) ? null : value.Trim(); }
        public string CnId { get => AMCOSUser.Cn; set => AMCOSUser.Cn = value?.Trim(); }
        public string DodId { get => AMCOSUser.DodId; set => AMCOSUser.DodId = value?.Trim(); }      
        public string ComPhone { get => UserAdministration.GetFormattedPhoneNo(AMCOSUser.ComPhone); set => AMCOSUser.ComPhone = value?.Trim(); }
        public string Dsn { get => UserAdministration.GetFormattedPhoneNo(AMCOSUser.Dsn); set => AMCOSUser.Dsn = string.IsNullOrWhiteSpace(value) ? null : value.Trim(); }
        public string InternationalNo { get => AMCOSUser.InternationalNo; set => AMCOSUser.InternationalNo = string.IsNullOrWhiteSpace(value) ? null : value.Trim(); }
        public string ArmyAccountType { get => AMCOSUser.ArmyAccountType; set => AMCOSUser.ArmyAccountType = string.IsNullOrWhiteSpace(value) ? null : value.Trim(); }
        public string ArmyRank { get => AMCOSUser.ArmyRank; set => AMCOSUser.ArmyRank = string.IsNullOrWhiteSpace(value) ? null : value.Trim(); }        
        public string OfficeName { get => AMCOSUser.OfficeName; set => AMCOSUser.OfficeName = string.IsNullOrWhiteSpace(value) ? null : value.Trim(); }
        public string CompanyName { get => AMCOSUser.CompanyName; set => AMCOSUser.CompanyName = string.IsNullOrWhiteSpace(value) ? null : value.Trim(); }
        public string Macom { get => AMCOSUser.Macom; set => AMCOSUser.Macom = string.IsNullOrWhiteSpace(value) ? null : value.Trim(); }
        public short? AccessStatus { get => AMCOSUser.AccessStatus; set => AMCOSUser.AccessStatus = value; }
        public string UserStatus { get => AMCOSUser.UserStatus; set => AMCOSUser.UserStatus = value; }
        public string UserRole { get => AMCOSUser.UserRole; set => AMCOSUser.UserRole = value; }
        public string SelfAccountType
        {
            get
            {
                if (string.IsNullOrEmpty(AMCOSUser.SelfAccountType))
                    return UserAdministration.GetAccountTypeFromEmail(Email).ToString();
                else
                    return AMCOSUser.SelfAccountType;
            }
            set
            {
                AMCOSUser.SelfAccountType = value;
            }
        }
        public AMCOSUser AMCOSUser { get; }

    }
}
