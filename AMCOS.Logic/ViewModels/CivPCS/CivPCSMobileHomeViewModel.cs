using AMCOS.Logic.Models;

namespace AMCOS.Logic.ViewModels
{
    public class CivPcsMobileHomeViewModel : IModel, ICivPcsMobileHome
    {
        /// <summary>
        /// Default constructor requires input parameter of AMCOS version
        /// </summary>
        /// <param name="amcosVersion"></param>
        public CivPcsMobileHomeViewModel(int amcosVersion)
        {
            MobileHomeEstCostPerMile = SingleValue.Get("AA", "PCS_MobileHomeCostPerMile", amcosVersion);
        }
        /// <summary>
        /// Title of content panel
        /// </summary>
        public string Title => "Mobile Home Transportation";
        /// <summary>
        /// Name of view associated with this model
        /// </summary>
        public string View => "_MobileHome";
        /// <summary>
        /// Total miles for mobile home transportation
        /// </summary>
        public int MobileHomeTotalMileage { get; set; } = 0;
        /// <summary>
        /// Estimated cost for moving a mobile home per mile
        /// </summary>
        public decimal MobileHomeEstCostPerMile { get; set; }
        /// <summary>
        /// Total estimated cost for moving the mobile home
        /// </summary>
        public decimal MobileHomeSubtotal { get; } = 0;       
    }
    public interface ICivPcsMobileHome
    {
        /// <summary>
        /// Total miles for mobile home transportation
        /// </summary>
        int MobileHomeTotalMileage { get; }
        /// <summary>
        /// Estimated cost for moving a mobile home per mile
        /// </summary>
        decimal MobileHomeEstCostPerMile { get; }
        /// <summary>
        /// Total estimated cost for moving the mobile home
        /// </summary>
        decimal MobileHomeSubtotal { get; }
    }
}
