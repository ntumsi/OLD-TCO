namespace AMCOS.Data.Entities
{
    public class QuickSightDashboard
    {
        public string DashboardTitle { get; set; }
        public string QuickSightNamespace { get; set; }
        public string InitialDashboardId { get; set; }
        public string AuthorizedResourceArns { get; set; }
        public string AllowedDomains { get; set; }
    }
}
