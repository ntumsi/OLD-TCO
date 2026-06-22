using AMCOS.Logic.Models;

namespace AMCOS.Logic.ViewModels
{
    public class CivPcsMeaViewModel : IModel, ICivPcsMea
    {
        public CivPcsMeaViewModel(int amcosVersion)
        {
            MEACivilian = SingleValue.Get("AA", "PCS_MEACivilian", amcosVersion);
            MEACivilianAndSpouse = SingleValue.Get("AA", "PCS_MEACivilianAndSpouse", amcosVersion);
            MEASubtotal = 0;
        }
        /// <summary>
        /// Title of content panel
        /// </summary>
        public string Title => "Miscellaneous Expense Allowance";
        /// <summary>
        /// View associated with this model
        /// </summary>
        public string View => "_MEA";
        /// <summary>
        /// Does the client have a spouse?
        /// </summary>
        public bool MEAHasSpouse { get; set; } = true;
        /// <summary>
        /// Total for Miscellaneous Expense Allowance
        /// </summary>
        public decimal MEASubtotal { get; set; }
        /// <summary>
        /// Max MEA Allowance for a single civilian with no documentation
        /// </summary>
        public decimal MEACivilian { get; set; }
        /// <summary>
        /// Max MEA allowance for a civilian and spouse with no documentation
        /// </summary>
        public decimal MEACivilianAndSpouse { get; set; }
        
    }
    public interface ICivPcsMea
    {
        /// <summary>
        /// Does the client have a spouse?
        /// </summary>
        bool MEAHasSpouse { get; set; }
        /// <summary>
        /// Total for Miscellaneous Expense Allowance
        /// </summary>
        decimal MEASubtotal { get; set; }
        /// <summary>
        /// Max MEA Allowance for a single civilian with no documentation
        /// </summary>
        decimal MEACivilian { get; set; }
        /// <summary>
        /// Max MEA allowance for a civilian and spouse with no documentation
        /// </summary>
        decimal MEACivilianAndSpouse { get; set; }
       
    }
}
