using AMCOS.Data.Entities;
using AMCOS.Logic.ViewModels;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace AMCOS.Logic.Helpers
{
    public static class Extensions
    {
        public static PCSProject ConvertToPCSProject(this CivPcsJson pcsJson)
        {
            var newValue = new PCSProject();
            var newType = newValue.GetType();
            var oldType = pcsJson.GetType();
            newType.GetProperties().ToList().ForEach(p =>
            {
                var oldTypeProperty = oldType.GetProperty(p.Name);
                if (oldTypeProperty != null)
                {
                    p.SetValue(newValue, oldTypeProperty.GetValue(pcsJson));
                }
            });
            return newValue;
        }
        public static CivPcsJson ConvertToCivPCSjson(this PCSProject pcsProject)
        {
            var newValue = new CivPcsJson();
            var newType = newValue.GetType();
            pcsProject.GetType().GetProperties().ToList().ForEach(p => newType.GetProperty(p.Name)?.SetValue(newValue, p.GetValue(pcsProject)));
            return newValue;
        }
    }
}
