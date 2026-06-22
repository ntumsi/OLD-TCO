using AMCOS.Logic.Models;

namespace AMCOS.Logic.ViewModels
{
    public class CivPcsTqseViewModel : IModel, ICivPcsTqse
    {
        public CivPcsTqseViewModel(int amcosVersion)
        {
            TQSEPerDiemRate = SingleValue.Get("AA", "PCS_TQSEPerDiem_Rate", amcosVersion);
            TQSESpousePerDiemRate = SingleValue.Get("AA", "PCS_TQSESpousePerDiem_Rate", amcosVersion);
        }
        /// <summary>
        /// Title of the PCS page
        /// </summary>
        public string Title => "Temporary Quarters Subsistence Expense";
        /// <summary>
        /// View associated with this model
        /// </summary>
        public string View => "_TQSE";
        /// <summary>
        /// Total number of whole days for TQSE
        /// </summary>
        public int NumberDaysTQSE { get; set; } = 10;
        /// <summary>
        /// Whether or not the client has a spouse
        /// </summary>
        public int TQSEDependents { get; set; } = 0;
        /// <summary>
        /// Calculation for TQSE Per Diem Lodging
        /// </summary>
        public decimal TQSESelfPerDiemLodging { get; set; }
        /// <summary>
        /// Calculation for TQSE Spouse Per Diem Lodging
        /// </summary>
        public decimal TQSESpousePerDiemLodging { get; set; }
        /// <summary>
        /// Calculation for TQSE Per diem MI&E
        /// </summary>
        public decimal TQSESelfPerDiemMIE { get; set; }
        /// <summary>
        /// Calculation for TQSE Spouse Per Diem MI&E
        /// </summary>
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
        public decimal TQSETotal { get; set; }

    }
    public interface ICivPcsTqse
    {
        /// <summary>
        /// Total number of whole days for TQSE
        /// </summary>
        int NumberDaysTQSE { get; set; }
        /// <summary>
        /// Whether or not the client has a spouse
        /// </summary>
        int TQSEDependents { get; set; }
        /// <summary>
        /// Calculation for TQSE Per Diem Lodging
        /// </summary>
        decimal TQSESelfPerDiemLodging { get; set; }
        /// <summary>
        /// Calculation for TQSE Spouse Per Diem Lodging
        /// </summary>
        decimal TQSESpousePerDiemLodging { get; set; }
        /// <summary>
        /// Calculation for TQSE Per diem MI&E
        /// </summary>
        decimal TQSESelfPerDiemMIE { get; set; }
        /// <summary>
        /// Calculation for TQSE Spouse Per Diem MI&E
        /// </summary>
        decimal TQSESpousePerDiemMIE { get; set; }
        /// <summary>
        /// TQSE Self Per Diem Rate
        /// </summary>
        decimal TQSEPerDiemRate { get; set; }
        /// <summary>
        /// TQSE Spouse PerDiem Rate
        /// </summary>
        decimal TQSESpousePerDiemRate { get; set; }
        /// <summary>
        /// Total of TQSE Reimbursement
        /// </summary>
        decimal TQSETotal { get; set; }
    }
}
