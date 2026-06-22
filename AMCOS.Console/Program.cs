using AMCOS.Data;
using AMCOS.Logic;

namespace AMCOS.Console
{
    internal class Program
    {
        private static void Main(string[] args)
        {
            var data = new Lite();
            var amcosVersionId = AppConfiguration.GetInt32("AmcosVersionId", 202401);

            data.CreateInflationYearObject(amcosVersionId);
            data.CreatePayPlanJson(amcosVersionId);

            global::System.Console.Write("\nPress any key to exit...");
            global::System.Console.ReadKey(true);
        }
    }
}
