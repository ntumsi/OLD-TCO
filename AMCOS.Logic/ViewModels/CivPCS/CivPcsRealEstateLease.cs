using AMCOS.Logic.Models;

namespace AMCOS.Logic.ViewModels
{
    public class CivPcsRealEstateLease : IModel, ICivPcsRealEstateLease
    {
        /// <summary>
        /// Title of view
        /// </summary>
        public string Title => "Real Estate / Unexpired Lease";
        /// <summary>
        /// View associtated with this view model
        /// </summary>
        public string View => "_RealEstateLease";
        /// <summary>
        /// Whether Real Estate or UEL will be reimbursed
        /// </summary>
        public string RealEstateOrLease { get; set; } = "RealEstate";
        /// <summary>
        /// Total for reimbursement of either real estate or unexpired lease
        /// </summary>
        public decimal RealEstateLeaseTotal { get; set; } = 0;
        public ICivPcsRealEstate RealEstateModel { get; } = new CivPcsRealEstateViewModel();
        public ICivPcsLease LeaseModel { get; } = new CivPcsLeaseViewModel();
    }

    public interface ICivPcsRealEstateLease
    {
        /// <summary>
        /// Whether Real Estate or UEL will be reimbursed
        /// </summary>
        string RealEstateOrLease { get; set; }
        /// <summary>
        /// Total for reimbursement of either real estate or unexpired lease
        /// </summary>
        decimal RealEstateLeaseTotal { get; set; }
        ICivPcsRealEstate RealEstateModel { get; }
        ICivPcsLease LeaseModel { get; }
    }    
}
