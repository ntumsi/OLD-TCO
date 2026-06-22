using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace AMCOS.Logic.Attributes
{
    public class ExportIf : Attribute
    {
        private string _propertyName;
        private string _expectedValue;
        public ExportIf(string propertyName, string expectedValue)
        {
            _propertyName = propertyName;
            _expectedValue = expectedValue;
        }
        /// <summary>
        /// Tests whether the property of the passed in object is for export
        /// </summary>
        /// <param name="value"></param>
        /// <returns></returns>
        public bool IsForExport(object value)
        {
            return value.GetType().GetProperty(_propertyName).GetValue(value)?.ToString() == _expectedValue;
        }
    }
}
