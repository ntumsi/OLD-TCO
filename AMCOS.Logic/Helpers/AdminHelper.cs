using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace AMCOS.Logic.Helpers
{
    public static class AdminHelper
    {
        public static void ThrowExceptionIfNotAdmin(string userRole)
        {
            if (userRole != "Admin")
            {
                throw new UnauthorizedAccessException("User attempted to access an Admin Only page.");
            }
        }
        
    }
}
