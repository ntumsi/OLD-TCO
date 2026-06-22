using AMCOS.Logic.Models;

namespace AMCOS.Logic.ViewModels
{
    public class CivPcsGoodsHomeTransportation : IModel, ICivPcsGoodsHomeTransportation
    {
        public CivPcsGoodsHomeTransportation(int amcosVersion)
        {
            HHGTransportationModel = new CivPcsHhgViewModel(amcosVersion);
            HomeTranportationModel = new CivPcsMobileHomeViewModel(amcosVersion);
        }
        public string Title => "Goods / Home Transportation";
        public string View => "_GHTransportation";
        public string TransportationType { get; set; } = "Goods";
        public decimal GHTransportationTotal { get; set; } = 0;
        public ICivPcsHhg HHGTransportationModel { get; }
        public ICivPcsMobileHome HomeTranportationModel { get; }
    }
    public interface ICivPcsGoodsHomeTransportation
    {
        string TransportationType { get; set; }
        decimal GHTransportationTotal { get; set; }
        ICivPcsHhg HHGTransportationModel { get; }
        ICivPcsMobileHome HomeTranportationModel { get; }
    }
}
