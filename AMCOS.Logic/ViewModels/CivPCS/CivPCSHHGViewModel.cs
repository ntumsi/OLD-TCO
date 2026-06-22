using AMCOS.Logic.Models;

namespace AMCOS.Logic.ViewModels
{
    public class CivPcsHhgViewModel : IModel, ICivPcsHhg
    {
        public CivPcsHhgViewModel(int amcosVersion)
        {
            HHGEstimatedCostPerMile = SingleValue.Get("AA", "PCS_HHGCostPerMile", amcosVersion);
            HHGEstimatedCostPerPound = SingleValue.Get("AA", "PCS_HHGCostPerPound", amcosVersion);
            HHGMaxWeight = (int)SingleValue.Get("AA", "PCS_HHGMaxWeight", amcosVersion);
            HHGTotalWeight = HHGMaxWeight;
        }
        /// <summary>
        /// Title of Content Panel
        /// </summary>
        public string Title => "House Hold Goods";
        /// <summary>
        /// View model is associated with
        /// </summary>
        public string View => "_HHG";
        /// <summary>
        /// Total miles goods to be transported
        /// </summary>
        public int HHGTotalMileage { get; set; }
        /// <summary>
        /// Total weight of goods to be transported
        /// </summary>
        public double HHGTotalWeight { get; set; }
        /// <summary>
        /// Max reimbursableWeight
        /// </summary>
        public int HHGMaxWeight { get; set; }
        /// <summary>
        /// Estimation of cost per mile of transportation
        /// </summary>
        public decimal HHGEstimatedCostPerMile { get; set; }
        /// <summary>
        /// Estimated cost per pound for transportation
        /// </summary>
        public decimal HHGEstimatedCostPerPound { get; set; } 
        /// <summary>
        /// Total cost of transportation by mile
        /// </summary>
        public decimal HHGCostByTotalMiles { get; set; }
        /// <summary>
        /// Total cost of transportation by weight
        /// </summary>
        public decimal HHGCostByTotalWeight { get; set; }
        /// <summary>
        /// Total cost of transportation of goods
        /// </summary>
        public decimal SubtotalHHG { get; set; }

    }
    public interface ICivPcsHhg
    {
        /// <summary>
        /// Total miles goods to be transported
        /// </summary>
        int HHGTotalMileage { get; set; }
        /// <summary>
        /// Total weight of goods to be transported
        /// </summary>
        double HHGTotalWeight { get; set; }
        /// <summary>
        /// Max reimbursable weight
        /// </summary>
        int HHGMaxWeight { get; set; }
        /// <summary>
        /// Estimation of cost per mile of transportation
        /// </summary>
        decimal HHGEstimatedCostPerMile { get; set; }
        /// <summary>
        /// Estimated cost per pound for transportation
        /// </summary>
        decimal HHGEstimatedCostPerPound { get; set; }
        /// <summary>
        /// Total cost of transportation by mile
        /// </summary>
        decimal HHGCostByTotalMiles { get; set; }
        /// <summary>
        /// Total cost of transportation by weight
        /// </summary>
        decimal HHGCostByTotalWeight { get; set; }
        /// <summary>
        /// Total cost of transportation of goods
        /// </summary>
        decimal SubtotalHHG { get; set; }
    }
}
