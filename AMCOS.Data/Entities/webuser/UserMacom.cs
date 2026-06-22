namespace AMCOS.Data.Entities
{
    using System.ComponentModel.DataAnnotations;
    using System.ComponentModel.DataAnnotations.Schema;

    [Table("webuser.User_Macom")]
    public class UserMACOM
    {
        [Key]
        [Column(Order = 0)]
        [StringLength(2)]
        public string MACOM { get; set; }

        [Key]
        [Column(Order = 1)]
        [StringLength(20)]
        public string MACOM_Name { get; set; }

        [Key]
        [Column(Order = 2)]
        [StringLength(50)]
        public string Description { get; set; }
    }
}
