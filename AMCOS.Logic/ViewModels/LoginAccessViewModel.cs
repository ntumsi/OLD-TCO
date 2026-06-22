using AMCOS.Logic.Helpers;
using AMCOS.Logic.Models;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace AMCOS.Logic.ViewModels
{
    public class LoginAccessViewModel
    {
        private List<Email> _emails;       
        private string _userStatus;
        public LoginAccessViewModel(string userFullName, string userStatus, List<Email> emails = null)
        {
            _emails = emails;
            SelfFullName = userFullName;
            _userStatus = userStatus;
        }
        
        /// <summary>
        /// Full name of the user attempting to access the site
        /// </summary>
        public string SelfFullName { get; }
        /// <summary>
        /// Display a status message for users who are returning to the site but are still waiting for their application to be processed
        /// </summary>
        public string AmcosAccessStatus => "You have accessed the AMCOS system and your application is currently under review.";
        /// <summary>
        /// Shows a message indicating that the user has just submitted their application and it will be processed
        /// </summary>
        public bool ShowAfterSubmit => _emails != null;
        /// <summary>
        /// Show contents of the emails that were sent inside the view (developent only)
        /// </summary>
        public bool ShowEmailSent => AppConfiguration.GetSetting("Environment") == "Development";
        /// <summary>
        /// Amcos Email address from (Used for development purposes only)
        /// </summary>
        public string EmailFrom1Literal
        {
            get
            {
                if (_emails != null && _emails.Count > 0)
                    return _emails[0].From;
                else
                    return null;
            }
        }
        /// <summary>
        /// User Address to (Used for development purposes only
        /// </summary>
        public string EmailTo1Literal
        {
            get
            {
                if (_emails != null && _emails.Count > 0)
                    return _emails[0].To[0];
                else
                    return null;
            }
        }
        /// <summary>
        /// Email subject (Used for development purposes only)
        /// </summary>
        public string EmailSubject1Literal
        {
            get
            {
                if (_emails != null && _emails.Count > 0)
                    return _emails[0].Subject;
                else
                    return null;
            }
        }
        /// <summary>
        /// Email Body (Used for development purposes only)
        /// </summary>
        public string EmailBody1Literal
        {
            get
            {
                if (_emails != null && _emails.Count > 0)
                    return _emails[0].Body;
                else
                    return null;
            }
        }
        /// <summary>
        /// Sponsor Email From  (used for development purposes only)
        /// </summary>
        public string EmailFrom2Literal
        {
            get
            {
                if (_emails != null && _emails.Count > 1)
                    return _emails[1].From;
                else
                    return null;
            }
        }
        /// <summary>
        /// Sponsor Email To Address (used for development purposes only)
        /// </summary>
        public string EmailTo2Literal
        {
            get
            {
                if (_emails != null && _emails.Count > 1)
                    return _emails[1].To[0];
                else
                    return null;
            }
        }
        /// <summary>
        /// Sponsor Email Subject (used for development purposes only)
        /// </summary>
        public string EmailSubject2Literal
        {
            get
            {
                if (_emails != null && _emails.Count > 1)
                    return _emails[1].Subject;
                else
                    return null;
            }
        }
        /// <summary>
        /// Sponsor Email body (used for development purposes only)
        /// </summary>
        public string EmailBody2Literal
        {
            get
            {
                if (_emails != null && _emails.Count > 1)
                    return _emails[1].Body;
                else
                    return null;
            }
        }
    }
}
