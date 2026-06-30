using AMCOS.Data;
using AMCOS.Data.DataTransferObjects;
using System;
using System.Collections.Generic;
using System.Data;
using Npgsql;
using NpgsqlTypes;
using System.Linq;

namespace AMCOS.Logic
{
    public class Inventory
    {
        // Properties
        public string PayPlan { get; set; }
        public string CategoryGroupCode { get; set; }
        public string CategorySubgroupCode { get; set; }
        public int LocationId { get; set; }
        public string MetropolitanStatisticalAreaCode { get; set; }
        public int AmcosVersionId { get; set; }

        // Constructor
        public Inventory(string payPlan, string categoryGroupCode, string categorySubgroupCode, string metropolitanStatisticalAreaCode, int amcosVersionId)
        {
            PayPlan = payPlan;
            CategoryGroupCode = categoryGroupCode;
            CategorySubgroupCode = categorySubgroupCode;
            MetropolitanStatisticalAreaCode = metropolitanStatisticalAreaCode;
            AmcosVersionId = amcosVersionId;
        }
        public Inventory(string payPlan, int locationId, int amcosVersionId)
        {
            PayPlan = payPlan;
            LocationId = locationId;
            AmcosVersionId = amcosVersionId;
        }

        // Methods        
        public List<InventoryCCEDto> GetInventoryCCE()
        {
            List<InventoryCCEDto> inventory = new List<InventoryCCEDto>();
            IEnumerable<InventoryCCEDto> metro = null;
            IEnumerable<InventoryCCEDto> national = null;

            using (var context = new ApplicationDbContext())
            {
                if (MetropolitanStatisticalAreaCode == "0")
                {
                    MetropolitanStatisticalAreaCode = context.OccupationalEmploymentStatisticsMetro.AsNoTracking()                            
                        .Where(s => s.SOC == CategorySubgroupCode)
                        .OrderBy(s => s.MSACode)
                        .Select(s => s.MSACode)
                        .First();
                }

                metro = context.OccupationalEmploymentStatisticsMetro.AsNoTracking()
                    .Where(s => s.SOC == CategorySubgroupCode)
                    .Where(s => s.MSACode == MetropolitanStatisticalAreaCode)
                    .Where(s => s.AmcosVersionId == AmcosVersionId)
                    .Select(s => new InventoryCCEDto()
                    {
                        Area = s.MetropolitanStatisticalArea.MSAName,
                        TOT_EMP = s.Tot_Emp,
                        EMP_PRSE = s.Emp_Prse
                    })
                    .ToList();

                national = context.OccupationalEmploymentStatisticsNational.AsNoTracking()
                    .Where(s => s.SOC == CategorySubgroupCode)
                    .Select(s => new InventoryCCEDto()
                    {
                        Area = "zzzNational",
                        TOT_EMP = s.Tot_Emp,
                        EMP_PRSE = s.Emp_Prse
                    })
                    .ToList();

                inventory = inventory.Concat(metro).Concat(national).OrderBy(i => i.Area).ToList();
                return inventory;
            }                               
        }
        public DataTable GetInventoryOther()
        {
            // web.getInventory is a function returning (result_set_name, row_data jsonb);
            // StoredFunction unpacks the (dynamic-shape pivot) jsonb into a flat DataTable.
            DataTable inventory = Helpers.StoredFunction.QueryAsTable("web.getInventory",
                new NpgsqlParameter("@PayPlan", PayPlan),
                new NpgsqlParameter("@CategoryGroupCode", CategoryGroupCode),
                new NpgsqlParameter("@CategorySubgroupCode", CategorySubgroupCode),
                new NpgsqlParameter("@AmcosVersionId", AmcosVersionId));
            if (PayPlan != "CCE")
            {
                inventory.Columns.Add(new DataColumn("Total", Type.GetType("System.String")));
            }

            return inventory;
        }
        public DataTable GetInventoryWage()
        {
            DataTable inventory = Helpers.StoredFunction.QueryAsTable("web.GetInventoryWage",
                new NpgsqlParameter("@PayPlan", PayPlan),
                new NpgsqlParameter("@LocationId", LocationId),
                new NpgsqlParameter("@AmcosVersionId", AmcosVersionId));
            inventory.Columns.Add(new DataColumn("Total", Type.GetType("System.String")));

            return inventory;
        }
        public string GetWageScheduleTotal()
        {
            PayPlan payPlan = new PayPlan(PayPlan);
            double inventory = 0;            

            using (var context = new ApplicationDbContext())
            {
                if (LocationId == -1)
                {
                    inventory = context.Inventory.AsNoTracking()
                    .Where(i => i.PayPlan == PayPlan)
                    .Where(i => i.AmcosVersionId == AmcosVersionId)
                    .Sum(i => i.InventoryAmount);
                }
                else
                {
                    inventory = context.Inventory.AsNoTracking()
                    .Where(i => i.PayPlan == PayPlan)
                    .Where(i => i.LocationId == LocationId)
                    .Where(i => i.AmcosVersionId == AmcosVersionId)
                    .Sum(i => i.InventoryAmount);
                }
            }

            return inventory.ToString("#,000");
        }
        public string GetCategoryGroupTotal()
        {
            PayPlan payPlan = new PayPlan(PayPlan);
            double inventory = 0;
            if (PayPlan == "CCE")
            {
                using (var context = new ApplicationDbContext())
                {
                    if (CategoryGroupCode == "-1")
                    {
                        CategoryGroupCode = context.Category.AsNoTracking()
                            .Where(i => i.PayPlan == "CCE")
                            .OrderBy(i => i.CategoryGroupCode)
                            .Select(i => i.CategoryGroupCode)
                            .First();                        
                    }                    
                    inventory = context.OccupationalEmploymentStatisticsMetro.AsNoTracking()
                        .Where(i => i.AmcosVersionId == AmcosVersionId)
                        .Where(o => o.SOC.Substring(0,2) + "-0000" == CategoryGroupCode)
                        .Where(o => o.Tot_Emp > 0)
                        .Sum(o => o.Tot_Emp);            
                }
            }
            else if (payPlan.GetTags().Contains("Wage") && (PayPlan != "CY"))
            {
                using (var context = new ApplicationDbContext())
                {
                    if (LocationId == -1)
                    {
                        inventory = context.Inventory.AsNoTracking()
                        .Where(i => i.PayPlan == PayPlan)
                        .Where(i => i.AmcosVersionId == AmcosVersionId)
                        .Sum(i => i.InventoryAmount);
                    } else
                    {
                        inventory = context.Inventory.AsNoTracking()
                        .Where(i => i.PayPlan == PayPlan)
                        .Where(i => i.LocationId == LocationId)
                        .Where(i => i.AmcosVersionId == AmcosVersionId)
                        .Sum(i => i.InventoryAmount);
                    }                    
                }
            }
            else
            {
                using (var context = new ApplicationDbContext())
                {        
                    inventory = context.Inventory.AsNoTracking()
                        .Where(i => i.PayPlan == PayPlan)
                        .Where(i => i.CategoryGroupCode == CategoryGroupCode || CategoryGroupCode == "-1")
                        .Where(i => i.AmcosVersionId == AmcosVersionId)
                        .Sum(i => i.InventoryAmount);
                }
            }
            return inventory.ToString("#,000");
        }
        public string GetCategorySubgroupTotal()
        {
            double inventory = 0;
            if (PayPlan == "CCE")
            {
                using (var context = new ApplicationDbContext())
                {
                    if (CategorySubgroupCode == "-1")
                    {
                        CategorySubgroupCode = context.Category.AsNoTracking()
                            .Where(i => i.PayPlan == "CCE")
                            .Where(i => i.CategoryGroupCode == CategoryGroupCode)
                            .OrderBy(i => i.CategorySubgroupCode)
                            .Select(i => i.CategorySubgroupCode)
                            .First();
                    }
                    inventory = context.OccupationalEmploymentStatisticsMetro.AsNoTracking()
                        .Where(o => o.SOC == CategorySubgroupCode)
                        .Where(o => o.Tot_Emp > 0)
                        .Where(o => o.AmcosVersionId == AmcosVersionId)
                        .Sum(o => o.Tot_Emp);
                }
            }
            else
            {
                using (var context = new ApplicationDbContext())
                {
                    inventory = context.Inventory.AsNoTracking()
                        .Where(i => i.PayPlan == PayPlan)
                        .Where(i => i.CategoryGroupCode == CategoryGroupCode || CategoryGroupCode == "-1")
                        .Where(i => i.CategorySubgroupCode == CategorySubgroupCode || CategorySubgroupCode == "-1")
                        .Where(i => i.AmcosVersionId == AmcosVersionId)
                        .Sum(i => i.InventoryAmount);
                }
            }
            return inventory.ToString("#,000");
        }
        public string GetPayPlanTotal()
        {
            double inventory = 0;
            if (PayPlan == "CCE")
            {
                using (var context = new ApplicationDbContext())
                {
                    inventory = context.OccupationalEmploymentStatisticsMetro.AsNoTracking()
                        .Where(o => o.Tot_Emp > 0)
                        .Where(o => o.AmcosVersionId == AmcosVersionId)
                        .Sum(c => c.Tot_Emp);
                }
            } else
            {
                using (var context = new ApplicationDbContext())
                {
                    inventory = context.Inventory.AsNoTracking()
                        .Where(i => i.PayPlan == PayPlan)
                        .Where(i => i.AmcosVersionId == AmcosVersionId)
                        .Sum(i => i.InventoryAmount);
                }
            }           
            return inventory.ToString("#,000");
        }
    }
}
