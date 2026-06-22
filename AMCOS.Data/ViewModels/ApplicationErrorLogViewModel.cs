using System;
using System.Collections.Generic;
using System.Linq;
using System.Web;

namespace AMCOS.Data.ViewModels
{
    public class ApplicationErrorLogViewModel
    {
        public DateTime ErrorTime { get; set; }
        public string UserId { get; set; }
        public string ErrorPage { get; set; }
        public string ErrorDetail { get; set; }

    }
}