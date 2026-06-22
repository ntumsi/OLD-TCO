using AMCOS.Data.Entities;
using AMCOS.Logic.Attributes;
using AMCOS.Logic.Helpers;
using Newtonsoft.Json;
using System;

namespace AMCOS.Logic.ViewModels
{
    public class CivPcsJson : BaseJson, ICivPcsMileage, ICivPcsHouseHunting, ICivPcsTransportation, ICivPcsTqse, ICivPcsHhg, ICivPcsMobileHome, ICivPcsMea, ICivPcsRealEstate, ICivPcsLease, ICivPcsNts, ICivPcsRita, ICivPcsGrandTotal
    {
        /// <summary>
        /// Flag indicating whether the locations have changed.
        /// </summary>
        public bool LocationChanged { get; set; }
        /// <summary>
        /// Flag indicating that the source / destination mileage was changed.
        /// </summary>
        public bool MileageChanged { get; set; }
        /// <summary>
        /// Flag indicating that the Transportation POV Mileage value was changed.
        /// </summary>
        public bool POVMileageChanged { get; set; }
        /// <summary>
        /// Element Id of input whose value was changed.
        /// </summary>
        public string ValueChangedElementId { get; set; }
        /// <summary>
        /// Flag indicating whether the application values need to be updated with defaults
        /// </summary>
        public bool InitialState { get; set; } = true;
        /// <summary>
        /// Flag indicating whether the value of IsIsolatedDutyStation checkbox was changed
        /// </summary>
        public bool IsIsolatedDutyStationChanged { get; set; }
        /// <summary>
        /// True if the number of transporation dependents were just changed resets to false after recalculation
        /// </summary>
        public bool TransDependentsChanged { get; set; }
        /// <summary>
        /// Inflation rate multiplier 
        /// </summary>
        public decimal JicInflationRate { get; set; }
        /// <summary>
        /// Year associated with Transportation rate calculation
        /// </summary>
        public short TransportationVersionYear { get; set; }

        #region Project Properties        
        /// <summary>
        /// Name assigned to project
        /// </summary>
        public string ProjectName { get; set; }
        /// <summary>
        /// Date project was saved
        /// </summary>
        public DateTime ProjectSaveDate { get; set; }
        /// <summary>
        /// Column in View Projects for sorting
        /// </summary>
        public string ViewProjectsSortColumn { get; set; } = "ProjectSaveDate";
        /// <summary>
        /// Sort order of projects in view projects partial
        /// </summary>
        public string ViewProjectsSortOrder { get; set; } = "desc";
        #endregion

        #region Mileage
        /// <summary>
        /// Origination String for export
        /// </summary>
        [JsonIgnore]
        [ForExport("PCS Estimations", "Origination :")]
        public string Origination => PcsPropertyHelper.GetCivPCSLocationById(OriginationId, AmcosVersionId)?.Text;
        /// <summary>
        /// Origination location id
        /// </summary>
        public int OriginationId { get; set; }
        /// <summary>
        /// Destination string for export
        /// </summary>
        [JsonIgnore]
        [ForExport("PCS Estimations", "Destination :")]
        public string Destination => PcsPropertyHelper.GetCivPCSLocationById(DestinationId, AmcosVersionId)?.Text;
        /// <summary>
        /// Destination location id
        /// </summary>
        public int DestinationId { get; set; }
        /// <summary>
        /// Appropriation value used in determining JIC inflation / deflation value
        /// </summary>
        [ForExport("PCS Estimations", "Appropriation :")]
        public string Appropriation { get; set; }
        /// <summary>
        /// Conversion Type from the JIC inflation deflation table
        /// </summary>
        [ForExport("PCS Estimations", "Conversion Type :")]
        public string ConversionType { get; set; }
        /// <summary>
        /// Fiscal Year from the JIC inflation deflation table
        /// </summary>
        [ForExport("PCS Estimations", "Fiscal Year :")]
        public short Year { get; set; }
        /// <summary>
        /// Amcos Version Id from the JIC inflation deflation table
        /// </summary>        
        public int AmcosVersionId { get; set; }
        /// <summary>
        /// Calculated distance
        /// </summary>
        [ForExport("PCS Estimations", "Calculated Distance :")]
        public int CalculatedDistance { get; set; }
        #endregion

        #region House Hunting
        /// <summary>
        /// Number of Days hunting for a house
        /// </summary>
        [ForExport("House Hunting", "Number of Days Hunting :")]
        public int NumberOfDaysHunting { get; set; }
        /// <summary>
        /// If a spouse will be joining during house hunting
        /// </summary>
        [ForExport("House Hunting", "Have Spouse :")]
        public bool HouseHuntingHaveSpouse { get; set; }
        /// <summary>
        /// Lodging Per Diem for house hunting
        /// </summary>
        [ForExport("House Hunting", "Per Diem Rate Per Day based on Destination", "Lodging Per Diem", "Self Per Diem :")]
        public decimal SelfLodgingPerDiem { get; set; }
        /// <summary>
        /// Spouse Lodging Per Diem allowance during house hunting
        /// </summary>
        [ForExport("House Hunting", "Per Diem Rate Per Day based on Destination", "Lodging Per Diem", "Spouse Per Diem :")]
        public decimal SpouseLodgingPerDiem { get; set; }
        /// <summary>
        /// Meals and other expense reimbursement while house hunting
        /// </summary>
        [ForExport("House Hunting", "Per Diem Rate Per Day based on Destination", "MIE Per Diem", "Self Per Diem :")]
        public decimal SelfMIEPerDiem { get; set; }
        /// <summary>
        /// Meals and other expense reimbursement for spouse if joining house hunt
        /// </summary>
        [ForExport("House Hunting", "Per Diem Rate Per Day based on Destination", "MIE Per Diem", "Spouse Per Diem :")]
        public decimal SpouseMIEPerDiem { get; set; }
        /// <summary>
        /// Total for house hunting reimbursement
        /// </summary>        
        [ForExport("House Hunting", "Total (House Hunting) :")]
        public decimal HouseHuntingTotal { get; set; }
        /// <summary>
        /// Percent of maximum per diem rate for spouse
        /// </summary>
        public decimal SpousePerDiemRate { get; set; }
        #endregion

        #region Transportation
        /// <summary>
        /// Mileage is reimbursed for POV
        /// </summary>
        [ForExport("Transportation", "POV Mileage :")]
        public int POVMileage { get; set; }
        /// <summary>
        /// True if has dependant children or adults
        /// </summary>
        [ForExport("Transportation", "Dependants :")]
        public int TransportationDependents { get; set; }
        /// <summary>
        /// PCS Mileage Allowance in Leue of Transportation rate
        /// </summary>
        [ForExport("Transportation", "MALT Rate :")]
        public decimal PCSMaltRate { get; set; }
        /// <summary>
        /// Mileage multiplied by the PCS MALT Rate.
        /// </summary>
        [ForExport("Transportation", "Mileage Reimbursement :")]
        public decimal MileageReimbursement { get; set; }
        /// <summary>
        /// The government allows Mileage Allowance in Leue of Transportation if dependants when two POVs are used.  
        /// </summary>
        [ForExport("Transportation", "Dependant Mileage Reimbursement :")]
        public decimal DependantMileageReimbursement { get; set; }
        /// <summary>
        /// Total Transportation reimbursement
        /// </summary>
        [ForExport("Transportation", "Total (Transportation) :")]
        public decimal TransportationSubTotal { get; set; }
        #endregion

        #region TQSE
        /// <summary>
        /// Total number of whole days for Temporary Quarters Subsistence Expense
        /// </summary>
        [ForExport("TQSE", "Number of Days TQSE :")]
        public int NumberDaysTQSE { get; set; }
        /// <summary>
        /// Whether or not the client has a spouse
        /// </summary>
        [ForExport("TQSE", "Have Spouse")]
        public int TQSEDependents { get; set; }
        /// <summary>
        /// Calculation for TQSE Per Diem Lodging
        /// </summary>
        [ForExport("TQSE", "Per Diem Rate Per Day based on Destination", "Lodging", "Self Per Diem :")]
        public decimal TQSESelfPerDiemLodging { get; set; }
        /// <summary>
        /// Calculation for TQSE Spouse Per Diem Lodging
        /// </summary>
        [ForExport("TQSE", "Per Diem Rate Per Day based on Destination", "Lodging", "Spouse Per Diem :")]
        public decimal TQSESpousePerDiemLodging { get; set; }
        /// <summary>
        /// Calculation for TQSE Per diem MI&E
        /// </summary>
        [ForExport("TQSE", "Per Diem Rate Per Day based on Destination", "MI&E", "Self Per Diem :")]
        public decimal TQSESelfPerDiemMIE { get; set; }
        /// <summary>
        /// Calculation for TQSE Spouse Per Diem MI&E
        /// </summary>
        [ForExport("TQSE", "Per Diem Rate Per Day based on Destination", "MI&E", "Spouse Per Diem :")]
        public decimal TQSESpousePerDiemMIE { get; set; }
        /// <summary>
        /// TQSE Self Per Diem Rate
        /// </summary>
        public decimal TQSEPerDiemRate { get; set; }
        /// <summary>
        /// TQSE Spouse PerDiem Rate
        /// </summary>
        public decimal TQSESpousePerDiemRate { get; set; }
        /// <summary>
        /// Total of TQSE Reimbursement
        /// </summary>
        [ForExport("TQSE", "Total (TQSE) :")]
        public decimal TQSETotal { get; set; }
        #endregion

        #region Goods / Home Transportation
        /// <summary>
        /// Type of Transportation either Goods or Mobile home
        /// </summary>
        
        public string TransportationType { get; set; }
        
        /// <summary>
        /// Total miles goods to be transported
        /// </summary>
        [ExportIf("TransportationType", "Goods")]
        [ForExport("Household Goods", "Total Mileage :")]
        public int HHGTotalMileage { get; set; }
        /// <summary>
        /// Total weight of goods to be transported
        /// </summary> 
        [ExportIf("TransportationType", "Goods")]
        [ForExport("Household Goods", "Total Weight :")]
        public double HHGTotalWeight { get; set; }
        /// <summary>
        /// Max reimbursableWeight
        /// </summary>
        public int HHGMaxWeight { get; set; }
        /// <summary>
        /// Estimation of cost per mile of transportation
        /// </summary>
        [ExportIf("TransportationType", "Goods")]
        [ForExport("Household Goods", "Estimated Cost Per Mile :")]
        public decimal HHGEstimatedCostPerMile { get; set; }
        /// <summary>
        /// Estimated cost per pound for transportation
        /// </summary>
        [ExportIf("TransportationType", "Goods")]
        [ForExport("Household Goods", "Estimated Cost Per Pound :")]
        public decimal HHGEstimatedCostPerPound { get; set; }
        /// <summary>
        /// Total cost of transportation by mile
        /// </summary>
        [ExportIf("TransportationType", "Goods")]
        [ForExport("Household Goods", "Cost By Total Miles :")]
        public decimal HHGCostByTotalMiles { get; set; }
        /// <summary>
        /// Total cost of transportation by weight
        /// </summary>
        [ExportIf("TransportationType", "Goods")]
        [ForExport("Household Goods", "Cost By Total Weight :")]
        public decimal HHGCostByTotalWeight { get; set; }
        /// <summary>
        /// Total cost of transportation of goods
        /// </summary>
        [ExportIf("TransportationType", "Goods")]
        [ForExport("Household Goods", "Total (HHG Transportation) :")]
        public decimal SubtotalHHG { get; set; }
        /// <summary>
        /// Total miles for mobile home transportation
        /// </summary>
        [ExportIf("TransportationType", "Home")]
        [ForExport("Mobile Home Transportation", "Total Mileage :")]
        public int MobileHomeTotalMileage { get; set; }
        /// <summary>
        /// Estimated cost for moving a mobile home per mile
        /// </summary>
        [ExportIf("TransportationType", "Home")]
        [ForExport("Mobile Home Transportation", "Estimated Cost Per Mile :")]
        public decimal MobileHomeEstCostPerMile { get; set; }
        /// <summary>
        /// Total estimated cost for moving the mobile home
        /// </summary>
        [ExportIf("TransportationType", "Home")]
        [ForExport("Mobile Home Transportation", "Total (Mobile Home Tranportation) :")]
        public decimal MobileHomeSubtotal { get; set; }
        /// <summary>
        /// Total of Goods / Home transportation reimbursement
        /// </summary>
        public decimal GHTransportationTotal { get; set; }
        #endregion

        #region MEA  
        /// <summary>
        /// Does the client have a spouse?
        /// </summary>
        [ForExport("MEA", "Have Spouse : ")]
        public bool MEAHasSpouse { get; set; }
        /// <summary>
        /// Total for Miscellaneous Expense Allowance
        /// </summary>
        [ForExport("MEA", "Total (Miscellaneous Expense Allowance) :")]
        public decimal MEASubtotal { get; set; }
        /// <summary>
        /// Max MEA Allowance for a single civilian with no documentation
        /// </summary>
        public decimal MEACivilian { get; set; }
        /// <summary>
        /// Max MEA allowance for a civilian and spouse with no documentation
        /// </summary>
        public decimal MEACivilianAndSpouse { get; set; }

        #endregion

        #region Real Estate / Lease
        /// <summary>
        /// Sale price of old home sold
        /// </summary>
        [ExportIf("RealEstateOrLease", "RealEstate")]
        [ForExport("Real Estate", "Sale Price :")]
        public decimal SalePriceAmount { get; set; }
        /// <summary>
        /// Percent of sale price to be refunded
        /// </summary>
        [ExportIf("RealEstateOrLease", "RealEstate")]
        [ForExport("Real Estate", "% Refund of Sale Price :")]
        public decimal SalePriceRefund { get; set; }
        /// <summary>
        /// Purchase price of new residence
        /// </summary>
        [ExportIf("RealEstateOrLease", "RealEstate")]
        [ForExport("Real Estate", "Purchase Price :")]
        public decimal PurchasePriceAmount { get; set; }
        /// <summary>
        /// Percent of purchase price to be refunded
        /// </summary>
        [ExportIf("RealEstateOrLease", "RealEstate")]
        [ForExport("Real Estate", "% Refund of Purchase Price :")]
        public decimal PurchasePriceRefund { get; set; }
        /// <summary>
        /// Subtotal of Real Estate reimbursement allowance
        /// </summary>
        [ExportIf("RealEstateOrLease", "RealEstate")]
        [ForExport("Real Estate", "Total (Real Estate) :")]
        public decimal RealEstateSubtotal { get; set; }
        /// <summary>
        /// Unexpired Lease (UEL) early termination fee
        /// </summary>
        [ExportIf("RealEstateOrLease", "Lease")]
        [ForExport("Unexpired Lease", "UEL Amount :")]
        public decimal UELAmount { get; set; }
        /// <summary>
        /// Total reimbursement for Unexpired Lease (UEL)
        /// </summary>
        [ExportIf("RealEstateOrLease", "Lease")]
        [ForExport("Unexpired Lease", "Total (UEL) :")]
        public decimal UELTotal { get; set; }
        /// <summary>
        /// Whether Real Estate or UEL will be reimbursed
        /// </summary>
        public string RealEstateOrLease { get; set; }
        /// <summary>
        /// Total for reimbursement of either real estate or unexpired lease
        /// </summary>
        public decimal RealEstateLeaseTotal { get; set; }

        #endregion

        #region NTS
        /// <summary>
        /// Is the permanent duty station isolated
        /// </summary>
        [ForExport("NTS", "Is Duty Station Isolated :" )]
        public bool IsIsolatedDutyStation { get; set; }

        /// <summary>
        /// Non-Temporary Storage reimbursement total
        /// </summary>
        [ForExport("NTS", "Total (Non-Temporary Storage) :")]
        public decimal NTSSubtotal { get; set; }
        #endregion

        #region RITA
        /// <summary>
        /// Assumed tax rate for federal, social security, and medicare
        /// </summary>       
        public decimal DefaultFederalTaxRate { get; set; }
        /// <summary>
        /// Tax bracket used for calculating RITA values
        /// </summary>
        [ForExport("RITA", "Federal Income Tax Rate:")]
        public decimal FederalTaxRate { get; set; }
        /// <summary>
        /// Medicare Tax Rate
        /// </summary>
        [ForExport("RITA", "Medicare Tax Rate:")]
        public decimal MedicareTaxRate { get; set; }
        /// <summary>
        /// Social Security Tax Rate
        /// </summary>
        [ForExport("RITA", "Social Security Tax Rate:")]
        public decimal SocialSecurityTaxRate { get; set; }
        /// <summary>
        /// State income tax value used for calculating RITA
        /// </summary>
        [ForExport("RITA", "State Income Tax Rate:")]
        public decimal StateTaxRate { get; set; }
        /// <summary>
        /// Estimated County Tax Rate
        /// </summary>
        [ForExport("RITA", "County Tax Rate:")]
        public decimal CountyTaxRate { get; set; }
        /// <summary>
        /// Estimated City Tax Rate
        /// </summary>
        [ForExport("RITA", "City Tax Rate:")]
        public decimal CityTaxRate { get; set; }
        /// <summary>
        /// Total of Federal Income Tax, Medicare, Social Security, State, County, and City Tax Rates
        /// </summary>
        [ForExport("RITA", "Total Tax Rate :")]
        public decimal TotalTaxRate { get; set; }
        /// <summary>
        /// House Hunting Total RITA value
        /// </summary>
        [ForExport("RITA", "Income Tax Reimbursement By Topic", "Reimburement Amount", "House Hunting Trip Tax:")]
        public decimal HouseHuntingRITA { get; set; }
        /// <summary>
        /// Transportation RITA value
        /// </summary>
        [ForExport("RITA", "Income Tax Reimbursement By Topic", "Reimburement Amount", "Transporation Expense Tax:")]
        public decimal TransportationRITA { get; set; }
        /// <summary>
        /// TQSE RITA value
        /// </summary>
        [ForExport("RITA", "Income Tax Reimbursement By Topic", "Reimburement Amount", "Temporary Quarters Subsistence Expense Tax :")]
        public decimal TQSERITA { get; set; }
        /// <summary>
        /// Goods / Home Transportation RITA value
        /// </summary>
        [ForExport("RITA", "Income Tax Reimbursement By Topic", "Reimburement Amount", "Goods / Home Transporation Tax:")]
        public decimal GHTransportationRITA { get; set; }
        /// <summary>
        /// Miscellaneous Expense Allowance RITA value
        /// </summary>
        [ForExport("RITA", "Income Tax Reimbursement By Topic", "Reimburement Amount", "Miscellaneous Expenses Tax :")]
        public decimal MEARITA { get; set; }
        /// <summary>
        /// Real Estate RITA value
        /// </summary>
        [ForExport("RITA", "Income Tax Reimbursement By Topic", "Reimburement Amount", "Real Estate / UEL Tax :")]
        public decimal RealEstateLeaseRITA { get; set; }
        /// <summary>
        /// Non Temporary Storage RITA
        /// </summary>
        [ForExport("RITA", "Income Tax Reimbursement By Topic", "Reimburement Amount", "Non-Temporary Storage Tax :")]
        public decimal NTSRITA { get; set; }
        /// <summary>
        /// Subtotal of Relocation Income Tax Allowance
        /// </summary>
        [ForExport("RITA", "Total (Relocation Income Tax) :")]
        public decimal RITASubtotal { get; set; }
        #endregion

        #region GrandTotal
        [JsonIgnore]
        [ForExport("PCS Estimations", "Estimated Reimbursements by Topic", "Reimbursement Amount", "House Hunting Trip :")]
        public decimal Exp_HouseHuntingTotal => HouseHuntingTotal;
        [JsonIgnore]
        [ForExport("PCS Estimations", "Estimated Reimbursements by Topic", "Reimbursement Amount", "Tranportation :")]
        public decimal Exp_TransportationSubTotal => TransportationSubTotal;
        [JsonIgnore]
        [ForExport("PCS Estimations", "Estimated Reimbursements by Topic", "Reimbursement Amount", "Temporary Quarters Subsistence Expense :")]
        public decimal Exp_TQSETotal => TQSETotal;
        [JsonIgnore]
        [ForExport("PCS Estimations", "Estimated Reimbursements by Topic", "Reimbursement Amount", "Goods / Home Transportation :")]
        public decimal Exp_GHTransportationTotal => GHTransportationTotal;
        [JsonIgnore]
        [ForExport("PCS Estimations", "Estimated Reimbursements by Topic", "Reimbursement Amount", "Miscellaneous Expenses :")]
        public decimal Exp_MEASubtotal => MEASubtotal;
        [JsonIgnore]
        [ForExport("PCS Estimations", "Estimated Reimbursements by Topic", "Reimbursement Amount", "Real Estate / UEL :")]
        public decimal Exp_RealEstateLeaseTotal => RealEstateLeaseTotal;
        [JsonIgnore]
        [ForExport("PCS Estimations", "Estimated Reimbursements by Topic", "Reimbursement Amount", "Non-Temporary Storage :")]
        public decimal Exp_NTSSubtotal => NTSSubtotal;
        [JsonIgnore]
        [ForExport("PCS Estimations", "Estimated Reimbursements by Topic", "Reimbursement Amount", "Relocation Income Allowance :")]
        public decimal Exp_RITASubtotal => RITASubtotal;
        /// <summary>
        /// Grand Total of all reimbursable expenses
        /// </summary>
        [ForExport("PCS Estimations", "Estimated Reimbursements by Topic", "Reimbursement Amount", "Grand Total :")]
        public decimal GrandTotal { get; set; }
        #endregion


    }
}

