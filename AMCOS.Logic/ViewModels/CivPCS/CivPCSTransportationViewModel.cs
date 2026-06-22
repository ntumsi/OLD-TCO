using AMCOS.Logic.Models;
using System;

namespace AMCOS.Logic.ViewModels
{
    public class CivPcsTransportationViewModel : IModel, ICivPcsTransportation
    {
        public CivPcsTransportationViewModel(int amcosVersionId)
        {
            PCSMaltRate = SingleValue.Get("AA", "PCS_MALT_Rate", amcosVersionId);
            TransportationVersionYear = Convert.ToInt16(amcosVersionId.ToString().Substring(0, 4));
        }
        /// <summary>
        /// Title of the form
        /// </summary>
        public string Title => "Transportation Expense";
        /// <summary>
        /// View associated with this model
        /// </summary>
        public string View => "_Transportation";
        /// <summary>
        /// Mileage is reimbursed for POV
        /// </summary>
        public int POVMileage { get; set; } = 0;
        /// <summary>
        /// True if has dependant children or adults
        /// </summary>
        public int TransportationDependents { get; set; } = 0;
        /// <summary>
        /// PCS Mileage Allowance in Leue of Transportation rate
        /// </summary>
        public decimal PCSMaltRate { get; set; }
        /// <summary>
        /// Year for which transportation values will be calculated
        /// </summary>
        public short TransportationVersionYear { get; set; } 
        /// <summary>
        /// Mileage multiplied by the PCS MALT Rate.
        /// </summary>
        public decimal MileageReimbursement { get; set; }
        /// <summary>
        /// The government allows Mileage Allowance in Leue of Transportation if dependants when two POVs are used.  
        /// </summary>
        public decimal DependantMileageReimbursement { get; set; }
        /// <summary>
        /// Total Transportation reimbursement
        /// </summary>        
        public decimal TransportationSubTotal { get; set; }
    }
    public interface ICivPcsTransportation
    {
        /// <summary>
        /// Mileage is reimbursed for POV
        /// </summary>
        int POVMileage { get; set; } 
        /// <summary>
        /// True if has dependant children or adults
        /// </summary>
        int TransportationDependents { get; set; }        
        /// <summary>
        /// PCS Mileage Allowance in Leue of Transportation rate
        /// </summary>
        decimal PCSMaltRate { get; set; }
        /// <summary>
        /// Year for which transportation values will be calculated
        /// </summary>
        short TransportationVersionYear { get; set; }
        /// <summary>
        /// Mileage multiplied by the PCS MALT Rate.
        /// </summary>
        decimal MileageReimbursement { get; set; }
        /// <summary>
        /// The government allows Mileage Allowance in Leue of Transportation if dependants when two POVs are used.  
        /// </summary>
        decimal DependantMileageReimbursement { get; set; }
        /// <summary>
        /// Total Transportation reimbursement
        /// </summary>        
        decimal TransportationSubTotal { get; set; }
    }
}
