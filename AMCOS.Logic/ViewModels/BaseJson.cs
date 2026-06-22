using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace AMCOS.Logic.ViewModels
{
    /// <summary>
    /// This class holds variables used for antiforgery and user session maintenance.  
    /// Consider that on an ajax post back, the browser refresh will occur automatically if authentication timeout would occur. 
    /// </summary>
    public class BaseJson
    {
        /// <summary>
        /// AntiForgeryToken used to refresh the anitforgery token in the active browser session.
        /// </summary>
        public string AntiForgeryToken { get; set; }
        /// <summary>
        /// Time in milliseconds before authentication timeout occurs.  Assuming SlidingExpiration the timeout is only reset if the user is  Subtracting 10000 for latency.
        /// Handle from an ajax error response instead.
        /// </summary>
        public int AuthenticationTimeout { get; set; }
    }
}
