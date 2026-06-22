using AMCOS.Data;
using System.Linq;

namespace AMCOS.Logic
{
    public class Locations
    {
        public bool IsApoDpoFpo(string zipCode)
        {
            bool returnValue = false;

            using (var context = new ApplicationDbContext())
            {
                var fipsZipQuery = from z in context.FIPSZip
                                   where z.ZipCode == zipCode
                                   select z;

                foreach (var fipsZip in fipsZipQuery)
                {
                    if (fipsZip.City == "APO" || fipsZip.City == "DPO" || fipsZip.City == "FPO")
                        returnValue = true;
                }
            }
            return returnValue;
        }
    }
}
