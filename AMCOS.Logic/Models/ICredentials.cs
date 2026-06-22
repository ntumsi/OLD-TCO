using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace AMCOS.Logic.Models
{
    public interface ICredentials
    {
        string UserId { get; }
        string DodId { get; }
        string FirstName { get; }
        string LastName { get; }
        string ArmyRank { get; }
        string ArmyAccountType { get; }
        string CACEmail { get; }
    }
}
