using AMCOS.Logic.Models;

namespace AMCOS.Logic.ViewModels
{
    public class CivPcsLeaseViewModel : IModel, ICivPcsLease
    {
        /// <summary>
        /// Title associated with the view model
        /// </summary>
        public string Title => "Unexpired Lease Reimbursement";
        /// <summary>
        /// View associated with this model
        /// </summary>
        public string View => "_Lease";
        /// <summary>
        /// Unexpired Lease (UEL) early termination fee
        /// </summary>
        public decimal UELAmount { get; set; } = 0;
        /// <summary>
        /// Total reimbursement for Unexpired Lease (UEL)
        /// </summary>
        public decimal UELTotal { get; set; } = 0;
    }
    public interface ICivPcsLease
    {
        /// <summary>
        /// Unexpired Lease (UEL) early termination fee
        /// </summary>
        decimal UELAmount { get; set; }
        /// <summary>
        /// Total reimbursement for Unexpired Lease (UEL)
        /// </summary>
        decimal UELTotal { get; set; }
    }
}
