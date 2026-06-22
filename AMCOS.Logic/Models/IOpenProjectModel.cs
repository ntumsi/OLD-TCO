using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace AMCOS.Logic.Models
{
    public interface IOpenProjectModel
    {
        /// <summary>
        /// Title of the modal displayed to user
        /// </summary>
        string Title { get; }
        /// <summary>
        /// Selectable list of values
        /// </summary>
        List<Tuple<string, DateTime>> Values { get; }
        /// <summary>
        /// Selected value from list of values
        /// </summary>
        string SelectedValue { get; set; }
        /// <summary>
        /// Controller to execute action against
        /// </summary>
        string Controller { get; }
        /// <summary>
        /// Action to submit SelectedValue to
        /// </summary>
        string SelectedAction { get; }
        /// <summary>
        /// ID 
        /// </summary>
        Guid ID { get; }
    }
}
