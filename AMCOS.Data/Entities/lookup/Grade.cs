namespace AMCOS.Data.Entities
{
    using System.ComponentModel.DataAnnotations;
    using System.ComponentModel.DataAnnotations.Schema;

    [Table("lookup.Grade")]
    public class Grade
    {
        [Key]
        [Column(Order = 0)]
        [StringLength(3)]
        public string PayPlan { get; set; }

        [Key]
        [Column(Order = 1)]
        [StringLength(50)]
        public string GradeType { get; set; }

        [Key]
        [Column(Order = 2)]
        [StringLength(2)]
        public string GradeLevel { get; set; }
    }
}
