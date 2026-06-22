namespace AMCOS.DataAccess.Entities
{
    using System;
    using System.ComponentModel.DataAnnotations;
    using System.ComponentModel.DataAnnotations.Schema;

    [Table("webuser.PMProject")]
    public partial class PMProject
    {
        [Key]
        [Column(Order = 0)]
        [StringLength(50)]
        public string UserId { get; set; }

        [Key]
        [Column(Order = 1)]
        public int ProjectId { get; set; }

        [Required]
        [StringLength(50)]
        public string ProjectName { get; set; }

        public int YearStart { get; set; }

        public int YearDuration { get; set; }

        [StringLength(50)]
        public string ProjectCreator { get; set; }

        [Required]
        [StringLength(50)]
        public string ProjectType { get; set; }

        public int ReserveDaysInactive { get; set; }

        public int ReserveDaysActive { get; set; }

        public DateTime CreateDate { get; set; }

        public DateTime LastUpdate { get; set; }

        [Column(TypeName = "text")]
        public string Description { get; set; }

        public double? DiscountRate { get; set; }
    }
}
