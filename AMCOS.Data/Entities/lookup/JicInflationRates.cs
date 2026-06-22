using System;

namespace AMCOS.Data.Entities
{
    public class JicInflationRates
    {
        public string ConversionType { get; set; }
        public Int16 Year { get; set; }
        public string Appropriation { get; set; }        
        public decimal Amount { get; set; }
        public int AmcosVersionId { get; set; }
    }
}

