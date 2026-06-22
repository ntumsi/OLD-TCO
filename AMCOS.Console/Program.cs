using AMCOS.Logic;

namespace AMCOS.Console
{
    class Program
    {
        static void Main(string[] args)
        {
            Lite data = new Lite();
            int amcosVersionId = 202401;
            data.CreateInflationYearObject(amcosVersionId);
            data.CreatePayPlanJson(amcosVersionId);
            //data.CreatePayPlanOptionList(amcosVersionId);

            System.Console.Write("\nPress any key to exit...");
            System.Console.ReadKey(true);
        }
    }
}
