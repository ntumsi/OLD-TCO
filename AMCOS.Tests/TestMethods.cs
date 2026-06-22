using AMCOS.Data;
using AMCOS.Data.Entities;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace AMCOS.Tests
{
    public static class TestMethods
    {
        public static void DeletePCSProject(string userId, string projectName)
        {
            using (var context = new ApplicationDbContext())
            {
                var project = context.PCSProject.Where(p => p.UserId == userId && p.ProjectName == projectName).FirstOrDefault();
                if(project != null)
                {
                    context.PCSProject.Remove(project);
                    context.SaveChanges();
                }
            }
        }
        public static void DeleteUserById(string userId)
        {
            
             using (var context = new ApplicationDbContext())
                {
                    var user = context.AMCOSUser.Where(x => x.UserId == userId).FirstOrDefault();
                    if (user != null)
                    {
                        context.AMCOSUser.Remove(user);
                        context.SaveChanges();
                    }
                }
            
        }

        public static AMCOSUser AddAmcosUser(string userId, string firstName, string lastName, string email, string status, DateTime? lastLogin = null, string rank = null, string sponsorId = null, string userRole = "User")
        {
            using (var context = new ApplicationDbContext())
            {
                var newUser = new AMCOSUser
                {
                    UserId = userId,
                    FirstName = firstName,
                    LastName = lastName,
                    Email = email,
                    Prefix = null,
                    AKOId = userId,
                    DodId = userId,
                    ComPhone = null,
                    Dsn = null,
                    InternationalNo = null,
                    ArmyAccountType = null,
                    ArmyRank = rank,
                    OfficeName = null,
                    CompanyName = null,
                    Macom = null,
                    UserRole = userRole,
                    SelfAccountType = Logic.UserAdministration.GetAccountTypeFromEmail(email).ToString(),
                    SponsorUserId = sponsorId,
                    DateCreated = DateTime.Now,
                    LastUpdate = DateTime.Now,
                    UserStatus = status,
                    LastLogin = lastLogin
                };

                context.AMCOSUser.Add(newUser);
                context.SaveChanges();
                return newUser;
            }
        }
    }
}
