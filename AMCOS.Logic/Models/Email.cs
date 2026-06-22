using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace AMCOS.Logic.Models
{
    public class Email
    {        
        /// <summary>
        /// Constructor
        /// </summary>
        /// <param name="from"></param>
        /// <param name="to"></param>
        /// <param name="subject"></param>
        /// <param name="body"></param>
        public Email(string from, string[] to, string subject, string body, string[] filesToAttach = null, string[] ccEmailAddresses = null, string[] bccEmailAddresses = null)
        {
            From = from;
            To = to;
            Subject = subject;
            Body = body;
            FilesToAttach = filesToAttach;
            CcEmailAddresses = ccEmailAddresses;
            BccEmailAddresses = bccEmailAddresses;
        }
        /// <summary>
        /// Email address sent from
        /// </summary>
        public string From { get; }
        /// <summary>
        /// Email addresses email sent to
        /// </summary>
        public string[] To { get; }
        /// <summary>
        /// Subject of the email
        /// </summary>
        public string Subject { get; }
        /// <summary>
        /// Contents of the email
        /// </summary>
        public string Body { get; }
        /// <summary>
        /// FileLocations to be attached
        /// </summary>
        public string[] FilesToAttach { get; }
        /// <summary>
        /// Carbon Copy for email to also send to
        /// </summary>
        public string[] CcEmailAddresses { get; }
        /// <summary>
        /// Blind carbon copy emails to send to
        /// </summary>
        public string[] BccEmailAddresses { get; }
    }
}
