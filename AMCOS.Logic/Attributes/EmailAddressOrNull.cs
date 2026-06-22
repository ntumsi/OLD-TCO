using System.ComponentModel.DataAnnotations;
using System.Text.RegularExpressions;

namespace AMCOS.Logic.Attributes
{
    public class EmailAddressOrNull : ValidationAttribute
    {
        Regex _regex = new Regex(@"^(([\w-]+\.)+[\w-]+|([a-zA-Z]{1}|[\w-]{2,}))@((([0-1]?[0-9]{1,2}|25[0-5]|2[0-4][0-9])\.([0-1]?[0-9]{1,2}|25[0-5]|2[0-4][0-9])\.([0-1]?[0-9]{1,2}|25[0-5]|2[0-4][0-9])\.([0-1][0-9]{1,2}|25[0-5]|2[0-4][0-9])){1}|([a-zA-Z]+[\w-]+\.)+[a-zA-Z]{2,4})$");
        protected override ValidationResult IsValid(object value, ValidationContext validationContext)
        {
            if(!string.IsNullOrWhiteSpace(value?.ToString()) && _regex.Match(value.ToString()).Length < 1)
                return new ValidationResult("Valid email required.");
            else
                return ValidationResult.Success;
        }
    }
}
