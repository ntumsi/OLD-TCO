namespace AMCOS.Data.Entities
{
    using System.ComponentModel.DataAnnotations;
    using System.ComponentModel.DataAnnotations.Schema;
    using Microsoft.EntityFrameworkCore;

    [PrimaryKey(nameof(PayPlan), nameof(GradeType), nameof(GradeLevel))]
    [Table("Grade", Schema = "lookup")]
    public class Grade
    {
        [Column(Order = 0)]
        [StringLength(3)]
        public string PayPlan { get; set; }

        [Column(Order = 1)]
        [StringLength(50)]
        public string GradeType { get; set; }

        [Column(Order = 2)]
        [StringLength(2)]
        public string GradeLevel { get; set; }
    }
}
