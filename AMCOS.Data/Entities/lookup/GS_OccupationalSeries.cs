namespace AMCOS.Data.Entities
{
    using System.ComponentModel.DataAnnotations;
    using System.ComponentModel.DataAnnotations.Schema;

    [Table("lookup.GS_OccupationalSeries")]
    public class GSOccupationalSeries
    {
        [Key]
        [StringLength(4)]
        public string OccupationalSeriesNumber { get; set; }

        [Required]
        [StringLength(250)]
        public string SeriesTitle { get; set; }
    }
}
