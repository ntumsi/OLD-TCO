using AMCOS.Data.Entities;
using AMCOS.Logic.Helpers;
using AMCOS.Logic.Models;
using System;
using System.Collections.Generic;

namespace AMCOS.Logic.ViewModels
{
    public class CivPcsViewModel : BaseViewModel, IPcsModel
    {
        //IEnumerable<SelectListItem> _amcosVersions = PCSPropertyHelper.GetMaxReleaseVersionPerYear(2020);
        public CivPcsViewModel(List<Tuple<string, DateTime>> existingProjects, AMCOSUser user) : base(user)
        {
            OpenProjectModal = new OpenProjectDialog(existingProjects);
            SaveAsModal = new SaveAsDialog(existingProjects);
            var amcosVersion = Convert.ToInt32(PcsPropertyHelper.GetMaxReleaseVersion());
            
            Content = new List<IModel>()
            {
                new CivPcsMileageViewModel(amcosVersion),
                new CivPcsHouseHuntingViewModel(amcosVersion),
                new CivPcsTransportationViewModel(amcosVersion),
                new CivPcsTqseViewModel(amcosVersion),
                new CivPcsGoodsHomeTransportation(amcosVersion),
                new CivPcsMeaViewModel(amcosVersion),
                new CivPcsRealEstateLease(),
                new CivPcsNtsViewModel(),
                new CivPcsRitaViewModel(amcosVersion),
                new CivPcsGrandTotalViewModel(),
            };
        }
        /// <summary>
        /// List of partial models to be displayed inside the PCS content window and sidebar menu
        /// </summary>
        public List<IModel> Content { get; } 
        /// <summary>
        /// Title of this viewModel to display title banner
        /// </summary>
        public string Title => "Civilian Permanent Change of Station (PCS)";
        /// <summary>
        /// Controller for post backs
        /// </summary>
        public string Controller => "CivPCS";
        /// <summary>
        /// View associated with this model
        /// </summary>
        public string View => "Index";

        public IOpenProjectModel OpenProjectModal { get; }

        public ISaveAsModel SaveAsModal { get; }
        private class OpenProjectDialog : IOpenProjectModel
        {
            public OpenProjectDialog(List<Tuple<string, DateTime>> values)
            {
                Values = values;
            }
            public string Title => "Select a project to open";

            public List<Tuple<string, DateTime>> Values { get; } 

            public string SelectedValue { get; set; }

            public string Controller => "CivPCS";

            public string SelectedAction => "OpenProject";
            public Guid ID { get; } = Guid.NewGuid();
        }
        private class SaveAsDialog : ISaveAsModel
        {
            public SaveAsDialog(List<Tuple<string, DateTime>> values)
            {
                Values = values;
            }

            public List<Tuple<string, DateTime>> Values { get; }
            public string Title => "Choose a project or enter a new project name to save.";

            public string SaveAs { get; set; }

            public string Controller => "CivPCS";

            public string SaveAction => "SaveProject";
            public Guid ID { get; } = Guid.NewGuid();
        }
    }
}
