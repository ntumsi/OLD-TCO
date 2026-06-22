using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace AMCOS.Logic.Models
{
    public interface IModel
    {
        /// <summary>
        /// Title of model for display inside title banner
        /// </summary>
        string Title { get; }
        ///// <summary>
        ///// Controller for post backs
        ///// </summary>
        //string Controller { get; }
        /// <summary>
        /// View associated with the model implementation
        /// </summary>
        string View { get; }
    }
}
