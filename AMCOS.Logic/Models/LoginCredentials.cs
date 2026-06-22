using AMCOS.Logic.Helpers;
using System;

namespace AMCOS.Logic.Models
{
    public class LoginCredentials : ICredentials
    {
        public LoginCredentials(string userName, string dodId, string firstName, string lastName, string armyRank, string armyAcctType, string cacEmail)
        {
            UserId = string.IsNullOrWhiteSpace(userName) ? throw new ArgumentNullException("userName") : userName;
            DodId = dodId;
            FirstName = LoginPropertyHelper.ParseMultipleValueServerVariable(firstName) ?? throw new ArgumentNullException("firstName");
            LastName = LoginPropertyHelper.ParseMultipleValueServerVariable(lastName) ?? throw new ArgumentNullException("lastName");
            ArmyRank = armyRank;
            ArmyAccountType = armyAcctType;
            CACEmail = cacEmail;
        }
        public string UserId { get; }
        public string DodId { get; }
        public string FirstName { get; }
        public string LastName { get; }
        public string ArmyRank { get; }
        public string ArmyAccountType { get; }
        public string CACEmail { get; }
    }
}
