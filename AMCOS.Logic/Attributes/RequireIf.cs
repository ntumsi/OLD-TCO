using System.ComponentModel.DataAnnotations;
using System.Linq;

namespace AMCOS.Logic.Attributes
{
    /// <summary>
    /// Attribute class for validating user input
    /// </summary>
    public class RequireIf : ValidationAttribute
    {
        private string _property;
        private string[] _values;
        public RequireIf(string property, string[] values)
        {
            _property = property;
            _values = values;
        }
        protected override ValidationResult IsValid(object value, ValidationContext validationContext)
        {  
            if (_values != null && _values.Contains(validationContext.ObjectInstance.GetType().GetProperty(_property).GetValue(validationContext.ObjectInstance)?.ToString()))
                return !string.IsNullOrWhiteSpace(value?.ToString()) ? ValidationResult.Success : new ValidationResult("Required");
            else if (_values == null && string.IsNullOrWhiteSpace(validationContext.ObjectInstance.GetType().GetProperty(_property).GetValue(validationContext.ObjectInstance)?.ToString()))
                return !string.IsNullOrWhiteSpace(value?.ToString()) ? ValidationResult.Success : new ValidationResult("Required");
            else
                return ValidationResult.Success;            
        }        
    }
}
