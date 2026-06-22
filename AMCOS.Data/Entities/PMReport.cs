namespace AMCOS.DataAccess.Entities
{
    using System.ComponentModel.DataAnnotations;
    using System.ComponentModel.DataAnnotations.Schema;

    [Table("webuser.PMReport")]
    public partial class PMReport
    {
        public int Id { get; set; }

        [Required]
        [StringLength(50)]
        public string UserId { get; set; }

        public int ProjectId { get; set; }

        public int CategoryId { get; set; }

        [Required]
        [StringLength(3)]
        public string PayPlan { get; set; }

        [Required]
        [StringLength(100)]
        public string SummaryName { get; set; }
    }
}
