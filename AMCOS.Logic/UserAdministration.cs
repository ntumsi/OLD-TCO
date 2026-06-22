using AMCOS.Data;
using AMCOS.Data.DataTransferObjects;
using AMCOS.Data.Entities;
using AMCOS.Logic.Helpers;
using AMCOS.Logic.Models;
using Microsoft.VisualBasic;
using System;
using System.Collections.Generic;
using System.Globalization;
using System.Linq;
using System.Security.Claims;
using System.Web.UI.WebControls;

namespace AMCOS.Logic
{
    public static class UserAdministration
    {
        public enum AccountType
        {
            MILITARY,
            CIVILIAN,
            CONTRACTOR,
            OTHER,
            UNKNOWN
        }
        public static string GetFormattedPhoneNo(string unformattedPhoneNumber)
        {
            if ((unformattedPhoneNumber == null) || (unformattedPhoneNumber.Trim() == String.Empty))
            {
                return "";
            }
            else
            {
                string phoneNumber = unformattedPhoneNumber.Trim();
                string result = "";
                for (int i = 0; i <= phoneNumber.Length - 1; i++)
                {
                    if (Information.IsNumeric(phoneNumber.Substring(i, 1)))
                    {
                        result = result + phoneNumber.Substring(i, 1);
                    }
                }
                if (result.Length < 10)
                {
                    return result;
                }
                if (result.Length > 10)
                {
                    result = result.Substring(result.Length - 10);
                }
                return String.Format("({0}){1}-{2}", result.Substring(0, 3), result.Substring(3, 3), result.Substring(6));
            }
        }
        public static IEnumerable<ListItem> GetOrganizations()
        {
            using (var context = new ApplicationDbContext())
            {
                List<ListItem> organizations = context.Organization
                    .OrderBy(o => o.OrganizationName)
                    .Select(o => new ListItem()
                    {
                        Text = o.OrganizationName + " : " + o.OrganizationDescription,
                        Value = o.OrganizationName
                    }).ToList();
                return organizations;
            }
        }
        /// <summary>
        /// Compares the email with the accountType to determine if the user requires a sponsor
        /// </summary>
        /// <param name="emailAddress"></param>
        /// <param name="accountType"></param>
        /// <returns></returns>
        public static bool RequiresSponsor(string emailAddress, AccountType accountType)
        {
            AccountType emailAccountType = GetAccountTypeFromEmail(emailAddress);
            //Make sure that the accountType supplied by the user falls within our expected range.
            //The user may only supply a different account type than the one determined by the email
            //address if the account type supplied by the email address is unknown.
            if (emailAccountType != accountType && emailAccountType != AccountType.UNKNOWN)
                throw new ArgumentException("Supplied account type is not valid for the requesting user.");

            if (accountType == AccountType.MILITARY || accountType == AccountType.CIVILIAN)
                return false;
            else
                return true;
        }
        /// <summary>
        /// Get The accountType determined by the email address
        /// </summary>
        /// <param name="emailAddress"></param>
        /// <returns></returns>
        public static AccountType GetAccountTypeFromEmail(string emailAddress)
        {
            emailAddress = emailAddress.ToLower(new CultureInfo("en-US", false));
            if (emailAddress.Contains(".mil@"))    //Miliary
                return AccountType.MILITARY;

            if (emailAddress.Contains(".civ@") ||  //Civilian
                emailAddress.Contains(".naf@"))    //Non-Appropriated Fund DoD and Uniformed Service Employee
                return AccountType.CIVILIAN;

            if (emailAddress.Contains(".ctr@"))    //Contractor
                return AccountType.CONTRACTOR;

            if (emailAddress.Contains(".ben@") ||  //Beneficiary
                emailAddress.Contains(".cvr@") ||  //Civilian Retiree
                emailAddress.Contains(".dav@") ||  //Disabled American Veteran
                emailAddress.Contains(".fm@") ||   //Foreign Military
                emailAddress.Contains(".fn@") ||   //Foreign National
                emailAddress.Contains(".ln@") ||   //Local National
                emailAddress.Contains(".moh@") ||  //Medal of Honor Recipient
                emailAddress.Contains(".nfg@") ||  //Non-Federal Government
                emailAddress.Contains(".ngo@") ||  //Non-Government Official
                emailAddress.Contains(".ret@") ||  //Retired Military
                emailAddress.Contains(".vet@") ||  //Former Military Member
                emailAddress.Contains(".vol@"))    //Volunteer
                return AccountType.OTHER;
            else
                return AccountType.UNKNOWN;
        }
        public static string GetUserRole(ClaimsIdentity identity)
        {
            // Helper function to find the primary role from a list of claims
            // You can define your role priority here. Check for the most important roles first.
            return identity.HasClaim(ClaimTypes.Role, "Admin") ? "Admin" : "User";           
            
        }
        public static void ApproveUser(string userId)
        {
            //update webuser.AMCOSUser set UserStatus='Active', LastLogin=getdate(), LastApprovedDate=getdate() where UserID=@uid
            using (var context = new ApplicationDbContext())
            {
                var result = context.AMCOSUser
                    .Where(u => u.UserId == userId)
                    .First();
                if (result != null)
                {
                    result.UserStatus = "Active";
                    result.LastLogin = DateTime.Now;
                    result.LastApprovedDate = DateTime.Now;
                    context.SaveChanges();
                }
            }
        }
        public static void DenyUser(string userId)
        {
            //update webuser.AMCOSUser set UserStatus='Denied', LastDeniedDate=getdate() where UserID=@uid
            using (var context = new ApplicationDbContext())
            {
                var result = context.AMCOSUser
                    .Where(u => u.UserId == userId)
                    .First();
                if (result != null)
                {
                    result.UserStatus = "Denied";
                    result.LastDeniedDate = DateTime.Now;
                    context.SaveChanges();
                }
            }
        }
        public static AMCOSUser GetUserByDodId(string dodId)
        {
            using (var context = new ApplicationDbContext())
            {
                return context.AMCOSUser
                    .Where(u => u.DodId == dodId)
                    .OrderByDescending(u => u.LastLogin)
                    .FirstOrDefault();
            }
        }
        public static AMCOSUser GetUserById(string userId)
        {
            using (var context = new ApplicationDbContext())
            {
                return context.AMCOSUser
                    .Where(u => u.UserId == userId)
                    .FirstOrDefault();
            }
        }
        
        /// <summary>
        /// Return a user by checking the email column first.  If no user exists then check by the CAC email.  
        /// </summary>
        /// <param name="emailAddress"></param>
        /// <returns></returns>
        public static AMCOSUser GetUserByEmail(string emailAddress)
        {
            using (var context = new ApplicationDbContext())
            {
                var user = context.AMCOSUser
                    .Where(u => u.Email.ToLower() == emailAddress.ToLower())
                    .OrderByDescending(u => u.LastLogin)
                    .FirstOrDefault();
                if (user == null)
                    user = context.AMCOSUser
                    .Where(u => u.CACEmail.ToLower() == emailAddress.ToLower())
                    .OrderByDescending(u => u.LastLogin)
                    .FirstOrDefault();

                return user;
            }
        }
        public static void AddAmcosUser(AMCOSUser requestingUser, bool sponsorOnly = false, string sponsorUserId = "")
        {
            if (requestingUser == null)
            {
                throw new ArgumentNullException("requestingUser");
            }

            using (var context = new ApplicationDbContext())
            {
                var newUser = new AMCOSUser
                {
                    UserId = requestingUser.UserId,
                    FirstName = requestingUser.FirstName,
                    MiddleName = requestingUser.MiddleName,
                    LastName = requestingUser.LastName,
                    Email = requestingUser.Email,
                    CACEmail = requestingUser.CACEmail,
                    Prefix = requestingUser.Prefix,
                    AKOId = requestingUser.AKOId,
                    DodId = requestingUser.DodId,
                    ComPhone = requestingUser.ComPhone,
                    Dsn = requestingUser.Dsn,
                    InternationalNo = requestingUser.InternationalNo,
                    ArmyAccountType = requestingUser.ArmyAccountType,
                    ArmyRank = requestingUser.ArmyRank,
                    OfficeName = requestingUser.OfficeName,
                    CompanyName = requestingUser.CompanyName,
                    Macom = requestingUser.Macom,
                    UserRole = "User",
                    SelfAccountType = requestingUser.SelfAccountType,
                    SponsorUserId = requestingUser.SponsorUserId,
                    DateCreated = DateTime.Now,
                    LastUpdate = DateTime.Now,
                };                

                context.AMCOSUser.Add(newUser);
                context.SaveChanges();
            }
        }
        public static AMCOSUser GetCurrentUser(ClaimsIdentity identity)
        {
            var currentUser = GetUserByDodId(identity.Claims.FirstOrDefault(c => c.Type == ClaimTypes.NameIdentifier)?.Value);

            if (currentUser == null)
            {
                //If user is null then try to find the user by email
                currentUser = GetUserByEmail(identity.Claims.FirstOrDefault(c => c.Type == ClaimTypes.Email)?.Value);
                //If user is null then add new user
                if (currentUser == null)
                {
                    AddAmcosUser(new AMCOSUser()
                    {
                        UserId = Guid.NewGuid().ToString(),
                        DodId = identity.Claims.FirstOrDefault(c => c.Type == ClaimTypes.NameIdentifier)?.Value,
                        UserRole = GetUserRole(identity),
                        FirstName = identity.Claims.FirstOrDefault(c => c.Type == ClaimTypes.GivenName)?.Value,
                        LastName = identity.Claims.FirstOrDefault(c => c.Type == ClaimTypes.Surname)?.Value,
                        Email = identity.Claims.FirstOrDefault(c => c.Type == ClaimTypes.Email)?.Value,
                        ArmyAccountType = identity.Claims.FirstOrDefault(c => c.Type == "accountType")?.Value,
                        Macom = identity.Claims.FirstOrDefault(c => c.Type == "department")?.Value,
                        DateCreated = DateTime.Now,
                        LastUpdate = DateTime.Now,
                        UserStatus = "Active",
                        LastLogin = DateTime.Now
                    });

                }
                else  //Else update user values
                {
                    currentUser.DodId = identity.Claims.FirstOrDefault(c => c.Type == ClaimTypes.NameIdentifier)?.Value;
                    currentUser.FirstName = identity.Claims.FirstOrDefault(c => c.Type == ClaimTypes.GivenName)?.Value;
                    currentUser.LastName = identity.Claims.FirstOrDefault(c => c.Type == ClaimTypes.Surname)?.Value;
                    currentUser.ArmyAccountType = identity.Claims.FirstOrDefault(c => c.Type == "accountType")?.Value;
                    currentUser.Macom = identity.Claims.FirstOrDefault(c => c.Type == "department")?.Value;
                    currentUser.UserRole = UserAdministration.GetUserRole(identity);
                    currentUser.LastUpdate = DateTime.Now;
                    currentUser.UserStatus = "Active";
                    currentUser.LastLogin = DateTime.Now;
                    UpdateAmcosUser(currentUser);
                }


            }
            else if (DateTime.Now - currentUser.LastUpdate > TimeSpan.FromDays(1))  //Else update user values
            {
                currentUser.Email = identity.Claims.FirstOrDefault(c => c.Type == ClaimTypes.Email)?.Value;
                currentUser.FirstName = identity.Claims.FirstOrDefault(c => c.Type == ClaimTypes.GivenName)?.Value;
                currentUser.LastName = identity.Claims.FirstOrDefault(c => c.Type == ClaimTypes.Surname)?.Value;
                currentUser.ArmyAccountType = identity.Claims.FirstOrDefault(c => c.Type == "accountType")?.Value;
                currentUser.Macom = identity.Claims.FirstOrDefault(c => c.Type == "department")?.Value;
                currentUser.UserRole = UserAdministration.GetUserRole(identity);
                currentUser.LastUpdate = DateTime.Now;
                currentUser.UserStatus = "Active";
                currentUser.LastLogin = DateTime.Now;
                UpdateAmcosUser(currentUser);
            }
            return currentUser;
        }
        public static List<PendingUsers> GetPendingUsers()
        {
            using (var context = new ApplicationDbContext())
            {
                List<PendingUsers> pendingUsers = context.PendingUsers.AsNoTracking().ToList();
                return pendingUsers;
            }
        }
        public static string GetUserEmail(string userId)
        {
            using (var context = new ApplicationDbContext())
            {
                AMCOSUser amcosUser = context.AMCOSUser.Where(u => u.UserId == userId).First();
                return amcosUser.Email;
            }
        }
        public static List<string> GetValidEmailSuffixList()
        {
            using (var context = new ApplicationDbContext())
            {
                return context.ValidEmailSuffix.Select(e => e.EmailSuffix).ToList();
            }
        }
        
        private static string LinkToSponsor(UserModel sponsor)
        {
            if (string.IsNullOrWhiteSpace(sponsor?.Email))
                throw new ArgumentNullException("sponsor");
            var existingSponsor = GetUserByEmail(sponsor.Email);
            if (existingSponsor == null)
                return CreateSponsorOnlyUser(sponsor);
            else
            {
                existingSponsor.SelfAccountType = sponsor.SelfAccountType;
                existingSponsor.Prefix = sponsor.Prefix;
                existingSponsor.FirstName = sponsor.FirstName;
                existingSponsor.MiddleName = sponsor.MiddleName;
                existingSponsor.LastName = sponsor.LastName;
                existingSponsor.ComPhone = sponsor.ComPhone;
                existingSponsor.Dsn = sponsor.Dsn;
                existingSponsor.Macom = sponsor.Macom;
                existingSponsor.OfficeName = sponsor.OfficeName;
                existingSponsor.ArmyRank = sponsor.ArmyRank;

                return UpdateSponsorOnlyUser(existingSponsor);
            }
        }
        public static UserModel AddUserCredentialsToModel(UserModel userModel, ICredentials credentials)
        {
            //Assign user credential data to the userModel object
            if (credentials == null)
                throw new ArgumentNullException("credentials");

            userModel.CACEmail = credentials.CACEmail;
            userModel.UserId = credentials.UserId ?? throw new ArgumentNullException("userName");
            userModel.CnId = credentials.UserId;
            userModel.DodId = credentials.DodId;
            userModel.FirstName = credentials.FirstName;
            userModel.LastName = credentials.LastName;
            userModel.ArmyRank = credentials.ArmyRank;
            userModel.ArmyAccountType = credentials.ArmyAccountType;
            return userModel;
        }
        
        private static string UpdateSponsorOnlyUser(AMCOSUser sponsor)
        {
            if (sponsor.UserStatus != "SponsorOnly")
                return sponsor.UserId;

            try
            {
                UpdateAmcosUser(sponsor);
                return sponsor.UserId;
            }
            catch (Exception ex)
            {
                var message = "Error updating sponsorOnlyUser with the following fields: " +
                       "<br />sponsorModel.UserID = " + sponsor.UserId +
                    "<br />sponsorModel.AkoID = " + sponsor.AKOId +
                    "<br />sponsorModel.DodID = " + sponsor.DodId +
                    "<br />sponsorModel.Email = " + sponsor.Email +
                    "<br />sponsorModel.Prefix = " + sponsor.Prefix +
                    "<br />sponsorModel.FirstName = " + sponsor.FirstName +
                    "<br />sponsorModel.MiddleName = " + sponsor.MiddleName +
                    "<br />sponsorModel.LastName = " + sponsor.LastName +
                    "<br />sponsorModel.ComPhone = " + sponsor.ComPhone +
                    "<br />sponsorModel.Macom = " + sponsor.Macom +
                    "<br />sponsorModel.OfficeName = " + sponsor.OfficeName +
                    "<br />sponsorModel.ArmyRank = " + sponsor.ArmyRank +
                    "<br />sponsorModel.Dsn = " + sponsor.Dsn +
                    "<br />sponsorModel.SelfAccountType = " + sponsor.SelfAccountType +
                    "<br />sponsorModel.UserStatus = " + sponsor.UserStatus;
                ex.Data.Add("Additional", message);
                throw ex;
            }
        }

        /// <summary>
        /// takes sponsor usermodel to create AMCOSUser
        /// </summary>
        /// <param name="sponsor"></param>
        /// <returns></returns>
        private static string CreateSponsorOnlyUser(UserModel sponsorModel)
        {
            if (string.IsNullOrWhiteSpace(sponsorModel.Email))
                throw new ArgumentNullException("Email");
            sponsorModel.UserId = sponsorModel.Email;

            try
            {
                AddAmcosUser(sponsorModel.AMCOSUser, true);
                return sponsorModel.UserId;
            }
            catch (Exception ex)
            {
                var message = "Error inserting new sponsorOnlyUser with the following fields: " +
                       "<br />sponsorModel.UserID = " + sponsorModel.UserId +
                    "<br />sponsorModel.AkoID = " + sponsorModel.CnId +
                    "<br />sponsorModel.DodID = " + sponsorModel.DodId +
                    "<br />sponsorModel.Email = " + sponsorModel.Email +
                    "<br />sponsorModel.Prefix = " + sponsorModel.Prefix +
                    "<br />sponsorModel.FirstName = " + sponsorModel.FirstName +
                    "<br />sponsorModel.MiddleName = " + sponsorModel.MiddleName +
                    "<br />sponsorModel.LastName = " + sponsorModel.LastName +
                    "<br />sponsorModel.ComPhone = " + sponsorModel.ComPhone +
                    "<br />sponsorModel.Macom = " + sponsorModel.Macom +
                    "<br />sponsorModel.OfficeName = " + sponsorModel.OfficeName +
                    "<br />sponsorModel.ArmyRank = " + sponsorModel.ArmyRank +
                    "<br />sponsorModel.Dsn = " + sponsorModel.Dsn +
                    "<br />sponsorModel.SelfAccountType = " + sponsorModel.SelfAccountType +
                    "<br />sponsorModel.UserStatus = " + sponsorModel.UserStatus;
                ex.Data.Add("Additional", message);
                throw ex;
            }
        }
        //public void AddAmcosSponsor(AMCOSUser sponsor)
        //{
        //    using (var context = new ApplicationDbContext())
        //    {
        //        var newUser = new AMCOSUser
        //        {
        //            UserId = sponsor.UserId,
        //            FirstName = sponsor.FirstName,
        //            LastName = sponsor.LastName,
        //            Email = sponsor.Email,
        //            Prefix = sponsor.Prefix,
        //            CnId = sponsor.CnId,
        //            DodId = sponsor.DodId,
        //            ComPhone = sponsor.ComPhone,
        //            Dsn = sponsor.Dsn,
        //            InternationalNo = sponsor.InternationalNo,
        //            ArmyAccountType = sponsor.ArmyAccountType,
        //            ArmyRank = sponsor.ArmyRank,
        //            OfficeName = sponsor.OfficeName,
        //            CompanyName = sponsor.CompanyName,
        //            Macom = sponsor.Macom,
        //            SelfAccountType = sponsor.SelfAccountType,
        //            DateCreated = DateTime.Now,
        //            LastUpdate = DateTime.Now,
        //        };
        //        context.AMCOSUser.Add(newUser);
        //        context.SaveChanges();
        //    }
        //}
        public static void UpdateSponsorUserId(string userIdBefore, string userIdAfter)
        {
            //update webuser.AMCOSUser set SponsorUserID = @uid where SponsorUserID = @sid", {"@uid", "@sid"}, {_userName, userIdBeforeUpdate})
            using (var context = new ApplicationDbContext())
            {
                var users = (from user in context.AMCOSUser
                             where user.SponsorUserId == userIdBefore
                             select user).ToList();


                // modify each object
                foreach (var user in users)
                {
                    user.SponsorUserId = userIdAfter;
                }

                context.SaveChanges();
            }
        }
        public static void UpdateAmcosUser(AMCOSUser user)
        {
            using (var context = new ApplicationDbContext())
            {
                var existingUser = context.AMCOSUser.Where(x => x.UserId == user.UserId).First();
                existingUser.UserId = user.UserId;
                existingUser.FirstName = user.FirstName;
                existingUser.MiddleName = user.MiddleName;
                existingUser.LastName = user.LastName;
                existingUser.Email = user.Email;
                existingUser.CACEmail = user.CACEmail;
                existingUser.Prefix = user.Prefix;
                existingUser.AKOId = user.AKOId;
                existingUser.DodId = user.DodId;
                existingUser.ComPhone = user.ComPhone;
                existingUser.Dsn = user.Dsn;
                existingUser.InternationalNo = user.InternationalNo;
                existingUser.ArmyAccountType = user.ArmyAccountType;
                existingUser.ArmyRank = user.ArmyRank;
                existingUser.OfficeName = user.OfficeName;
                existingUser.CompanyName = user.CompanyName;
                existingUser.Macom = user.Macom;
                existingUser.UserStatus = user.UserStatus;
                existingUser.SelfAccountType = user.SelfAccountType;
                existingUser.SponsorUserId = user.SponsorUserId;
                existingUser.LastUpdate = DateTime.Now;
                existingUser.UserRole = user.UserRole;
                context.SaveChanges();
            }
        }

    }
}
