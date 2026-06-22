namespace AMCOS.DataAccess.Entities
{
    using System.ComponentModel.DataAnnotations;
    using System.ComponentModel.DataAnnotations.Schema;

    [Table("webuser.PMCategory")]
    public partial class PMCategory
    {
        [Key]
        [Column(Order = 0)]
        [StringLength(50)]
        public string UserId { get; set; }

        [Key]
        [Column(Order = 1)]
        [DatabaseGenerated(DatabaseGeneratedOption.None)]
        public int ProjectId { get; set; }

        [Key]
        [Column(Order = 2)]
        public int CategoryId { get; set; }

        [StringLength(50)]
        public string CategoryName { get; set; }
    }
}
