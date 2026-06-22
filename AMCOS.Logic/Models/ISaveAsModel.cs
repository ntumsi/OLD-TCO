using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace AMCOS.Logic.Models
{
    public interface ISaveAsModel
    {
        /// <summary>
        /// Title of the modal displayed to user
        /// </summary>
        string Title { get; }
        /// <summary>
        /// Name of the project user wishes to save
        /// </summary>
        string SaveAs { get; set; }
        /// <summary>
        /// Name of controller to execute commands against
        /// </summary>
        string Controller { get; }        
        /// <summary>
        /// Name of action
        /// </summary>
        string SaveAction { get; }
        /// <summary>
        /// Unique identifier for this modal
        /// </summary>
        Guid ID { get; }
        /// <summary>
        /// List of Existing Projects to save over
        /// </summary>
        List<Tuple<string, DateTime>> Values { get; }
    }
}
