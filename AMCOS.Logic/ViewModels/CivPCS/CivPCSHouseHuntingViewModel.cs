using AMCOS.Data.Entities;
using AMCOS.Logic.Models;
using System.ComponentModel.DataAnnotations;

namespace AMCOS.Logic.ViewModels
{
    public class CivPcsHouseHuntingViewModel : IModel, ICivPcsHouseHunting
    {
        /// <summary>
        /// Default constructor
        /// </summary>
        public CivPcsHouseHuntingViewModel(int amcosVersion) : this(amcosVersion, null, (int)SingleValue.Get("AA", "PCS_DefaultHouseHuntingDays", amcosVersion), true)
        {
            
        }
        public CivPcsHouseHuntingViewModel(int amcosVersion, CivLocationPerDiem perdiem, int totalDays, bool haveSpouse)
        {
            SpousePerDiemRate = SingleValue.Get("AA", "PCS_SpousePerDiem_Rate", amcosVersion);

            SelfLodgingPerDiem = perdiem != null && perdiem.MaxLodgingRate.HasValue ? perdiem.MaxLodgingRate.Value : 0;
            SelfMIEPerDiem = perdiem != null && perdiem.MIERate.HasValue ? perdiem.MIERate.Value : 0;
            SpouseLodgingPerDiem = haveSpouse && perdiem != null && perdiem.MaxLodgingRate.HasValue ? perdiem.MaxLodgingRate.Value * SpousePerDiemRate : 0;
            SpouseMIEPerDiem = haveSpouse && perdiem != null && perdiem.MIERate.HasValue ? perdiem.MIERate.Value * SpousePerDiemRate : 0;

            NumberOfDaysHunting = totalDays;
            HouseHuntingHaveSpouse = haveSpouse;
            HouseHuntingTotal = (SelfLodgingPerDiem + SelfMIEPerDiem + SpouseLodgingPerDiem + SpouseMIEPerDiem) * totalDays;
        }
        public string Title => "House Hunting Trip";
        public string Controller => "CivPCS";
        public string View => "_HouseHunting";
        [Range(1, 60)]
        public int NumberOfDaysHunting { get; set; }
        public bool HouseHuntingHaveSpouse { get; set; }
        public decimal SelfLodgingPerDiem { get; set; }
        public decimal SpouseLodgingPerDiem { get; set; }
        public decimal SelfMIEPerDiem { get; set; }
        public decimal SpouseMIEPerDiem { get; set; }
        public decimal HouseHuntingTotal { get; set; }
        public decimal SpousePerDiemRate { get; set; }
    }
    public interface ICivPcsHouseHunting
    {
        int NumberOfDaysHunting { get; set; }
        bool HouseHuntingHaveSpouse { get; set; }
        decimal SelfLodgingPerDiem { get; set; }
        decimal SpouseLodgingPerDiem { get; set; }
        decimal SelfMIEPerDiem { get; set; }
        decimal SpouseMIEPerDiem { get; set; }
        decimal HouseHuntingTotal { get; set; }
        decimal SpousePerDiemRate { get; set; }
    }
}
