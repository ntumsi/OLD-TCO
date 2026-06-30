namespace AMCOS.Data.Entities
{
    using System.ComponentModel.DataAnnotations;
    using System.ComponentModel.DataAnnotations.Schema;
    using Microsoft.EntityFrameworkCore;

    [PrimaryKey(nameof(JobSeries), nameof(StateCountry), nameof(FunctionalArea), nameof(CostCenter), nameof(GradeLevel))]
    [Table("GP_Inventory", Schema = "data")]
    public class GPInventory
    {
        [Column(Order = 0)]
        [StringLength(5)]
        public string JobSeries { get; set; }

        [Column(Order = 1)]
        [StringLength(50)]
        public string StateCountry { get; set; }

        [Column(Order = 2)]
        [StringLength(50)]
        public string FunctionalArea { get; set; }

        [Column(Order = 3)]
        [StringLength(50)]
        public string CostCenter { get; set; }

        [Column(Order = 4)]
        public byte GradeLevel { get; set; }

        public byte? Step { get; set; }

        public int? PersonCount { get; set; }
    }
}
