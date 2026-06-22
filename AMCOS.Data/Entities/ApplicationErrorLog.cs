using System;
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace AMCOS.Data.Entities
{
    [Table("web.ApplicationErrorLog")]
    public class ApplicationErrorLog
    {
        [Key]
        [Column(Order = 0)]
        public int ErrorId { get; set; }
        public DateTime ErrorTime { get; set; }
        [StringLength(50)]
        public string UserId { get; set; }
        [StringLength(200)]
        public string ErrorPage { get; set; }
        [StringLength(7000)]
        public string ErrorDetail { get; set; }
    }
}