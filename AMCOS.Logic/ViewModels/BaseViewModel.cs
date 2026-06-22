using AMCOS.Data.Entities;
using System;

namespace AMCOS.Logic.ViewModels
{
    /// <summary>
    /// Use this base class with all ViewModels that employ _Layout.vbhtml as their View's layout.
    /// </summary>
    public abstract class BaseViewModel
    {
        public BaseViewModel(AMCOSUser user)
        {
            var isDevelopment = AppConfiguration.GetSetting("Environment") == "Development";            
            IsAdmin = user.UserRole == "Admin";
            if (IsAdmin)
            {
                var pendingUsers = Convert.ToInt32(DataAccessUtility.GetScalarByStaticSql("select web.GetPendingUserCount()"));
                switch (pendingUsers)
                {
                    case 0:
                        ShowPendingUsersNotification = false;
                        break;
                    case 1:
                        ShowPendingUsersNotification = true;
                        PendingUsersNotification = "There is one AMCOS user account pending!";
                        break;
                    default:
                        ShowPendingUsersNotification = true;
                        PendingUsersNotification = $"There are {pendingUsers} AMCOS user accounts pending!";
                        break;
                }
            }
            else
                ShowPendingUsersNotification = false;
        }
        /// <summary>
        /// Used in determining display of role based client side web controls
        /// </summary>
        public bool IsAdmin { get; }
        /// <summary>
        /// Show pending users notification when the requester is an admin and there are pending users.
        /// </summary>
        public bool ShowPendingUsersNotification { get; }
        /// <summary>
        /// The pending users notification to display
        /// </summary>
        public string PendingUsersNotification { get; }

        public string CustomDataExportEmail => Properties.Resources.CustomDataExportEmail;        
        
    }
}
