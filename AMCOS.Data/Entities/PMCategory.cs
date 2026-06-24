namespace AMCOS.DataAccess.Entities
{
    using System.ComponentModel.DataAnnotations;
    using System.ComponentModel.DataAnnotations.Schema;
    using Microsoft.EntityFrameworkCore;

    [PrimaryKey(nameof(UserId), nameof(ProjectId), nameof(CategoryId))]
    [Table("webuser.PMCategory")]
    public partial class PMCategory
    {
        [Column(Order = 0)]
        [StringLength(50)]
        public string UserId { get; set; }

        [Column(Order = 1)]
        [DatabaseGenerated(DatabaseGeneratedOption.None)]
        public int ProjectId { get; set; }

        [Column(Order = 2)]
        public int CategoryId { get; set; }

        [StringLength(50)]
        public string CategoryName { get; set; }
    }
}
