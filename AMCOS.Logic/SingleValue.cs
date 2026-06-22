using AMCOS.Data;
using System.Linq;

namespace AMCOS.Logic
{
    public static class SingleValue
    {
        public static decimal Get(string payPlan, string parameterName, int amcosVersionId)
        {
            using (var context = new ApplicationDbContext())
            {
                return (from v in context.SingleValues
                        where v.PayPlan == payPlan
                        where v.ParamName == parameterName
                        where v.AmcosVersionId == amcosVersionId
                        select v.ParamValue).FirstOrDefault();
            }
        }
    }
}
