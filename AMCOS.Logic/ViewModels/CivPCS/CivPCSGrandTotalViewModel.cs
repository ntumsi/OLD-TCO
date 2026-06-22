using AMCOS.Logic.Models;

namespace AMCOS.Logic.ViewModels
{
    public class CivPcsGrandTotalViewModel : IModel, ICivPcsGrandTotal
    {
        /// <summary>
        /// Title of the content panel
        /// </summary>
        public string Title => "Grand Total of All Reimbursable Expenses";
        /// <summary>
        /// View Associated with this model
        /// </summary>
        public string View => "_GrandTotal";
        /// <summary>
        /// Grand Total of all reimbursable expenses
        /// </summary>
        public decimal GrandTotal { get; set; } = 0;
    }
    public interface ICivPcsGrandTotal
    {
        /// <summary>
        /// Grand Total of all reimbursable expenses
        /// </summary>
        decimal GrandTotal { get; set; }
    }
}
