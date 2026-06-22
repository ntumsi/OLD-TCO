using AMCOS.Logic.Models;

namespace AMCOS.Logic.ViewModels
{
    public class CivPcsNtsViewModel : IModel, ICivPcsNts
    {
        /// <summary>
        /// Title of the content panel
        /// </summary>
        public string Title => "Non-Temporary Storage";
        /// <summary>
        /// View associated with this model
        /// </summary>
        public string View => "_NTS";
        /// <summary>
        /// Is the permanent duty station isolated
        /// </summary>
        public bool IsIsolatedDutyStation { get; set; } = false;
        /// <summary>
        /// Flag indicating whether the value of IsIsolatedDutyStation checkbox was changed
        /// </summary>
        public bool IsIsolatedDutyStationChanged { get; set; } = false;
        /// <summary>
        /// Non-Temporary Storage reimbursement total
        /// </summary>
        public decimal NTSSubtotal { get; set; } = 0;
    }
    public interface ICivPcsNts
    {
        /// <summary>
        /// Is the permanent duty station isolated
        /// </summary>
        bool IsIsolatedDutyStation { get; set; }
        /// <summary>
        /// Flag indicating whether the value of IsIsolatedDutyStation checkbox was changed
        /// </summary>
        bool IsIsolatedDutyStationChanged { get; set; }
        /// <summary>
        /// Non-Temporary Storage reimbursement total
        /// </summary>
        decimal NTSSubtotal { get; set; }
    }
}
