using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace AMCOS.Data.Entities
{
    public class QuickSightEnvironment
    {
        public string AwsAccountId { get; set; }
        public string AwsRegionCode { get; set; }
        public string SessionLifetimeInMinutes { get; set; }
        public string AllowedDomains { get; set; }
    }
}
