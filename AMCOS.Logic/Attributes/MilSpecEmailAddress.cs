using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using System.Configuration;
using System.Linq;
using System.Text.RegularExpressions;

namespace AMCOS.Logic.Attributes
{
    public class MilSpecEmailAddress : ValidationAttribute
    {
        private List<string> _validEmailSuffix => new Lazy<List<string>>(() => UserAdministration.GetValidEmailSuffixList()).Value;
        Regex _regex = new Regex(@"^(([\w-]+\.)+[\w-]+|([a-zA-Z]{1}|[\w-]{2,}))@((([0-1]?[0-9]{1,2}|25[0-5]|2[0-4][0-9])\.([0-1]?[0-9]{1,2}|25[0-5]|2[0-4][0-9])\.([0-1]?[0-9]{1,2}|25[0-5]|2[0-4][0-9])\.([0-1][0-9]{1,2}|25[0-5]|2[0-4][0-9])){1}|([a-zA-Z]+[\w-]+\.)+[a-zA-Z]{2,4})$");
        protected override ValidationResult IsValid(object value, ValidationContext validationContext)
        {
            if (!string.IsNullOrWhiteSpace(value?.ToString()) && _regex.Match(value.ToString()).Length > 0 && ContainsValidEmailSuffix(value.ToString()))
                return ValidationResult.Success;
            else
                return new ValidationResult($"Your email is not valid or its domain is not in the acceptable list ({ string.Join(", ", _validEmailSuffix) }).  If you would like to add it, please click <a href='https://www.aesmp.army.mil/csm?id=sc_cat_item&sys_id=faac2dbe9775d69440c7b8021153afee' target='_blank'>here</a> to contact the help desk. For more information on how to submit a request, please click <a href='https://www.cave.army.mil/AMCOS/Public/AESMP%20User%20Primer.pdf' target='_blank'>here.</a>");
        }
        private bool ContainsValidEmailSuffix(string value)
        {
            foreach(var suffix in _validEmailSuffix)
            {
                if (value.IndexOf("@" + suffix, StringComparison.OrdinalIgnoreCase) > 1)
                    return true;
            }
            return false;
        }
        private string GetEmailDomain(string value)
        {
            var str = value?.Split('@');
            if(str != null && str.Count() > 1)            
                return str[1];
            else
                return string.Empty;
        }
    }
}
