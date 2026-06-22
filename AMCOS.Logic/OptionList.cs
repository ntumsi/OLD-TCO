using AMCOS.Data;
using AMCOS.Data.DataTransferObjects;
using System.Collections.Generic;
using System.Linq;
using System.Web.UI.WebControls;

namespace AMCOS.Logic
{
    public static class OptionList
    {
        public static IEnumerable<ListItem> GetCategoryGroups(string payPlan)
        {
            using (var context = new ApplicationDbContext())
            {
                return context.Category.AsNoTracking()
                    .Where(c => c.PayPlan == payPlan)
                    .Where(c => c.CategoryGroupCode != "-1")
                    .Select(c => new ListItem()
                    {
                        Text = c.CategoryGroupDisplay,
                        Value = c.CategoryGroupCode
                    })
                    .Distinct()
                    .OrderBy(c => c.Value)
                    .ToList();
            }
        }
        public static IEnumerable<ListItem> GetCategoryGroupsForXwalk(string payPlan, int amcosVersionId)
        {
            using (var context = new ApplicationDbContext())
            {
                List<string> categorySubgroupsWithCosts;
                List<string> categorySubgroupsWithXwalk;
                List<string> toCategorySubgroupsWithXwalk;
                List<string> allCategorySubgroupsWithXwalk;
                if (payPlan == "CCE")
                {
                    categorySubgroupsWithCosts = context.OccupationalEmploymentStatisticsMetro.AsNoTracking()
                        .Where(c => c.AmcosVersionId == amcosVersionId)
                        .Where(c => c.SOCStructure.GroupLevel == "Detailed")
                        .Select(c => c.SOC)
                        .Distinct()
                        .ToList();
                }
                else
                {
                    categorySubgroupsWithCosts = context.Costs.AsNoTracking()
                    .Where(c => c.PayPlan == payPlan)
                    .Where(c => c.AmcosVersionId == amcosVersionId)
                    .Where(c => c.CategorySubgroupCode != "-1")
                    .Select(c => c.CategorySubgroupCode)
                    .Distinct()
                    .ToList();
                }

                categorySubgroupsWithXwalk = context.SubgroupMapping.AsNoTracking()
                    .Where(c => c.PayPlan == payPlan)
                    .Where(c => categorySubgroupsWithCosts.Contains(c.CategorySubgroupCode))
                    .Where(c => amcosVersionId >= c.AmcosVersionIdStart)
                    .Where(c => amcosVersionId <= c.AmcosVersionIdEnd)
                    .Select(c => c.CategorySubgroupCode)
                    .Distinct()
                    .ToList();

                toCategorySubgroupsWithXwalk = context.SubgroupMapping.AsNoTracking()
                    .Where(c => c.ToPayPlan == payPlan)
                    .Where(c => categorySubgroupsWithCosts.Contains(c.ToCategorySubgroupCode))
                    .Where(c => amcosVersionId >= c.AmcosVersionIdStart)
                    .Where(c => amcosVersionId <= c.AmcosVersionIdEnd)
                    .Select(c => c.ToCategorySubgroupCode)
                    .Distinct()
                    .ToList();

                allCategorySubgroupsWithXwalk = categorySubgroupsWithXwalk.Concat(toCategorySubgroupsWithXwalk).ToList();

                return context.Category.AsNoTracking()
                    .Where(c => c.PayPlan == payPlan)
                    .Where(c => allCategorySubgroupsWithXwalk.Contains(c.CategorySubgroupCode))
                    .Where(c => c.CategoryGroupCode != "-1")
                    .Select(c => new ListItem()
                    {
                        Text = c.CategoryGroupDisplay,
                        Value = c.CategoryGroupCode
                    })
                    .Distinct()
                    .OrderBy(c => c.Value)
                    .ToList();
            }
        }
        public static IEnumerable<ListItem> GetCategoryGroupsWithInventory(string payPlan, int amcosVersionId)
        {
            using (var context = new ApplicationDbContext())
            {
                List<string> categoryGroupsWithInventory;

                if (payPlan == "CCE")
                {
                    categoryGroupsWithInventory = context.OccupationalEmploymentStatisticsMetro.AsNoTracking()
                        .Where(i => i.AmcosVersionId == amcosVersionId)
                        .Where(i => i.SOCStructure.GroupLevel == "Major")
                        .Select(i => i.SOC)
                        .Distinct()
                        .ToList();
                } else
                {
                    categoryGroupsWithInventory = context.Inventory.AsNoTracking()
                    .Where(i => i.PayPlan == payPlan)
                    .Where(i => i.AmcosVersionId == amcosVersionId)
                    .Select(i => i.CategoryGroupCode)
                    .Distinct()
                    .ToList();
                }                

                return context.Category.AsNoTracking()
                    .Where(c => c.PayPlan == payPlan)
                    .Where(c => categoryGroupsWithInventory.Contains(c.CategoryGroupCode))
                    .Where(c => c.CategoryGroupCode != "-1")
                    .Select(c => new ListItem()
                    {
                        Text = c.CategoryGroupDisplay,
                        Value = c.CategoryGroupCode
                    })
                    .Distinct()
                    .OrderBy(c => c.Value)
                    .ToList();
            }
        }
        public static IEnumerable<ListItem> GetCategorySubgroups(string payPlan)
        {
            using (var context = new ApplicationDbContext())
            {
                return context.Category.AsNoTracking()
                    .Where(c => c.PayPlan == payPlan)
                    .Where(c => c.CategorySubgroupCode != "-1")
                    .Select(c => new ListItem()
                    {
                        Text = c.CategorySubgroupDisplay,
                        Value = c.CategorySubgroupCode
                    })
                    .Distinct()
                    .OrderBy(c => c.Value)
                    .ToList();
            }
        }
        public static IEnumerable<ListItem> GetCategorySubgroups(string payPlan, string categoryGroupCode)
        {
            using (var context = new ApplicationDbContext())
            {
                return context.Category.AsNoTracking()                                
                    .Where(c => c.PayPlan == payPlan)
                    .Where(c => c.CategoryGroupCode == categoryGroupCode)
                    .Where(c => c.CategorySubgroupCode != "-1")
                    .Select(c => new ListItem()
                    {
                        Text = c.CategorySubgroupDisplay,
                        Value = c.CategorySubgroupCode
                    })
                    .Distinct()
                    .OrderBy(c => c.Value)
                    .ToList();
            }
        }
        public static IEnumerable<ListItem> GetCategorySubgroupsForXwalk(string payPlan, string categoryGroupCode, int amcosVersionId)
        {
            using (var context = new ApplicationDbContext())
            {
                List<string> categorySubgroupsWithCosts;
                List<string> categorySubgroupsWithXwalk;
                List<string> toCategorySubgroupsWithXwalk;
                List<string> allCategorySubgroupsWithXwalk;

                if (payPlan == "CCE")
                {
                    categorySubgroupsWithCosts = context.OccupationalEmploymentStatisticsMetro.AsNoTracking()
                        .Where(i => i.SOC.Substring(0, 2) == categoryGroupCode.Substring(0, 2))
                        .Where(i => i.AmcosVersionId == amcosVersionId)
                        .Select(i => i.SOC)
                        .Distinct()
                        .ToList();
                }
                else
                {
                    categorySubgroupsWithCosts = context.Costs.AsNoTracking()
                        .Where(i => i.PayPlan == payPlan)
                        .Where(i => i.CategoryGroupCode == categoryGroupCode)
                        .Where(i => i.AmcosVersionId == amcosVersionId)
                        .Select(i => i.CategorySubgroupCode)
                        .Distinct()
                        .ToList();
                }

                categorySubgroupsWithXwalk = context.SubgroupMapping.AsNoTracking()
                    .Where(c => c.PayPlan == payPlan)
                    .Where(c => categorySubgroupsWithCosts.Contains(c.CategorySubgroupCode))
                    .Where(c => amcosVersionId >= c.AmcosVersionIdStart)
                    .Where(c => amcosVersionId <= c.AmcosVersionIdEnd)
                    .Select(c => c.CategorySubgroupCode)
                    .Distinct()
                    .ToList();

                toCategorySubgroupsWithXwalk = context.SubgroupMapping.AsNoTracking()
                    .Where(c => c.ToPayPlan == payPlan)
                    .Where(c => categorySubgroupsWithCosts.Contains(c.ToCategorySubgroupCode))
                    .Where(c => amcosVersionId >= c.AmcosVersionIdStart)
                    .Where(c => amcosVersionId <= c.AmcosVersionIdEnd)
                    .Select(c => c.ToCategorySubgroupCode)
                    .Distinct()
                    .ToList();

                allCategorySubgroupsWithXwalk = categorySubgroupsWithXwalk.Concat(toCategorySubgroupsWithXwalk).ToList();

                return context.Category.AsNoTracking()
                    .Where(c => c.PayPlan == payPlan)
                    .Where(c => allCategorySubgroupsWithXwalk.Contains(c.CategorySubgroupCode))
                    .Select(c => new ListItem()
                    {
                        Text = c.CategorySubgroupDisplay,
                        Value = c.CategorySubgroupCode
                    })
                    .Distinct()
                    .OrderBy(c => c.Value)
                    .ToList();
            }
        }
        public static IEnumerable<ListItem> GetCategorySubgroupsWithInventory(string payPlan, string categoryGroupCode, int amcosVersionId)
        {
            using (var context = new ApplicationDbContext())
            {
                List<string> categorySubgroupsWithInventory;

                if (payPlan == "CCE")
                {
                    categorySubgroupsWithInventory = context.OccupationalEmploymentStatisticsMetro.AsNoTracking()
                        .Where(i => i.SOC.Substring(0,2) == categoryGroupCode.Substring(0,2))
                        .Where(i => i.AmcosVersionId == amcosVersionId)
                        .Select(i => i.SOC)
                        .Distinct()
                        .ToList();
                } else
                {
                    categorySubgroupsWithInventory = context.Inventory.AsNoTracking()
                        .Where(i => i.PayPlan == payPlan)
                        .Where(i => i.CategoryGroupCode == categoryGroupCode)
                        .Where(i => i.AmcosVersionId == amcosVersionId)
                        .Select(i => i.CategorySubgroupCode)
                        .Distinct()
                        .ToList();
                }                

                return context.Category.AsNoTracking()                    
                    .Where(c => c.PayPlan == payPlan)
                    .Where(c => c.CategoryGroupCode == categoryGroupCode)
                    .Where(c => categorySubgroupsWithInventory.Contains(c.CategorySubgroupCode))
                    .Select(c => new ListItem()
                    {
                        Text = c.CategorySubgroupDisplay,
                        Value = c.CategorySubgroupCode
                    })
                    .Distinct()
                    .OrderBy(c => c.Value)
                    .ToList();
            }
        }
        public static IEnumerable<ListItem> GetGradeLevels(string payPlan, int locationId, int amcosVersionId)
        {
            using (var context = new ApplicationDbContext())
            {
                List<ListItem> gradeLevels = context.Costs.AsNoTracking()
                    .Where(c => c.PayPlan == payPlan)
                    .Where(c => c.CategoryGroupCode == "-1")
                    .Where(c => c.CategorySubgroupCode == "-1")
                    .Where(c => c.LocationId == locationId)
                    .Where(c => c.AmcosVersionId == amcosVersionId)
                    .Select(c => new ListItem()
                    {
                        Text = c.GradeType + c.GradeLevel,
                        Value = c.GradeLevel.ToString()
                    })
                    .Distinct()
                    .OrderBy(c => c.Value.Length).ThenBy(c => c.Value)
                    .ToList();
                return gradeLevels;
            }
        }
        public static IEnumerable<ListItem> GetGradeLevels(string payPlan, string categorySubgroupCode, int amcosVersionId)
        {
            using (var context = new ApplicationDbContext())
            {
                List<ListItem> gradeLevels = context.Costs.AsNoTracking()
                    .Where(c => c.PayPlan == payPlan)
                    .Where(c => c.CategorySubgroupCode == categorySubgroupCode)
                    .Where(c => c.LocationId == -1)
                    .Where(c => c.AmcosVersionId == amcosVersionId)
                    .Select(c => new ListItem()
                    {
                        Text = c.GradeType + c.GradeLevel,
                        Value = c.GradeLevel.ToString()
                    })
                    .Distinct()
                    .OrderBy(c => c.Value.Length).ThenBy(c => c.Value)
                    .ToList();
                return gradeLevels;
            }
        }
        public static IEnumerable<ListItem> GetGradeLevels(string payPlan, string categorySubgroupCode, int locationId, int amcosVersionId)
        {
            using (var context = new ApplicationDbContext())
            {
                List<ListItem> gradeLevels = context.Costs.AsNoTracking()
                    .Where(c => c.PayPlan == payPlan)
                    .Where(c => c.CategorySubgroupCode == categorySubgroupCode)
                    .Where(c => c.LocationId == locationId)
                    .Where(c => c.AmcosVersionId == amcosVersionId)
                    .Select(c => new ListItem()
                    {
                        Text = c.GradeType + c.GradeLevel,
                        Value = c.GradeLevel.ToString()
                    })
                    .Distinct()
                    .OrderBy(c => c.Value.Length).ThenBy(c => c.Value)
                    .ToList();
                return gradeLevels;
            }
        }
        public static IEnumerable<ListItem> GetLocalityPayAreaList(string categorySubgroupCode, int amcosVersionId)
        {
            using (var context = new ApplicationDbContext())
            {
                List<ListItem> options = new List<ListItem>();
                IEnumerable<ListItem> localityPayArea = null;
                IEnumerable<ListItem> civOverseas = null;

                localityPayArea = context.LocationByCategory.AsNoTracking()
                   .Where(c => c.PayPlan == "GS")
                   .Where(c => c.CategorySubgroupCode == categorySubgroupCode)
                   .Where(c => c.LocalityPayArea != null)
                   .Select(c => new ListItem()
                   {
                       Text = c.LocalityPayArea,
                       Value = c.LocationId.ToString()
                   })
                   .Distinct();

                civOverseas = context.LocationByCategory.AsNoTracking()
                   .Where(c => c.PayPlan == "GS")
                   .Where(c => c.CategorySubgroupCode == categorySubgroupCode)
                   .Where(c => c.CivOverseas != null)
                   .Select(c => new ListItem()
                   {
                       Text = c.CivOverseas,
                       Value = c.LocationId.ToString()
                   })
                   .Distinct();

                options = options.Concat(localityPayArea).ToList();
                options = options.Concat(civOverseas).ToList();
                options.OrderBy(c => c.Text);
                return options;
            }
        }
        public static IEnumerable<ListItem> GetMetroAreas(string soc)
        {
            using (var context = new ApplicationDbContext())
            {
                IQueryable<string> innerquery = (from i in context.OccupationalEmploymentStatisticsMetro
                                                 where i.SOC == soc
                                                 select i.MSACode).Distinct();

                return (from m in context.MetropolitanStatisticalArea
                        where (innerquery.Contains(m.MSACode))
                        select new ListItem()
                        {
                            Text = m.MSACode + " : " + m.MSAName,
                            Value = m.MSACode
                        }).OrderBy(m => m.Value).ToList();
            }
        }
        public static IEnumerable<ListItem> GetMetropolitanStatisticalAreas(string standardOccupationalCode, int amcosVersionId)
        {
            //SELECT AreaCode, AreaCode + ' - '+ AreaName as AreaDesc 
            //from lookup.MetroArea where AreaCode in (select AreaCode from dataload.OccupationalEmploymentStatisticsMetro where SOC = @soc) 
            //order by AreaName
            using (var context = new ApplicationDbContext())
            {
                var metropolitanStatisticalAreasWithCosts = context.OccupationalEmploymentStatisticsMetro.AsNoTracking()
                    .Where(c => c.SOC == standardOccupationalCode)
                    .Select(c => c.MSACode)
                    .Distinct();

                var results = context.MetropolitanStatisticalArea.AsNoTracking()
                    .Where(m => amcosVersionId >= m.AmcosVersionIdStart && amcosVersionId <= m.AmcosVersionIdEnd)
                    //.Where(m => (m.AreaTypeCode == "M") || (m.AreaTypeCode == "S"))
                    .Where(m => metropolitanStatisticalAreasWithCosts.Contains(m.MSACode))
                    .Select(m => new ListItem()
                    {
                        Text = m.MSACode + " : " + m.MSAName,
                        Value = m.MSACode
                    })
                    .OrderBy(m => m.Value)
                    .ToList();
                return results;
            }
        }
        public static IEnumerable<ListItem> GetPayPlans(bool includeCCE = false)
        {
            using (var context = new ApplicationDbContext())
            {
                List<string> payPlansWithInventory;

                if (includeCCE)
                {
                    payPlansWithInventory = context.Inventory.AsNoTracking()
                        .Select(p => p.PayPlan)
                        .Distinct()
                        .ToList();
                }
                else
                {
                    payPlansWithInventory = context.Category.AsNoTracking()
                        .Where(p => p.PayPlan != "CCE")
                        .Select(p => p.PayPlan)
                        .Distinct()
                        .ToList();
                }

                List<ListItem> payPlans = context.PayPlan.AsNoTracking()
                    .Where(p => payPlansWithInventory.Contains(p.Name))
                    .OrderBy(p => p.DisplayTitle)
                       .Select(p => new ListItem()
                       {
                           Text = p.DisplayTitle,
                           Value = p.Name
                       }).ToList();
                return payPlans;
            }
        }
        public static IEnumerable<ListItem> GetPayPlansWithoutCCE()
        {
            using (var context = new ApplicationDbContext())
            {
                List<ListItem> payPlans = context.PayPlan
                    .Where(p => p.Name != "CCE")
                    .OrderBy(p => p.Description)
                    .Select(p => new ListItem()
                    {
                        Text = p.Description,
                        Value = p.Name.ToString()
                    })
                    .Distinct()
                    .OrderBy(c => c.Value)
                    .ToList();
                return payPlans;
            }
        }
        public static Dictionary<string,string> GetPayPlansWithPaySchedules(int amcosVersionId)
        {
            using (var context = new ApplicationDbContext())
            {
                List<string> payPlansWithPaySchedules;

                payPlansWithPaySchedules = context.PaySchedules.AsNoTracking()
                    .Where(p => p.AmcosVersionId == amcosVersionId)
                    .Select(p => p.PayPlan)
                    .Distinct()
                    .ToList();

                var payPlans = context.PayPlan.AsNoTracking()
                    .Where(p => payPlansWithPaySchedules.Contains(p.Name))
                    .OrderBy(p => p.DisplayTitle)
                    .ToDictionary(p => p.Name, p => p.DisplayTitle);
                    
                return payPlans;
            }
        }
        public static List<UnitDto> GetUnitList()
        {
            using (var context = new ApplicationDbContext())
            {
                var unitList = context.UnitPersonnel.AsNoTracking()                        
                    .Select(c => new UnitDto()
                    {
                        Text = c.UIC + " : " + c.UICTitle,
                        Value = c.UIC
                    })
                    .Distinct()
                    .OrderBy(c => c.Value)
                    .ToList();
                return unitList;
            }
        }
        public static IEnumerable<ListItem> GetWageSchedulesXWalk(string payPlan)
        {
            //Select DISTINCT CategorySubgroupCode,
            //CategorySubgroupCode + ' - ' + CategorySubGroupDescription AS Description
            //From data.CategorySubGroup
            //Where CategorySubgroupCode In (Select CategorySubgroupCode FROM data.Costs WHERE PayPlan = PayPlanWageList.SelectedValue)
            //ORDER BY CategorySubgroupCode;
            using (var context = new ApplicationDbContext())
            {
                List<ListItem> wageSchedules = context.LocationByCategory.AsNoTracking()
                    .Where(l => l.PayPlan == payPlan)
                    .Where(l => l.CategoryGroupCode == "-1")
                    .Where(l => l.CategorySubgroupCode == "-1")
                    .Where(l => l.WageSchedule != null)
                    .Select(l => new ListItem()
                    {
                        Text = l.WageSchedule,
                        Value = l.LocationId.ToString()
                    })
                    .Distinct()
                    .OrderBy(c => c.Text)
                    .ToList();
                return wageSchedules;
            }
        }
        public static IEnumerable<ListItem> GetWageSchedulesWithInventory(string payPlan)
        {
            using (var context = new ApplicationDbContext())
            {
                List<ListItem> wageSchedules = context.Inventory.AsNoTracking()
                    .Where(p => p.PayPlan == payPlan)
                    .Select(p => new ListItem()
                    {
                        Text = p.LocationLookup.DisplayName,
                        Value = p.LocationId.ToString()
                    })
                    .Distinct()
                    .ToList();
                return wageSchedules;
            }
        }
        public static Dictionary<string, string> GetWageSchedulesWithPaySchedules(string payPlan)
        {
            using (var context = new ApplicationDbContext())
            {
                var wageSchedules = context.PaySchedules.AsNoTracking()
                    .Where(p => p.PayPlan == payPlan)
                    .Select(p => new 
                    {
                        Text = p.LocationLookup.DisplayName,
                        Value = p.LocationId.ToString()
                    })
                    .Distinct()
                    .ToDictionary(p => p.Value, p => p.Text);
                return wageSchedules;
            }
        }
    }

}
