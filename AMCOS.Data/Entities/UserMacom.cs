namespace AMCOS.DataAccess.Entities
{
    using System.ComponentModel.DataAnnotations;
    using System.ComponentModel.DataAnnotations.Schema;
    using Microsoft.EntityFrameworkCore;

    [PrimaryKey(nameof(MACOM), nameof(MACOM_Name), nameof(Description))]
    [Table("User_Macom", Schema = "webuser")]
    public partial class UserMACOM
    {
        [Column(Order = 0)]
        [StringLength(2)]
        public string MACOM { get; set; }

        [Column(Order = 1)]
        [StringLength(20)]
        public string MACOM_Name { get; set; }

        [Column(Order = 2)]
        [StringLength(50)]
        public string Description { get; set; }
    }
}
