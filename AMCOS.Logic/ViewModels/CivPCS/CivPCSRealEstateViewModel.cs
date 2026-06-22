using AMCOS.Logic.Models;

namespace AMCOS.Logic.ViewModels
{
    public class CivPcsRealEstateViewModel : IModel, ICivPcsRealEstate
    {       
        /// <summary>
        /// Title for the content page
        /// </summary>
        public string Title => "Real Estate Allowance";
        /// <summary>
        /// View associated with this model
        /// </summary>
        public string View => "_RealEstate";
        /// <summary>
        /// Sale price of old home sold
        /// </summary>
        public decimal SalePriceAmount { get; set; } = 0;
        /// <summary>
        /// Percent of sale price to be refunded
        /// </summary>
        public decimal SalePriceRefund { get; set; } = 0;
        /// <summary>
        /// Purchase price of new residence
        /// </summary>
        public decimal PurchasePriceAmount { get; set; } = 0;
        /// <summary>
        /// Percent of purchase price to be refunded
        /// </summary>
        public decimal PurchasePriceRefund { get; set; } = 0;
        /// <summary>
        /// Subtotal of Real Estate reimbursement allowance
        /// </summary>
        public decimal RealEstateSubtotal { get; set; } = 0;

    }
    public interface ICivPcsRealEstate
    {
        /// <summary>
        /// Sale price of old home sold
        /// </summary>
        decimal SalePriceAmount { get; set; }
        /// <summary>
        /// Percent of sale price to be refunded
        /// </summary>
        decimal SalePriceRefund { get; set; }
        /// <summary>
        /// Purchase price of new residence
        /// </summary>
        decimal PurchasePriceAmount { get; set; }
        /// <summary>
        /// Percent of purchase price to be refunded
        /// </summary>
        decimal PurchasePriceRefund { get; set; }
        /// <summary>
        /// Subtotal of Real Estate reimbursement allowance
        /// </summary>
        decimal RealEstateSubtotal { get; set; }
    }
}
