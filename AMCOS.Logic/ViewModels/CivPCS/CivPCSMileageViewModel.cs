using AMCOS.Logic.Models;
using System;
using System.Collections.Generic;
using AMCOS.Logic.Helpers;
using System.Web.Mvc;

namespace AMCOS.Logic.ViewModels
{
    public class CivPcsMileageViewModel : IModel, ICivPcsMileage
    {
        /// <summary>
        /// Constructor
        /// </summary>
        /// <param name="amcosVersionList"></param>
        public CivPcsMileageViewModel(int amcosVersionId)
        {
            AmcosVersionId = amcosVersionId;
            YearList = PcsPropertyHelper.GetJicInflationRateYears(ConversionType, Appropriation, amcosVersionId);
            Year = Convert.ToInt16(AmcosVersionId.ToString().Substring(0, 4));
            JicInflationRate = PcsPropertyHelper.GetJicInflationRate(ConversionType, Appropriation, Year, amcosVersionId);
            AppropriationList = PcsPropertyHelper.GetCivPCSAppropriationList();
        }
        /// <summary>
        /// Title of the Content Panel
        /// </summary>
        public string Title => "Source/Destination & Distance Estimator";
        /// <summary>
        /// View associated with this model
        /// </summary>
        public string View => "_Mileage";
        /// <summary>
        /// Origination location id
        /// </summary>
        public int OriginationId { get; set; }
        /// <summary>
        /// Destination location id
        /// </summary>
        public int DestinationId { get; set; }        
        /// <summary>
        /// Appropriation value used in determining JIC inflation / deflation value
        /// </summary>
        public string Appropriation { get; set; } = "OMA";
        /// <summary>
        /// List of available appropriation selection items
        /// </summary>
        public IEnumerable<SelectListItem> AppropriationList { get; set; }
        /// <summary>
        /// Conversion Type from the JIC inflation deflation table
        /// </summary>
        public string ConversionType { get; set; } = "ThenToThen";
        /// <summary>
        /// Fiscal Year from the JIC Inflation deflation table
        /// </summary>
        public short Year { get; set; }
        /// <summary>
        /// Inflationrate based on selected Appropration, ConverstionType and Year
        /// </summary>
        public decimal JicInflationRate { get; set; }
        /// <summary>
        /// Amcos Version Id from the JIC inflation deflation table
        /// </summary>
        public int AmcosVersionId { get; set; }
        /// <summary>
        /// List of available Amcos versions
        /// </summary>
        public IEnumerable<SelectListItem> YearList { get; }
        /// <summary>
        /// Calculated distance between origination and destination
        /// </summary>
        public int CalculatedDistance { get; set; } = 0;
    }
    public interface ICivPcsMileage
    {
        /// <summary>
        /// Origination location id
        /// </summary>
        int OriginationId { get; set; }
        /// <summary>
        /// Destination location id
        /// </summary>
        int DestinationId { get; set; }
        /// <summary>
        /// Appropriation value used in determining JIC inflation / deflation value
        /// </summary>
        string Appropriation { get; set; }
        /// <summary>
        /// Conversion Type from the JIC inflation deflation table
        /// </summary>
        string ConversionType { get; set; }
        /// <summary>
        /// Fiscal Year from the JIC Inflation deflation table
        /// </summary>
        short Year { get; set; }
        /// <summary>
        /// Inflationrate based on selected Appropration, ConverstionType and Year
        /// </summary>
        decimal JicInflationRate { get; set; }
        /// <summary>
        /// Amcos Version Id from the JIC inflation deflation table
        /// </summary>
        int AmcosVersionId { get; set; }
        /// <summary>
        /// Calculated distance between origination and destination
        /// </summary>
        int CalculatedDistance { get; set; }
    }
}
