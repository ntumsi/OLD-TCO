namespace AMCOS.DataAccess.Entities
{
    using System.ComponentModel.DataAnnotations;
    using System.ComponentModel.DataAnnotations.Schema;

    [Table("webuser.PMCategorySkillInventory")]
    public partial class PMCategorySkillInventory
    {
        public int Id { get; set; }

        [Required]
        [StringLength(50)]
        public string UserId { get; set; }

        public int ProjectId { get; set; }

        public int CategoryId { get; set; }

        public int SkillId { get; set; }

        public int Year { get; set; }

        public int Amount { get; set; }
    }
}
