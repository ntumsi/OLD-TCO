
using System.ComponentModel.DataAnnotations;

namespace AMCOS.Logic.Attributes
{
    public class NotEqualTo : ValidationAttribute
    {
        private string _property;
        public NotEqualTo(string property)
        {
            _property = property;
        }
        protected override ValidationResult IsValid(object value, ValidationContext validationContext)
        {
            if (validationContext.ObjectInstance.GetType().GetProperty(_property).GetValue(validationContext.ObjectInstance)?.ToString() == value?.ToString())
                return new ValidationResult("Cannot equal " + _property);
            else
                return ValidationResult.Success;
        }
    }
}
