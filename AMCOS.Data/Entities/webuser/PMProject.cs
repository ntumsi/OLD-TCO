namespace AMCOS.Data.Entities
{
    using System;

    public class PMProject
    {
        public int ProjectId { get; set; }
        public string UserId { get; set; }
        public string ProjectName { get; set; }
        public int YearStart { get; set; }
        public int YearDuration { get; set; }
        public string ProjectCreator { get; set; }
        public string ProjectType { get; set; }
        public int ReserveDaysInactive { get; set; }
        public int ReserveDaysActive { get; set; }
        public DateTime CreateDate { get; set; }
        public DateTime LastUpdate { get; set; }
        public string Description { get; set; }
        public double? DiscountRate { get; set; }
    }
}
