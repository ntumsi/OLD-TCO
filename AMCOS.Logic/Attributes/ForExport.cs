using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace AMCOS.Logic.Attributes
{
    public class ForExport : Attribute
    {
        public string Section { get; }
        public string Label { get; }
        public string TableHeader { get; }
        public string ColumnHeader { get; }
        public string RowHeader { get; }
        public ForExport(string section, string tableHeader, string columnHeader, string rowHeader)
        {
            Section = section;
            TableHeader = tableHeader;
            ColumnHeader = columnHeader;
            RowHeader = rowHeader;
        }
        public ForExport(string section, string label)
        {
            Section = section;
            Label = label;
        }
    }
}
