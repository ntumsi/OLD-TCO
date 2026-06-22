using System.Collections.Generic;

namespace AMCOS.Logic.Models
{
    public interface IPcsModel : IModel
    {
        /// <summary>
        /// List of partial models to be displayed inside the PCS content window and sidebar menu
        /// </summary>
        List<IModel> Content { get; }
        /// <summary>
        /// Displays a modal for opening a project
        /// </summary>
        IOpenProjectModel OpenProjectModal { get; }
        /// <summary>
        /// Displays a save as modal dialog
        /// </summary>
        ISaveAsModel SaveAsModal { get; }
        /// <summary>
        /// Controller associated with this view
        /// </summary>
        string Controller { get; }

    }
   
}
