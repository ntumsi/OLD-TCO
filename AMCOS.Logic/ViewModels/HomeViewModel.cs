using AMCOS.Data.Entities;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using System.Web.Mvc;
using System.IO;

namespace AMCOS.Logic.ViewModels
{
    public class HomeViewModel : BaseViewModel
    {
        public HomeViewModel(AMCOSUser user, string imgPath) : base(user)
        {
            ImageUrl = imgPath;
        }
        public string ImageUrl { get; set; }
    }
}
