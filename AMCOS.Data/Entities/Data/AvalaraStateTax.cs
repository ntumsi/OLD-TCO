using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace AMCOS.Data.Entities
{
    public class AvalaraStateTax
    {
        public string State { get; set; }
        public string ZipCode { get; set; }
        public string TaxRegionName { get; set; }
        public decimal StateRate { get; set; }
        public decimal EstimatedCombinedRate { get; set; }
        public decimal EstimatedCountyRate { get; set; }
        public decimal EstimatedCityRate { get; set; }
        public decimal EstimatedSpecialRate { get; set; }
        public int RiskLevel { get; set; } 
        public int AmcosVersionIdStart { get; set; }
        public int AmcosVersionIdEnd { get; set; }
    }
}
