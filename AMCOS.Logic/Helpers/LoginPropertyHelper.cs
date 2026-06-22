
using System.Collections.Generic;
using System.Linq;
using System.Web.Mvc;

namespace AMCOS.Logic.Helpers
{
    public static class LoginPropertyHelper
    {
        public static string[] GetPrefixList(string accountType)
        {
            if (accountType == "MILITARY")
                return ",PVT,PV2,PFC,SPC/CPL,SGT,SSG,SFC,MSG,SGM,2LT,1LT,CPT,MAJ,LTC,COL,BG,MG,LTG,GEN,WO1,CW2,CW3,CW4,CW5".Split(',');
            else
                return "Mr.,Ms.,Mrs.".Split(',');
        }
        public static string[] GetRankGradeList(string accountType)
        {
            if (accountType == "MILITARY")
                return ",E1,E2,E3,E4,E5,E6,E7,E8,E9,O1,O2,O3,O4,O5,O6,O7,O8,O9,O10,W1,W2,W3,W4,W5".Split(',');
            else
                return ",GS1,GS2,GS3,GS4,GS5,GS6,GS7,GS8,GS9,GS10,GS11,GS12,GS13,GS14,GS15,WG1,WG2,WG3,WG4,WG5,WG6,WG7,WG8,WG9,WG10,WG11,WG12,WG13,WG14,WG15,WL1,WL2,WL3,WL4,WL5,WL6,WL7,WL8,WL9,WL10,WL11,WL12,WL13,WL14,WL15,WS1,WS2,WS3,WS4,WS5,WS6,WS7,WS8,WS9,WS10,WS11,WS12,WS13,WS14,WS15,WS16,WS17,WS18,WS19,SES,Other (Specify)".Split(',');
        }
        public static bool ShowSponsor(string selfAccountType)
        {
            return selfAccountType?.ToUpper() != "CIVILIAN" && selfAccountType?.ToUpper() != "MILITARY";
        }
        public static bool ShowCompanyName(string selfAccountType)
        {
            return ShowSponsor(selfAccountType);
        }
       

        /// <summary>
        /// returns macom list
        /// </summary>
        /// <returns></returns>
        public static List<SelectListItem> LoadMacomList()
        {
            var list = UserAdministration.GetOrganizations().Select(i => new SelectListItem() { Text = i.Text, Value = i.Value }).ToList();
            list.Insert(0, new SelectListItem() { Text = "(Select)", Value = "" });
            return list;
        }
        
        /// <summary>
        /// Return the access status message for logins
        /// </summary>
        /// <param name="userStatus"></param>
        /// <param name="isExistingUser"></param>
        /// <returns></returns>
        public static string GetRegistrationStatusMessage(string userStatus, bool isExistingUser)
        {
            if (isExistingUser)
            {
                switch (userStatus)
                {
                    case "Denied":
                    case "SponsorOnly":
                        return "You have accessed the AMCOS system.  Your last access request has been denied.  Please contact your sponsor or DASA-CE at amcos-cave-helpdesk@army.mil for further information. You may re-apply for access when your issue has been resolved.";

                    default:
                        return "Your user profile has expired.  Please update your user profile and re-submit for review.";
                }
            }
            else
                return "You have accessed the AMCOS system.  Please complete the registration form.";
        }

        public static string ParseMultipleValueServerVariable(string serverVariableValue)
        {
            string[] serverVariableValues = serverVariableValue.Split(',');
            return serverVariableValues[0].Trim();
        }
    }
}
