using AMCOS.Logic.Models;

namespace AMCOS.Logic.ViewModels
{
    public class CivPcsRitaViewModel : IModel, ICivPcsRita
    {
        public CivPcsRitaViewModel(int amcosVersion)
        {
            DefaultFederalTaxRate = SingleValue.Get("AA", "PCS_CivDefaultTax", amcosVersion);
            FederalTaxRate = DefaultFederalTaxRate;          
        }
        /// <summary>
        /// Title of this content panel
        /// </summary>
        public string Title => "Relocation Income Tax Allowance (RITA)";
        /// <summary>
        /// View associated with this model
        /// </summary>
        public string View => "_RITA";
        /// <summary>
        /// Assumed Tax Rate for federal, social security and medicare
        /// </summary>
        public decimal DefaultFederalTaxRate { get; set; }
        /// <summary>
        /// TaxBracket used for calculating RITA values
        /// </summary>
        public decimal FederalTaxRate { get; set; }
        /// <summary>
        /// Medicare Tax Rate
        /// </summary>
        public decimal MedicareTaxRate { get; set; }
        /// <summary>
        /// Social Security Tax Rate
        /// </summary>
        public decimal SocialSecurityTaxRate { get; set; }
        /// <summary>
        /// State income tax value used for calculating RITA
        /// </summary>
        public decimal StateTaxRate { get; set; }
        /// <summary>
        /// Estimated County Tax Rate
        /// </summary>
        public decimal CountyTaxRate { get; set; }
        /// <summary>
        /// Estimated City Tax Rate
        /// </summary>
        public decimal CityTaxRate { get; set; }
        /// <summary>
        /// Total of Federal Income Tax, Medicare, Social Security, State, County, and City Tax Rates
        /// </summary>
        public decimal TotalTaxRate { get; set; }
        /// <summary>
        /// Subtotal of Relocation Income Tax Allowance
        /// </summary>
        public decimal RITASubtotal { get; set; } = 0;
        /// <summary>
        /// House Hunting Total RITA value
        /// </summary>
        public decimal HouseHuntingRITA { get; set; }
        /// <summary>
        /// Transportation RITA value
        /// </summary>
        public decimal TransportationRITA { get; set; }
        /// <summary>
        /// TQSE RITA value
        /// </summary>
        public decimal TQSERITA { get; set; }
        /// <summary>
        /// Goods / Home Transportation RITA value
        /// </summary>
        public decimal GHTransportationRITA { get; set; }
        /// <summary>
        /// Miscellaneous Expense Allowance RITA value
        /// </summary>
        public decimal MEARITA { get; set; }
        /// <summary>
        /// Real Estate RITA value
        /// </summary>
        public decimal RealEstateLeaseRITA { get; set; }
        /// <summary>
        /// Non Temporary Storage RITA
        /// </summary>
        public decimal NTSRITA { get; set; }

    }
    public interface ICivPcsRita
    {
        /// <summary>
        /// Assumed Tax Rate for federal, social security and medicare
        /// </summary>
        decimal DefaultFederalTaxRate { get; set; }
        /// <summary>
        /// TaxBracket used for calculating Federal Tax values
        /// </summary>
        decimal FederalTaxRate { get; set; }
        /// <summary>
        /// Medicare Tax Rate
        /// </summary>
        decimal MedicareTaxRate { get; set; }
        /// <summary>
        /// Social Security Tax Rate
        /// </summary>
        decimal SocialSecurityTaxRate { get; set; }
        /// <summary>
        /// State income tax value used for calculating RITA
        /// </summary>
        decimal StateTaxRate { get; set; }
        /// <summary>
        /// Estimated County Tax Rate
        /// </summary>
        decimal CountyTaxRate { get; set; }
        /// <summary>
        /// Estimated City Tax Rate
        /// </summary>
        decimal CityTaxRate { get; set; }
        /// <summary>
        /// Total of Federal Income Tax, Medicare, Social Security, State, County, and City Tax Rates
        /// </summary>
        decimal TotalTaxRate { get; set; }
        /// <summary>
        /// Subtotal of Relocation Income Tax Allowance
        /// </summary>
        decimal RITASubtotal { get; set; }
        /// <summary>
        /// House Hunting RITA value
        /// </summary>
        decimal HouseHuntingRITA { get; set; }
        /// <summary>
        /// Transportation RITA value
        /// </summary>
        decimal TransportationRITA { get; set; }
        /// <summary>
        /// TQSE RITA value
        /// </summary>
        decimal TQSERITA { get; set; }
        /// <summary>
        /// Goods / Home Transportation RITA value
        /// </summary>
        decimal GHTransportationRITA { get; set; }
        /// <summary>
        /// Miscellaneous Expense Allowance RITA value
        /// </summary>
        decimal MEARITA { get; set; }
        /// <summary>
        /// Real Estate RITA value
        /// </summary>
        decimal RealEstateLeaseRITA { get; set; }
        /// <summary>
        /// Non Temporary Storage RITA
        /// </summary>
        decimal NTSRITA { get; set; }
    }
}
