namespace AMCOS.Data.Entities
{
    using System.ComponentModel.DataAnnotations;
    using System.ComponentModel.DataAnnotations.Schema;

    [Table("lookup.GS_OccupationalGroup")]
    public class GSOccupationalGroup
    {
        [Key]
        [StringLength(4)]
        public string OccupationalGroupNumber { get; set; }

        [StringLength(250)]
        public string GroupTitle { get; set; }
    }
}
