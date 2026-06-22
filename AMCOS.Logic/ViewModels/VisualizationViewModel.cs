using AMCOS.Data.Entities;
using AMCOS.Logic.Models;

namespace AMCOS.Logic.ViewModels
{
    public class VisualizationViewModel : BaseViewModel, IModel
    {
        public VisualizationViewModel(AMCOSUser user, string url, string title, string view) : base(user)
        {
            Url = url;
            Title = title;
            View = view;
        }
        public string Url { get; set; }
        public string Title { get; set; }
        public string View { get; set; }
    }
}
