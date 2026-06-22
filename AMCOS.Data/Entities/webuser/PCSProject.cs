using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations.Schema;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace AMCOS.Data.Entities
{
    public class PCSProject
    {


        #region Project Properties
        /// <summary>
        /// User Id of project owner
        /// </summary>
        public string UserId { get; set; }
        /// <summary>
        /// Name assigned to project
        /// </summary>
        public string ProjectName { get; set; }
        /// <summary>
        /// Date project was saved
        /// </summary>
        public DateTime ProjectSaveDate { get; set; }
        #endregion

        #region Mileage
        /// <summary>
        /// Origination location id
        /// </summary>
        public int? OriginationId { get; set; }
        /// <summary>
        /// Destination location id
        /// </summary>
        public int? DestinationId { get; set; }
        /// <summary>
        /// Appropriation value used in determining JIC inflation / deflation value
        /// </summary>
        public string Appropriation { get; set; }
        /// <summary>
        /// Conversion Type from the JIC inflation deflation table
        /// </summary>
        public string ConversionType { get; set; }
        /// <summary>
        /// Fiscal Year from the JIC Inflation deflation table
        /// </summary>
        public short? Year { get; set; }
        /// <summary>
        /// Amcos Version Id from the JIC inflation deflation table
        /// </summary>
        public int? AmcosVersionId { get; set; }
        /// <summary>
        /// Calculated distance
        /// </summary>
        public int? CalculatedDistance { get; set; }
        #endregion

        #region House Hunting
        /// <summary>
        /// Number of Days hunting for a house
        /// </summary>        
        public int? NumberOfDaysHunting { get; set; }
        /// <summary>
        /// If a spouse will be joining during house hunting
        /// </summary>        
        public bool? HouseHuntingHaveSpouse { get; set; }
        /// <summary>
        /// Lodging Per Diem for house hunting
        /// </summary>
        public decimal? SelfLodgingPerDiem { get; set; }
        /// <summary>
        /// Spouse Lodging Per Diem allowance during house hunting
        /// </summary>
        public decimal? SpouseLodgingPerDiem { get; set; }
        /// <summary>
        /// Meals and other expense reimbursement while house hunting
        /// </summary>
        public decimal? SelfMIEPerDiem { get; set; }
        /// <summary>
        /// Meals and other expense reimbursement for spouse if joining house hunt
        /// </summary>
        public decimal? SpouseMIEPerDiem { get; set; }
        /// <summary>
        /// Total for house hunting reimbursement
        /// </summary>
        public decimal? HouseHuntingTotal { get; set; }
        /// <summary>
        /// Percent of maximum per diem rate for spouse
        /// </summary>
        public decimal? SpousePerDiemRate { get; set; }
        #endregion

        #region Transportation
        /// <summary>
        /// Mileage is reimbursed for POV
        /// </summary>        
        public int? POVMileage { get; set; }
        /// <summary>
        /// True if has dependant children or adults
        /// </summary>        
        public int? TransportationDependents { get; set; }
        /// <summary>
        /// PCS Mileage Allowance in Leue of Transportation rate
        /// </summary>
        public decimal? PCSMaltRate { get; set; }
        /// <summary>
        /// Mileage multiplied by the PCS MALT Rate.
        /// </summary>
        public decimal? MileageReimbursement { get; set; }
        /// <summary>
        /// The government allows Mileage Allowance in Leue of Transportation if dependants when two POVs are used.  
        /// </summary>
        public decimal? DependantMileageReimbursement { get; set; }
        /// <summary>
        /// Total Transportation reimbursement
        /// </summary>        
        public decimal? TransportationSubTotal { get; set; }
        #endregion

        #region TQSE
        /// <summary>
        /// Total number of whole days for TQSE
        /// </summary>        
        public int? NumberDaysTQSE { get; set; }
        /// <summary>
        /// Whether or not the client has a spouse
        /// </summary>        
        public int? TQSEDependents { get; set; }
        /// <summary>
        /// Calculation for TQSE Per Diem Lodging
        /// </summary>
        public decimal? TQSESelfPerDiemLodging { get; set; }
        /// <summary>
        /// Calculation for TQSE Spouse Per Diem Lodging
        /// </summary>
        public decimal? TQSESpousePerDiemLodging { get; set; }
        /// <summary>
        /// Calculation for TQSE Per diem MI&E
        /// </summary>
        public decimal? TQSESelfPerDiemMIE { get; set; }
        /// <summary>
        /// Calculation for TQSE Spouse Per Diem MI&E
        /// </summary>
        public decimal? TQSESpousePerDiemMIE { get; set; }
        /// <summary>
        /// TQSE Self Per Diem Rate
        /// </summary>
        public decimal? TQSEPerDiemRate { get; set; }
        /// <summary>
        /// TQSE Spouse PerDiem Rate
        /// </summary>
        public decimal? TQSESpousePerDiemRate { get; set; }
        /// <summary>
        /// Total of TQSE Reimbursement
        /// </summary>
        public decimal? TQSETotal { get; set; }
        #endregion

        #region Goods / Home Transportation
        /// <summary>
        /// Type of Transportation either Goods or Mobile home
        /// </summary>        
        public string TransportationType { get; set; }
        /// <summary>
        /// Total of Goods / Home transportation reimbursement
        /// </summary>
        public decimal? GHTransportationTotal { get; set; }
        /// <summary>
        /// Total miles goods to be transported
        /// </summary>        
        public int? HHGTotalMileage { get; set; }
        /// <summary>
        /// Total weight of goods to be transported
        /// </summary>        
        public double? HHGTotalWeight { get; set; }
        /// <summary>
        /// Max reimbursableWeight
        /// </summary>
        public int? HHGMaxWeight { get; set; }
        /// <summary>
        /// Estimation of cost per mile of transportation
        /// </summary>
        public decimal? HHGEstimatedCostPerMile { get; set; }
        /// <summary>
        /// Estimated cost per pound for transportation
        /// </summary>
        public decimal? HHGEstimatedCostPerPound { get; set; }
        /// <summary>
        /// Total cost of transportation by mile
        /// </summary>
        public decimal? HHGCostByTotalMiles { get; set; }
        /// <summary>
        /// Total cost of transportation by weight
        /// </summary>
        public decimal? HHGCostByTotalWeight { get; set; }
        /// <summary>
        /// Total cost of transportation of goods
        /// </summary>
        public decimal? SubtotalHHG { get; set; }
        /// <summary>
        /// Total miles for mobile home transportation
        /// </summary>        
        public int? MobileHomeTotalMileage { get; set; }
        /// <summary>
        /// Estimated cost for moving a mobile home per mile
        /// </summary>       
        public decimal? MobileHomeEstCostPerMile { get; set; }
        /// <summary>
        /// Total estimated cost for moving the mobile home
        /// </summary>
        public decimal? MobileHomeSubtotal { get; set; }
        #endregion

        #region MEA
        /// <summary>
        /// Does the client have a spouse?
        /// </summary>
        public bool? MEAHasSpouse { get; set; }
        /// <summary>
        /// Total for Miscellaneous Expense Allowance
        /// </summary>
        public decimal? MEASubtotal { get; set; }
        /// <summary>
        /// Max MEA Allowance for a single civilian with no documentation
        /// </summary>
        public decimal? MEACivilian { get; set; }
        /// <summary>
        /// Max MEA allowance for a civilian and spouse with no documentation
        /// </summary>
        public decimal? MEACivilianAndSpouse { get; set; }

        #endregion

        #region Real Estate / Lease
        /// <summary>
        /// Sale price of old home sold
        /// </summary>
        public decimal? SalePriceAmount { get; set; }
        /// <summary>
        /// Purchase price of new residence
        /// </summary>
        public decimal? PurchasePriceAmount { get; set; }
        /// <summary>
        /// Sale price refund percentage 
        /// </summary>
        public decimal? SalePriceRefund { get; set; }
        /// <summary>
        /// Purchase price refund percentage
        /// </summary>
        public decimal? PurchasePriceRefund { get; set; }
        /// <summary>
        /// Subtotal of Real Estate reimbursement allowance
        /// </summary>
        public decimal? RealEstateSubtotal { get; set; }
        /// <summary>
        /// Unexpired Lease (UEL) early termination fee
        /// </summary>
        public decimal? UELAmount { get; set; }
        /// <summary>
        /// Total reimbursement for Unexpired Lease (UEL)
        /// </summary>
        public decimal? UELTotal { get; set; }
        /// <summary>
        /// Whether Real Estate or UEL will be reimbursed
        /// </summary>
        public string RealEstateOrLease { get; set; }
        /// <summary>
        /// Total for reimbursement of either real estate or unexpired lease
        /// </summary>
        public decimal? RealEstateLeaseTotal { get; set; }

        #endregion

        #region NTS
        /// <summary>
        /// Is the permanent duty station isolated
        /// </summary>
        public bool? IsIsolatedDutyStation { get; set; }

        /// <summary>
        /// Non-Temporary Storage reimbursement total
        /// </summary>
        public decimal? NTSSubtotal { get; set; }
        #endregion

        #region RITA
        /// <summary>
        /// Assumed Tax Rate for federal, social security and medicare
        /// </summary>
        public decimal? DefaultFederalTaxRate { get; set; }
        /// <summary>
        /// TaxBracket used for calculating RITA values
        /// </summary>
        public decimal? FederalTaxRate { get; set; }
        /// <summary>
        /// Medicare Tax Rate
        /// </summary>
        public decimal? MedicareTaxRate { get; set; }
        /// <summary>
        /// Social Security Tax Rate
        /// </summary>
        public decimal? SocialSecurityTaxRate { get; set; }
        /// <summary>
        /// State income tax value used for calculating RITA
        /// </summary>
        public decimal? StateTaxRate { get; set; }
        /// <summary>
        /// Estimated County Tax Rate
        /// </summary>
        public decimal? CountyTaxRate { get; set; }
        /// <summary>
        /// Estimated City Tax Rate
        /// </summary>
        public decimal? CityTaxRate { get; set; }
        /// <summary>
        /// Total of Federal Income Tax, Medicare, Social Security, State, County, and City Tax Rates
        /// </summary>
        public decimal? TotalTaxRate { get; set; }
        /// <summary>
        /// Subtotal of Relocation Income Tax Allowance
        /// </summary>
        public decimal? RITASubtotal { get; set; }
        /// <summary>
        /// House Hunting Total RITA value
        /// </summary>
        public decimal? HouseHuntingRITA { get; set; }
        /// <summary>
        /// Transportation RITA value
        /// </summary>
        public decimal? TransportationRITA { get; set; }
        /// <summary>
        /// TQSE RITA value
        /// </summary>
        public decimal? TQSERITA { get; set; }
        /// <summary>
        /// Goods / Home Transportation RITA value
        /// </summary>
        public decimal? GHTransportationRITA { get; set; }
        /// <summary>
        /// Miscellaneous Expense Allowance RITA value
        /// </summary>
        public decimal? MEARITA { get; set; }
        /// <summary>
        /// Real Estate RITA value
        /// </summary>
        public decimal? RealEstateLeaseRITA { get; set; }
        /// <summary>
        /// Non Temporary Storage RITA
        /// </summary>
        public decimal? NTSRITA { get; set; }
        #endregion

        #region GrandTotal
        /// <summary>
        /// Grand Total of all reimbursable expenses
        /// </summary>
        public decimal? GrandTotal { get; set; }
        #endregion
        public bool Deleted { get; set; } = false;

    }
}
