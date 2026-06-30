namespace AMCOS.DataAccess.Entities
{
    using System.ComponentModel.DataAnnotations;
    using System.ComponentModel.DataAnnotations.Schema;

    [Table("User_Summaries", Schema = "webuser")]
    public partial class UserSummaries
    {
        [Key]
        public int SummaryId { get; set; }

        [Required]
        [StringLength(50)]
        public string UserId { get; set; }

        public int ProjectId { get; set; }

        [Required]
        [StringLength(3)]
        public string PayPlan { get; set; }

        [StringLength(50)]
        public string Type { get; set; }

        [Required]
        [StringLength(50)]
        public string SummaryName { get; set; }

        public int InReport { get; set; }
    }
}
