using AMCOS.Data;
using System;
using System.Collections.Generic;
using System.Drawing;
using System.Linq;

namespace AMCOS.Logic
{
    public class PayPlan
    {
        public const string ColorHtmlActiveMpa = "#5D7430";
        public const string ColorHtmlActiveOma = "#6A9303";
        public const string ColorHtmlActiveOmdw = "#7030A0";
        public const string ColorHtmlActiveFedOma = "#00008B";
        public const string ColorHtmlArngPA = "#74B803";
        public const string ColorHtmlOmng = "#8BA103";
        public const string ColorHtmlRpa = "#5C9303";
        public const string ColorHtmlOmar = "#6E8003";
        public const string ColorHtmlCivArmyCivPay = "#1F8802";
        public const string ColorHtmlCivArmyOma = ColorHtmlActiveOma;
        public const string ColorHtmlCivFedOma = ColorHtmlActiveFedOma;
        public const string ColorHtmlCce = "#006D8B";
        public const string ColorHtmlTotal = "#DEDFDE";
        public const string ColorHtmlSumArmy = ColorHtmlActiveMpa;
        public const string ColorHtmlSumDod = ColorHtmlActiveOma;
        public const string ColorHtmlSumFed = ColorHtmlActiveFedOma;
        public const string ColorHtmlCostElementStructure = "#FFA500";

        // Properties
        public string Name { get; set; }
        public string Description { get; set; }
        public string CategoryGroupName
        {
            get
            {
                switch (Name)
                {
                    case "AE":
                    case "RE":
                    case "NE":
                        return "Career Management Field (CMF)";
                    case "AO":
                    case "RO":
                    case "NO":
                        return "Branch / Functional Area";
                    case "AWO":
                    case "RWO":
                    case "NWO":
                        return "Career Management Field (CMF)";
                    case "DB":
                    case "DE":
                    case "DJ":
                    case "DK":
                    case "GP":
                    case "GG":
                    case "GL":
                    case "GS":
                    case "NH":
                    case "NJ":
                    case "NK":
                    case "SES":
                        return "Occupational Group";
                    case "WL":
                    case "WS":
                    case "WG":
                        return "Wage Schedule";
                    case "CCE":
                        return "SOC Major Group";
                    default:
                        return "Group";
                }
            }
        }
        public string CategorySubgroupName
        {
            get
            {
                switch (Name)
                {
                    case "AE":
                    case "RE":
                    case "NE":
                    case "AWO":
                    case "RWO":
                    case "NWO":
                        return "Military Occupational Specialties (MOS)";
                    case "AO":
                    case "RO":
                    case "NO":
                        return "Area of Concentration (AOC)";
                    case "DB":
                    case "DE":
                    case "DJ":
                    case "DK":
                    case "GP":
                    case "GG":
                    case "GL":
                    case "GS":
                    case "NH":
                    case "NJ":
                    case "NK":
                    case "SES":
                        return "Occupational Series";
                    case "CCE":
                        return "Detailed Occupation";
                    default:
                        return "SubGroup";
                }
            }
        }
        public string GradeName
        {
            get
            {
                switch (Name)
                {
                    case "AE":
                    case "RE":
                    case "NE":
                        return "E";
                    case "AO":
                    case "RO":
                    case "NO":
                        return "O";
                    case "AWO":
                    case "RWO":
                    case "NWO":
                        return "W";
                    case "SES":
                        return "Level ";
                    default:
                        return Name;
                }
            }
        }
        public string GradeNameText
        {
            get
            {
                switch (Name)
                {
                    case "AE":
                    case "AO":
                    case "AWO":
                    case "GP":
                    case "GG":
                    case "GL":
                    case "GS":
                    case "NE":
                    case "NO":
                    case "NWO":
                    case "RE":
                    case "RO":
                    case "RWO":
                    case "WG":
                    case "WL":
                    case "WS":
                        return "Grade";
                    case "DB":
                    case "DE":
                    case "DJ":
                    case "DK":
                    case "NH":
                    case "NJ":
                    case "NK":
                        return "Pay Band";
                    case "CCE":
                        return "Salary Percentile Level";
                    case "SES":
                        return "Grade";
                    default:
                        return Name;
                }
            }
        }
        
        // Constructor
        public PayPlan(string payPlanName)
        {
            Name = payPlanName;
        }
        public Color GetAppropriationColor(string appropriationGroup, string appropriation)
        {
            if (GetTags().Contains("Active Military"))
            {
                switch (appropriationGroup)
                {
                    case "ARMY":
                        if (appropriation == "OMA")
                            return ColorTranslator.FromHtml(ColorHtmlActiveOma);
                        else
                            return ColorTranslator.FromHtml(ColorHtmlActiveMpa);
                    case "DoD":
                        return ColorTranslator.FromHtml(ColorHtmlActiveOmdw);
                    case "FEDERAL":
                        return ColorTranslator.FromHtml(ColorHtmlActiveFedOma);
                    default:
                        return Color.DarkBlue;
                }
            } else if (GetTags().Contains("National Guard"))
            {
                switch (appropriationGroup)
                {
                    case "ARMY":
                        if (appropriation == "OMA")
                            return ColorTranslator.FromHtml(ColorHtmlActiveOma);
                        else
                            return ColorTranslator.FromHtml(ColorHtmlActiveMpa);
                    case "PA":
                        return ColorTranslator.FromHtml(ColorHtmlArngPA);
                    case "OM":
                        return ColorTranslator.FromHtml(ColorHtmlOmng);
                    default:
                        return Color.DarkBlue;
                }
            } else if (GetTags().Contains("Reserves"))
            {
                switch (appropriationGroup)
                {
                    case "ARMY":
                        if (appropriation == "OMA")
                            return ColorTranslator.FromHtml(ColorHtmlActiveOma);
                        else
                            return ColorTranslator.FromHtml(ColorHtmlActiveMpa);
                    case "PA":
                        return ColorTranslator.FromHtml(ColorHtmlRpa);
                    case "OM":
                        return ColorTranslator.FromHtml(ColorHtmlOmar);
                    default:
                        return Color.DarkBlue;
                }
            } else if (GetTags().Contains("Civilian") || GetTags().Contains("GFEBS") || GetTags().Contains("Wage"))
            {
                if (Name == "CCE")
                {
                    return ColorTranslator.FromHtml(ColorHtmlCce);
                }
                switch (appropriationGroup)
                {
                    case "ARMY":
                        if (appropriation == "OMA")
                            return ColorTranslator.FromHtml(ColorHtmlCivArmyOma);
                        else
                            return ColorTranslator.FromHtml(ColorHtmlCivArmyCivPay);
                    case "FEDERAL":
                        return ColorTranslator.FromHtml(ColorHtmlCivFedOma);
                    default:
                        return Color.DarkBlue;
                }
            } else
            {
                return Color.DarkBlue;
            }
        }
        public Color GetAppropriationGroupColor(string AppropriationGroup)
        {

            if (GetTags().Contains("Active Military"))
            {
                switch (AppropriationGroup.ToUpper())
                {
                    case "ARMY":
                        return ColorTranslator.FromHtml(ColorHtmlActiveMpa);
                    case "DOD":
                        return ColorTranslator.FromHtml(ColorHtmlActiveOmdw);
                    case "FEDERAL":
                        return ColorTranslator.FromHtml(ColorHtmlActiveFedOma);
                    default:
                        return Color.DarkBlue;
                }
            } else if (GetTags().Contains("National Guard"))
            {
                switch (AppropriationGroup.ToUpper())
                {
                    case "ARMY":
                        return ColorTranslator.FromHtml(ColorHtmlActiveMpa);
                    case "PA":
                        return ColorTranslator.FromHtml(ColorHtmlArngPA);
                    case "OM":
                        return ColorTranslator.FromHtml(ColorHtmlOmng);
                    default:
                        return Color.DarkBlue;
                }
            } else if (GetTags().Contains("Reserves"))
            {
                switch (AppropriationGroup.ToUpper())
                {
                    case "ARMY":
                        return ColorTranslator.FromHtml(ColorHtmlActiveMpa);
                    case "PA":
                        return ColorTranslator.FromHtml(ColorHtmlRpa);
                    case "OM":
                        return ColorTranslator.FromHtml(ColorHtmlOmar);
                    default:
                        return Color.DarkBlue;
                }
            } else if (GetTags().Contains("Civilian") || GetTags().Contains("GFEBS") || GetTags().Contains("Wage"))
            {
                if (Name == "CCE")
                {
                    return ColorTranslator.FromHtml(ColorHtmlCce);
                }
                switch (AppropriationGroup.ToUpper())
                {
                    case "ARMY":
                        return ColorTranslator.FromHtml(ColorHtmlCivArmyCivPay);
                    case "FEDERAL":
                        return ColorTranslator.FromHtml(ColorHtmlCivFedOma);
                    default:
                        return Color.DarkBlue;
                }
            } else
            {
                return Color.DarkBlue;
            }
        }
        public Color GetArmyCesTitleColor(string armyCesTitle)
        {
            string[] exclude = {
                "4.01/4.02/4.03 - NGPA - Crew, Maintenance(MTOE), & System-Specific Support",
                "4.01/4.02/4.03 - RPA - Crew, Maintenance(MTOE), & System-Specific Support",
                "4.051 - MPA - Replacement Personnel (Training)",
                "4.051 - NGPA - Replacement Personnel (Training)",
                "4.051 - RPA - Replacement Personnel (Training)",
                "4.06 - MPA - Other Military Personnel Costs",
                "4.06 - NGPA - Other Military Personnel Costs",
                "4.06 - RPA - Other Military Personnel Costs",
                "5.06.02.01.02 Acquisition of New Personnel-MPA",
                "5.06.02.01.02 Acquisition of New Personnel-NGPA",
                "5.06.02.01.02 Acquisition of New Personnel-OMA",
                "5.06.02.01.02 Acquisition of New Personnel-OMA_1",
                "5.06.02.01.02 Acquisition of New Personnel-OMAR",
                "5.06.02.01.02 Acquisition of New Personnel-OMNG",
                "5.06.02.01.02 Acquisition of New Personnel-RPA",
                "5.06.02.02 Personnel Benefits-NGPA",
                "5.06.02.02 Personnel Benefits-RPA",
                "5.06.02.02.01 Family Housing-OMA",
                "5.06.02.02.02 Dependent Support Programs-OMDW",
                "5.06.02.02.03 Commissaries and Exchanges-OMDW",
                "5.06.02.03 Medical Support-MPA",
                "5.06.02.03 Medical Support-NGPA",
                "5.06.02.03 Medical Support-OMAR",
                "5.06.02.03 Medical Support-OMDW",
                "5.06.02.03 Medical Support-OMNG",
                "5.06.02.03 Medical Support-RPA",
                "5.06.03.01 Recruit And Initial Officer Training-MPA",
                "5.06.03.01 Recruit And Initial Officer Training-NGPA",
                "5.06.03.01 Recruit And Initial Officer Training-OMA",
                "5.06.03.01 Recruit And Initial Officer Training-OMA_1",
                "5.06.03.01 Recruit And Initial Officer Training-OMAR",
                "5.06.03.01 Recruit And Initial Officer Training-OMNG",
                "5.06.03.01 Recruit And Initial Officer Training-RPA",
                "5.06.03.02 General Skill Training-MPA",
                "5.06.03.02 General Skill Training-NGPA",
                "5.06.03.02 General Skill Training-OMA",
                "5.06.03.02 General Skill Training-OMA_1",
                "5.06.03.02 General Skill Training-OMAR",
                "5.06.03.02 General Skill Training-OMNG",
                "5.06.03.02 General Skill Training-RPA",
                "5.06.03.03 Professional Military Education-MPA",
                "5.06.03.03 Professional Military Education-NGPA",
                "5.06.03.03 Professional Military Education-OMA",
                "5.06.03.03 Professional Military Education-OMA_1",
                "5.06.03.03 Professional Military Education-OMAR",
                "5.06.03.03 Professional Military Education-OMNG",
                "5.06.03.03 Professional Military Education-RPA",
                "5.11 - OMA - Training",
                "5.11 - OMAR - Training",
                "5.11 - OMNG - Training",
                "5.12 - OMA - Other",
                "5.12 - OMAR - Other",
                "5.12 - OMDW - Other",
                "5.12 - OMNG - Other",
                "No Army CES",
                "No Army CES-Federal OM" };
            if (exclude.Contains(armyCesTitle))
                return Color.Orange;
            else
                return Color.DarkBlue;
        }
        public bool WithinTag(string payPlanTag)
        {
            using (var context = new ApplicationDbContext())
            {
                var payPlanTags = context.PayPlanTags.AsNoTracking()
                    .Where(p => p.PayPlan == Name)
                    .Select(p => p.Tag)
                    .Distinct()
                    .ToList();
                return payPlanTags.Contains(payPlanTag);                
            }
        }
        public List<string> GetTags()
        {
            using (var context = new ApplicationDbContext())
            {
                var payPlanTags = context.PayPlanTags.AsNoTracking()
                    .Where(p => p.PayPlan == Name)
                    .Select(p => p.Tag)
                    .Distinct()
                    .ToList();
                return payPlanTags;
            }
        }
        public string GetDisplayTitle()
        {
            string result = "";
            using (var context = new ApplicationDbContext())
            {
                var payPlanDisplayTitle = context.PayPlan.AsNoTracking()
                    .Where(p => p.Name == Name)
                    .Select(p => p.DisplayTitle)
                    .First();
                result = payPlanDisplayTitle;
            }
            return result;
        }
        public string GetCategoryGroupLabel()
        {
            string result = "";
            using (var context = new ApplicationDbContext())
            {
                var categoryGroupLabel = context.PayPlan.AsNoTracking()
                    .Where(p => p.Name == Name)
                    .Select(p => p.CategoryGroupLabel)
                    .First();
                result = categoryGroupLabel;
            }
            return result;
        }
        public string GetCategoryGroupText(string categoryGroupCode)
        {
            if (categoryGroupCode == null)
            {
                throw new ArgumentNullException(nameof(categoryGroupCode));
            }

            string result = "";

            if (categoryGroupCode == "-1")
            {
                result = "All";
            }
            else
            {
                using (var context = new ApplicationDbContext())
                {
                    var categoryGroupDisplay = context.Category.AsNoTracking()
                        .Where(c => c.PayPlan == Name)
                        .Where(c => c.CategoryGroupCode == categoryGroupCode)
                        .Select(c => c.CategoryGroupDisplay)
                        .First();
                    result = categoryGroupDisplay;
                }                
            }
            return result;
        }
        public string GetCategorySubgroupLabel()
        {
            string result = "";
            using (var context = new ApplicationDbContext())
            {
                var categorySubgroupLabel = context.PayPlan.AsNoTracking()
                    .Where(p => p.Name == Name)
                    .Select(p => p.CategorySubgroupLabel)
                    .First();
                result = categorySubgroupLabel;
            }
            return result;
        }
        public string GetCategorySubgroupText(string categorySubgroupCode)
        {
            if (categorySubgroupCode == null)
            {
                throw new ArgumentNullException(nameof(categorySubgroupCode));
            }

            string result = "";

            if (categorySubgroupCode == "-1")
            {
                result = "All";
            }
            else
            {
                using (var context = new ApplicationDbContext())
                {
                    var categorySubgroupDisplay = context.Category.AsNoTracking()
                        .Where(c => c.PayPlan == Name)
                        .Where(c => c.CategorySubgroupCode == categorySubgroupCode)
                        .Select(c => c.CategorySubgroupDisplay)
                        .First();
                    result = categorySubgroupDisplay;
                }
            }            
            return result;
        }
        public string GetCareerProgramText(string careerProgramNumber)
        {
            if (careerProgramNumber == null)
            {
                throw new ArgumentNullException(nameof(careerProgramNumber));
            }

            string result = "";

            if (careerProgramNumber == "-1")
            {
                result = "All";
            }
            else
            {
                using (var context = new ApplicationDbContext())
                {
                    var careerProgramDisplay = context.Category.AsNoTracking()
                        .Where(c => c.PayPlan == Name)
                        .Where(c => c.CareerProgramNumber == careerProgramNumber)
                        .Select(c => c.CareerProgramDisplay)
                        .First();
                    result = careerProgramDisplay;
                }
            }            
            return result;
        }
        public string GetLocationText()
        {
            //TODO Grab the location text based on the Id
            return "Location Name Will Appear Here";
        }
        public string GetInflationConversionTypeText(string value)
        {
            string result = "";

            if (value == "ThenToConstant")
            {
                result = "Then Year to Constant Dollars";
            }

            if (value == "ThenToThen")
            {
                result = "Then Year to Then Year";
            }

            return result;
        }
    }
}
