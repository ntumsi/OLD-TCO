using Microsoft.VisualBasic;
using System;
using System.Data;
using Npgsql;
using NpgsqlTypes;
using System.Text.RegularExpressions;
using System.Collections.Generic;
using System.Linq;
using Newtonsoft.Json.Linq;
using System.IO;
using System.Globalization;
using System.Web.UI.WebControls;
using AMCOS.Data.DataTransferObjects;
using AMCOS.Data;
using AMCOS.Data.ViewModels;
using AMCOS.Data.Entities;
using System.Text;

namespace AMCOS.Logic
{
    public class Lite
    {
        public string PayPlan { get; set; }
        public string CostSummaryName { get; set; }
        public string CategoryGroupCode { get; set; }
        public string CategorySubgroupCode { get; set; }
        public string CareerProgramNumber { get; set; }
        public int LocationId { get; set; }
        public string ScienceTechnologyReinventionLaboratory { get; set; }
        public string DependentStatus { get; set; }
        public int NumberOfDependents { get; set; }
        public int LocalityRateId { get; set; }
        public string SpecialRateTableNumber { get; set; }
        public string WageArea { get; set; }
        public float OverheadPercent { get; set; }
        public string StateCountry { get; set; }
        public string FunctionalAreaCode { get; set; }
        public string CostCenterCode { get; set; }
        public string InflationConversionType { get; set; }
        public string InflationYear { get; set; }
        public int AmcosVersionId { get; set; }

        readonly Dictionary<string, string> payPlanType = new Dictionary<string, string>()
        {
            {"AE", "military"},
            {"AO", "military"},
            {"AWO", "military"},
            {"NE", "military"},
            {"NO", "military"},
            {"NWO", "military"},
            {"RE", "military"},
            {"RO", "military"},
            {"RWO","military"},
            {"CCE", "civilian-g/s/c"},
            {"DB", "laboratory demo"},
            {"DE", "laboratory demo"},
            {"DJ", "laboratory demo"},
            {"DK", "laboratory demo"},
            {"AD", "civilian-g/s/c"},
            {"CA", "civilian-g/s/c"},
            {"EE", "civilian-g/s/c"},
            {"EF", "civilian-g/s/c"},
            {"EX", "civilian-g/s/c"},
            {"GG", "civilian-g/s/c"},
            {"GL", "civilian-g/s/c"},
            {"GP", "civilian-g/s/c"},
            {"GS", "civilian-g/s/c"},
            {"IE", "civilian-g/s/c"},
            {"IG", "civilian-g/s/c"},
            {"IP", "civilian-g/s/c"},
            {"SES", "civilian-g/s/c"},
            {"SL", "civilian-g/s/c"},
            {"ST", "civilian-g/s/c"},
            {"ZZ", "civilian-g/s/c"},
            {"NH", "acquisition demo"},
            {"NJ", "acquisition demo"},
            {"NK", "acquisition demo"},
            {"WA", "wage(af)"},
            {"WB", "wage(af)"},
            {"WD", "wage(af)"},
            {"WG", "wage(af)"},
            {"WJ", "wage(af)"},
            {"WK", "wage(af)"},
            {"WL", "wage(af)"},
            {"WN", "wage(af)"},
            {"WO", "wage(af)"},
            {"WQ", "wage(af)"},
            {"WR", "wage(af)"},
            {"WS", "wage(af)"},
            {"WT", "wage(af)"},
            {"WU", "wage(af)"},
            {"WY", "wage(af)"},
            {"XF", "wage(af)"},
            {"XG", "wage(af)"},
            {"XH", "wage(af)"},
            {"XR", "wage(af)"},
            {"XT", "wage(af)"},
            {"XU", "wage(af)"},
            {"CY","wage(naf)"},
            {"NA","wage(naf)"},
            {"NF","wage(naf)"},
            {"NL","wage(naf)"},
            {"NS","wage(naf)"},
        };

        public Lite()
        {
        }
        public Lite(string payPlan)
        {
            PayPlan = payPlan;
        }
        public Lite(string payPlan, string costSummaryName, string categoryGroupCode, string categorySubgroupCode)
        {
            PayPlan = payPlan;
            CostSummaryName = costSummaryName;
            CategoryGroupCode = categoryGroupCode;
            CategorySubgroupCode = categorySubgroupCode;
        }
        //GS
        public Lite(string payPlan, string costSummaryName, string categoryGroupCode, string categorySubgroupCode, int localityRateId, string inflationConversionType, string inflationYear)
        {
            PayPlan = payPlan;
            CostSummaryName = costSummaryName;
            CategoryGroupCode = categoryGroupCode;
            CategorySubgroupCode = categorySubgroupCode;
            LocalityRateId = localityRateId;
            InflationConversionType = inflationConversionType;
            InflationYear = inflationYear;
        }
        public void CreateAvailableCostsObject(int amcosVersionId)
        {
            using (var context = new ApplicationDbContext())
            {
                List<AMCOS.Data.Entities.PayPlan> payPlans = context.PayPlan.ToList();
                List<CostSummary> costSummaries = context.CostSummary.ToList();

                var categoryGroupCodes = context.Costs
                    .Select(costs => new
                    {
                        costs.PayPlan,
                        costs.CategoryGroupCode
                    })
                    .Distinct().ToList();

                var categorySubgroupCodes = context.Costs
                    .Select(costs => new
                    {
                        costs.PayPlan,
                        costs.CategoryGroupCode,
                        costs.CategorySubgroupCode
                    })
                    .Distinct().ToList();

                var locations = context.Costs
                    .Select(costs => new
                    {
                        costs.PayPlan,
                        costs.CategoryGroupCode,
                        costs.CategorySubgroupCode,
                        costs.LocationId
                    })
                    .Distinct().ToList();

                JObject payPlanObject =
                    new JObject(
                        new JProperty("payPlanObject",
                        new JArray(
                            from p in payPlans
                            orderby p.Name
                            select new JObject(
                                new JProperty("payPlanValue", p.Name),
                                new JProperty("payPlanText", p.Description),
                                new JProperty("categoryGroupLabel", p.CategoryGroupLabel),
                                new JProperty("categorySubgroupLabel", p.CategorySubgroupLabel),
                                new JProperty("costSummaries",
                                new JArray(
                                    from c in costSummaries
                                    where c.PayPlan == p.Name
                                    select new JObject(
                                        new JProperty("costSummaryText", c.Name)))),
                                new JProperty("categoryGroups",
                                new JArray(
                                    from g in categoryGroupCodes
                                    where g.PayPlan == p.Name
                                    orderby g.CategoryGroupCode
                                    select new JObject(
                                        new JProperty("categoryGroupValue", g.CategoryGroupCode),
                                        new JProperty("categorySubgroups",
                                        new JArray(
                                            from s in categorySubgroupCodes
                                            where s.PayPlan == g.PayPlan && s.CategoryGroupCode == g.CategoryGroupCode
                                            orderby s.CategorySubgroupCode
                                            select new JObject(
                                                new JProperty("categorySubgroupValue", s.CategorySubgroupCode),
                                                new JProperty("locations",
                                                new JArray(
                                                    from l in locations
                                                    where l.PayPlan == p.Name && l.CategoryGroupCode == g.CategoryGroupCode && l.CategorySubgroupCode == s.CategorySubgroupCode
                                                    orderby l.LocationId
                                                    select new JObject(
                                                        new JProperty("locationId", l.LocationId))))))))))))));

                File.WriteAllText(@"c:\temp\AvailableCosts.js", payPlanObject.ToString());
            }
        }
        public void CreateInflationYearObject(int amcosVersionId)
        {
            using (var context = new ApplicationDbContext())
            {
                var conversionTypes = context.JicInflationRates
                    .Where(c => c.AmcosVersionId == amcosVersionId)
                    .Select(c => new
                    {
                        c.ConversionType
                    })
                    .Distinct().ToList();

                var inflationYears = context.JicInflationRates
                    .Where(c => c.AmcosVersionId == amcosVersionId)
                    .Select(y => new
                    {
                        y.ConversionType,
                        y.Year
                    })
                    .Distinct()
                    .ToList();

                JObject inflationYearObject =
                    new JObject(
                        new JProperty("inflationYearObject",
                        new JArray(
                            from c in conversionTypes
                            select new JObject(
                                new JProperty("conversionType", c.ConversionType),
                                new JProperty("years",
                                new JArray(
                                    from y in inflationYears
                                    where c.ConversionType == y.ConversionType
                                    orderby y.Year
                                    select new JObject(
                                        new JProperty("yearValue", y.Year))))))));

                File.WriteAllText(@"c:\temp\InflationYear.js", inflationYearObject.ToString());
            }
        }
        public void CreatePayPlanJson(int amcosVersionId)
        {
            using (var context = new ApplicationDbContext())
            {
                List<Data.Entities.PayPlan> payPlans = context.PayPlan.AsNoTracking().ToList();
                List<CostSummary> costSummaries = context.CostSummary.AsNoTracking().ToList();

                //Which pay plans have costs for the requested version?
                List<string> payPlansWithCosts = context.Costs.AsNoTracking()
                    .Where(costs => costs.AmcosVersionId == amcosVersionId)
                    .Select(costs => costs.PayPlan)
                    .Distinct().ToList();

                payPlansWithCosts.AddRange(new string[] { "CCE" });

                var categoryGroupsByPayPlan = context.PayPlan.AsNoTracking()
                    .Where(p => p.CategoryGroupLabel != null)
                    .Select(p => new
                    {
                        PayPlan = p.Name,
                        OptGroup = "categoryGroup",
                        Label = p.CategoryGroupLabel
                    });

                var categorySubgroupsByPayPlan = context.PayPlan.AsNoTracking()
                    .Where(p => p.CategorySubgroupLabel != null)
                    .Select(p => new
                    {
                        PayPlan = p.Name,
                        OptGroup = "categorySubgroup",
                        Label = p.CategorySubgroupLabel
                    });

                var careerProgramsByPayPlan = context.PayPlan.AsNoTracking()
                    .Where(p => p.IncludeArmyCareerPrograms == true)
                    .Select(p => new
                    {
                        PayPlan = p.Name,
                        OptGroup = "careerProgram",
                        Label = "Army Career Programs"
                    });

                var categoryOptionGroups = categoryGroupsByPayPlan.Concat(categorySubgroupsByPayPlan).Concat(careerProgramsByPayPlan).ToList();

                JObject payPlanObject = new JObject(
                    new JProperty("payPlanObject", 
                    new JArray(from p in payPlans
                    where payPlansWithCosts.Contains(p.Name)
                    orderby p.Name
                    select new JObject(
                    new JProperty("payPlanValue", p.Name),
                    new JProperty("payPlanText", p.DisplayTitle),
                    new JProperty("categoryOptionGroups", new JArray(from o in categoryOptionGroups
                                                                        where o.PayPlan == p.Name
                                                                        select new JObject(
                                                                        new JProperty("optgroup", o.OptGroup),
                                                                        new JProperty("label", o.Label)))),
                    new JProperty("categoryPlaceholderText", "Make a selection"),
                    new JProperty("costSummaries",
                    new JArray(from c in costSummaries where c.PayPlan == p.Name select new JValue(c.Name))
                    )))));

                File.WriteAllText(@"c:\temp\object-payplan.js", payPlanObject.ToString());
            }
        }
        public void CreatePayPlanOptionList(int amcosVersionId)
        {
            StringBuilder sb = new StringBuilder();
            using (var context = new ApplicationDbContext())
            {
                List<Data.Entities.PayPlan> payPlans = context.PayPlan.AsNoTracking().OrderBy(p => p.DisplaySequence).ToList();
                
                //Which pay plans have costs for the requested version?
                List<string> payPlansWithCosts = context.Costs.AsNoTracking()
                    .Where(costs => costs.AmcosVersionId == amcosVersionId)
                    .Select(costs => costs.PayPlan)
                    .Distinct().ToList();

                payPlansWithCosts.AddRange(new string[] { "CCE" });

                var payPlanGroups = (from g in payPlans
                                     where payPlansWithCosts.Contains(g.Name)
                                     orderby g.DisplaySequence
                                     select g.GroupTitle).Distinct();
                
                foreach (string payPlanGroup in payPlanGroups)
                {
                    sb.AppendLine("<optgroup label=\"" + payPlanGroup + "\">");
                    foreach (var payPlan in payPlans)
                    {
                        if (payPlan.GroupTitle == payPlanGroup)
                        {
                            sb.AppendLine("<option value=\"" + payPlan.Name +"\">" + payPlan.DisplayTitle + "</option>");
                        }
                    }
                    sb.AppendLine("</optgroup>");
                }                
            }
            //< optgroup label = "Military" >
            //< option ></ option >
            //< option value = "AE" > Active Enlisted(AE) </ option >
            //< option value = "AO" > Active Officer(AO) </ option >
            //< option value = "AWO" > Active Warrant Officer(AWO)</ option >
            //< option value = "NE" > National Guard Enlisted(NE)</ option >
            //< option value = "NO" > National Guard Officer(NO)</ option >
            //< option value = "NWO" > National Guard Warrant Officer(NWO) </ option >
            //< option value = "RE" > Reserve Enlisted(RE) </ option >
            //< option value = "RO" > Reserve Officer(RO) </ option >
            //< option value = "RWO" > Reserve Warrant Officer(RWO)</ option >
            //</ optgroup >
            //< optgroup label = "Civilian-G/S/C" >
            //< option value = "CCE" > Contractor Cost Estimate(CCE)</ option >
            //< option value = "SES" > Senior Executive Schedule(SES)</ option >
            //< option value = "GG" > Intelligence Personnel(GG) </ option >
            //< option value = "GL" > Law Enforcement Officers(GL)</ option >
            //< option value = "GP" > Physicians and Dentists(GP)</ option >        
            //< option value = "GS" > General Schedule(GS) </ option >                                                        
            //</ optgroup >                               
            //< optgroup label = "Laboratory Demo" >        
            //< option value = "DB" > Engineers & Scientists(DB) </ option >
            //< option value = "DE" > Engineer & Scientist Technicians(DE) </ option >                      
            //< option value = "DJ" > Administrative(DJ) </ option >                      
            //< option value = "DK" > General Support(DK) </ option >                                                                     
            //</ optgroup >                                           
            //< optgroup label = "Acquisition Demo" >
            //< option value = "NH" > Business and Technical Management Professionals(NH)</ option >
            //< option value = "NJ" > Technical Management Support(NJ)</ option >                            
            //< option value = "NK" > Administration Support(NK) </ option >                                                                                                
            //</ optgroup >
            //< optgroup label = "Wage" >
            //< option value = "WA" > Lock & Dam Supervisor(WA) </ option >
            //< option value = "WB" > Wage not otherwise designated(WB) </ option >
            //< option value = "WD" > Production Facility Grade(WD)</ option >
            //< option value = "WG" > Wage Grade(WG) </ option >
            //< option value = "WJ" > Hopper Dredge(WJ) </ option >
            //< option value = "WK" > Hopper Dredge - nonsupervisory(WK) </ option >
            //< option value = "WL" > Wage Leader(WL) </ option >
            //< option value = "WN" > Production Facility Supervisor(WN)</ option >
            //< option value = "WO" > Lock & Dam Leader(WO) </ option >
            //< option value = "WS" > Wage Supervisor(WS) </ option >
            //< option value = "WT" > Trainees(WT) </ option >
            //< option value = "XF" > Floating Plant Grade(XF)</ option >
            //< option value = "XG" > Floating Plant Leader(XG)</ option >
            //< option value = "XH" > Floating Plant Supervisor(XH)</ option >
            //< option value = "XR" > Flood Control Grade(XR)</ option >
            //< option value = "XT" > Flood Control Leader(XT)</ option >
            //</ optgroup >

            File.WriteAllText(@"c:\temp\PayPlanOptionList.txt", sb.ToString());
        }
        public List<string> GetArmyCesTitles(string payPlan, string costSummaryName)
        {
            using (var context = new ApplicationDbContext())
            {
                var query = context.CostSummary.AsNoTracking()
                    .Where(c => c.PayPlan == payPlan)
                    .Where(c => c.Name == costSummaryName)
                    .Select(c => new { c.SummaryId })
                    .Single();
                int costSummaryId = query.SummaryId;
                return context.CostSummaryElement
                    .Where(c => c.CostElement.ArmyCesTitle != null)
                    .Where(c => c.CostElement.PayPlan == payPlan && c.SummaryId == costSummaryId)
                    .OrderBy(c => c.CostElement.ArmyCesTitle)
                    .Select(c => c.CostElement.ArmyCesTitle)
                    .Distinct().ToList();
            }
        }                
        public DataSet GetCosts(string userId)
        {
            DataSet ds = new DataSet();
            string[] parameterNames = new string[] { "@PayPlan", "@CostSummaryName", "@CategoryGroupCode", "@CategorySubgroupCode", "@CareerProgramNumber", "@LocationId", "@STRL", "@DependentStatus", "@NumberOfDependents", "@InflationConversion", "@InflationYear", "@AmcosVersionId" };
            NpgsqlDbType[] parameterTypes = new NpgsqlDbType[] { NpgsqlDbType.Text, NpgsqlDbType.Text, NpgsqlDbType.Text, NpgsqlDbType.Text, NpgsqlDbType.Integer, NpgsqlDbType.Integer, NpgsqlDbType.Text, NpgsqlDbType.Text, NpgsqlDbType.Integer, NpgsqlDbType.Text, NpgsqlDbType.Text, NpgsqlDbType.Integer };
            object[] parameterValues = new object[] {PayPlan,CostSummaryName,CategoryGroupCode,CategorySubgroupCode,CareerProgramNumber,LocationId,ScienceTechnologyReinventionLaboratory,DependentStatus,NumberOfDependents,InflationConversionType,InflationYear,AmcosVersionId };
            try
            {
                ds = DataAccessUtility.ExecuteStoredProcDataSet("web.GetAmcosLiteCosts", parameterNames, parameterTypes, parameterValues);
            }
            catch (Exception ex)
            {
                LogHelper logHelper = new LogHelper();
                logHelper.LogError(ex.Message, userId);
                throw;
            }
            return ds;
        }
        public DataTable GetCostTableWithOrder(string costSummaryName, DataTable costTable) {

            if (costSummaryName == null)
            {
                throw new ArgumentNullException("costSummaryName");
            }

            if (costTable == null)
            {
                throw new ArgumentNullException("costTable");
            }

            int maxShowOrder;

            if (costSummaryName == "Weapon System Manpower" && PayPlan.StartsWith("A"))
            {
                //Add subtotal for Weapon System Manpower
                DataRow rowWeaponSystemManpowerTotal = costTable.NewRow();
                for (int columnNumber = 0; columnNumber <= costTable.Columns.Count - 1; columnNumber++)
                {
                    if (costTable.Columns[columnNumber].ColumnName == "ShowOrder")
                    {
                        if (System.DBNull.Value.Equals(costTable.Compute("max(ShowOrder)", "APPN <> 'Federal OM'")))
                            maxShowOrder = 100000;
                        else
                            maxShowOrder = Convert.ToInt32(costTable.Compute("max(ShowOrder)", "APPN <> 'Federal OM'"));
                        rowWeaponSystemManpowerTotal[columnNumber] = 1 + maxShowOrder;
                    }
                    else if (!Information.IsNumeric(Regex.Replace(costTable.Columns[columnNumber].ColumnName, "[^0-9.]", "")))
                    {
                        rowWeaponSystemManpowerTotal[columnNumber] = "";
                        if (costTable.Columns[columnNumber].ColumnName == "Cost Element Name")
                            rowWeaponSystemManpowerTotal[columnNumber] = "WEAPON SYSTEM MANPOWER Total";
                    }
                    else
                        rowWeaponSystemManpowerTotal[columnNumber] = costTable.Compute("sum([" + costTable.Columns[columnNumber].ColumnName + "])", "APPN <> 'Federal OM'");
                }               
                costTable.Rows.Add(rowWeaponSystemManpowerTotal);

                // Add subtotal for Federal OM
                // TODO Fix to specify the appropriation group instead of checking for cost element name equal null
                if (costTable.Select("APPN = 'Federal OM'").Length > 0)
                {
                    DataRow rowFederalOMTotal = costTable.NewRow();
                    for (int columnNumber = 0; columnNumber <= (costTable.Columns.Count - 1); columnNumber++)
                    {
                        if (costTable.Columns[columnNumber].ColumnName == "ShowOrder")
                        {
                            if (System.DBNull.Value.Equals(costTable.Compute("max(ShowOrder)", "")))
                                maxShowOrder = 100000;
                            else
                                maxShowOrder = (int)costTable.Compute("max(ShowOrder)", "");                                
                            
                            rowFederalOMTotal[columnNumber] = 1 + maxShowOrder;
                        }
                        else if (!Information.IsNumeric(Regex.Replace(costTable.Columns[columnNumber].ColumnName, "[^0-9.]", "")))
                        {
                            rowFederalOMTotal[columnNumber] = "";
                            if (costTable.Columns[columnNumber].ColumnName == "Cost Element Name")
                                rowFederalOMTotal[columnNumber] = "FEDERAL OM Total";
                        }
                        else
                            rowFederalOMTotal[columnNumber] = costTable.Compute("sum([" + costTable.Columns[columnNumber].ColumnName + "])", "APPN = 'Federal OM'");
                    }
                    costTable.Rows.Add(rowFederalOMTotal);
                }
            }
   
            // Add total line at bottom for all summaries except Ancillary
            if (costSummaryName != "Ancillary") {
                DataRow rowTotal = costTable.NewRow();
                for (int columnNumber = 0; columnNumber <= (costTable.Columns.Count - 1); columnNumber++) {
                    if (costTable.Columns[columnNumber].ColumnName == "ShowOrder")
                    {
                        if (System.DBNull.Value.Equals(costTable.Compute("max(ShowOrder)", "")))
                            maxShowOrder = 100000;
                        else
                            maxShowOrder = (int)costTable.Compute("max(ShowOrder)", "");

                        rowTotal[columnNumber] = 2 + maxShowOrder;
                    }
                    else if (!Information.IsNumeric(Regex.Replace(costTable.Columns[columnNumber].ColumnName, "[^0-9.]", "")) && !(costTable.Columns[columnNumber].ColumnName == "MIN") && !(costTable.Columns[columnNumber].ColumnName == "AVG") && !(costTable.Columns[columnNumber].ColumnName == "MAX"))
                    {
                        rowTotal[columnNumber] = DBNull.Value;
                        if (costTable.Columns[columnNumber].ColumnName == "Cost Element Name")
                            rowTotal[columnNumber] = "Total";
                    }
                    else
                        rowTotal[columnNumber] = costTable.Compute("sum([" + costTable.Columns[columnNumber].ColumnName + "])", "[Cost Element Name] not like '%Total'");
                }
                costTable.Rows.Add(rowTotal);
            }

            costTable.AcceptChanges();
            return costTable;
        }

        public DataSet Costs(string categorySubgroupCode, string metroAreaCode, string overheadPercent, int amcosVersionId)
        {
            DataSet ds = new DataSet();

            switch (PayPlan)
            {
                case "CCE":
                    string sqlStatement = "SELECT * FROM web.costsCCE(@StandardOccupationCode, @Area, @OverheadPercent, @AmcosVersionId);";
                    using (NpgsqlConnection connection = new NpgsqlConnection(AppConfiguration.GetConnectionString()))
                    {
                        connection.Open();
                        NpgsqlDataAdapter adapter = new NpgsqlDataAdapter();
                        using (NpgsqlCommand command = new NpgsqlCommand(sqlStatement, connection))
                        {
                            command.Parameters.AddWithValue("@StandardOccupationCode", categorySubgroupCode);
                            command.Parameters.AddWithValue("@Area", metroAreaCode);
                            command.Parameters.AddWithValue("@OverheadPercent", Single.Parse(overheadPercent));
                            command.Parameters.AddWithValue("@AmcosVersionId", amcosVersionId);
                            command.CommandType = CommandType.Text;
                            adapter.SelectCommand = command;
                            adapter.Fill(ds);
                        }
                    }
                    return ds;
                default:
                    return ds;
            }
        }
        public DataSet Costs(string categoryGroupCode, string categorySubgroupCode, int locationId, Single overheadPercent, string inflationConversion, string inflationYear, int amcosVersionId)
        {
            DataSet ds = new DataSet();

            switch (PayPlan)
            {
                case "CCE":
                    string standardOccupationCode = "";
                    string sqlStatement = "SELECT * FROM web.costsCCEInflated(@StandardOccupationCode, @LocationId, @OverheadPercent, @InflationConversion, @InflationYear, @AmcosVersionId);";
                    if (categorySubgroupCode == "-1")
                    {
                        standardOccupationCode = categoryGroupCode;
                    }
                    else
                    {
                        standardOccupationCode = categorySubgroupCode;
                    }

                    using (NpgsqlConnection connection = new NpgsqlConnection(AppConfiguration.GetConnectionString()))
                    {
                        connection.Open();
                        NpgsqlDataAdapter adapter = new NpgsqlDataAdapter();
                        using (NpgsqlCommand command = new NpgsqlCommand(sqlStatement, connection))
                        {
                            command.Parameters.AddWithValue("@StandardOccupationCode", standardOccupationCode);
                            command.Parameters.AddWithValue("@LocationId", locationId);
                            command.Parameters.AddWithValue("@OverheadPercent", overheadPercent);
                            command.Parameters.AddWithValue("@InflationConversion", inflationConversion);
                            command.Parameters.AddWithValue("@InflationYear", inflationYear);
                            command.Parameters.AddWithValue("@AmcosVersionId", amcosVersionId);
                            command.CommandType = CommandType.Text;
                            adapter.SelectCommand = command;
                            adapter.Fill(ds);
                        }
                    }
                    return ds;
                default:
                    return ds;
                    
            }
            
        }
        public IEnumerable<ListItem> GetGradeLevels(string payPlan, string categoryGroupCode, string categorySubgroupCode = "", string stateCountry = "__ALL__", string functionalAreaCode = "__ALL__", string costCenterCode = "__ALL__")
        {
            DataTable gradeLevelsTable = new DataTable("GradeLevels")
            {
                Locale = CultureInfo.InvariantCulture
            };

            DataColumn textColumn = new DataColumn
            {
                DataType = Type.GetType("System.String"),
                ColumnName = "Text"
            };
            gradeLevelsTable.Columns.Add(textColumn);
            textColumn.Dispose();

            DataColumn valueColumn = new DataColumn
            {
                DataType = Type.GetType("System.String"),
                ColumnName = "Value"
            };
            gradeLevelsTable.Columns.Add(valueColumn);
            valueColumn.Dispose();

            DataRow row;

            //TODO improve performance

            using (var context = new ApplicationDbContext())
            {
                var allCosts = context.Costs
                    .Where(c => c.PayPlan == payPlan);
                if (categoryGroupCode != "__ALL__")
                    allCosts = allCosts.Where(c => c.CategoryGroupCode == categoryGroupCode);
                if (categorySubgroupCode != "__ALL__" && !(String.IsNullOrEmpty(categorySubgroupCode)))
                    allCosts = allCosts.Where(c => c.CategorySubgroupCode == categorySubgroupCode);
                var gradeLevels = allCosts.Select(g => new { g.GradeLevel }).Distinct();

                //        var gradeLevels = Costs
                //.Where(whereClause)
                //.Select(c => new { c.GradeLevel });

                //string whereClause = "(PayPlan == @0)";

                //if (categoryGroupCode != "__ALL__")
                //    whereClause += " AND (CategoryGroupCode == @1)";
                //if (categorySubgroupCode != "__ALL__" && !(String.IsNullOrEmpty(categorySubgroupCode)))
                //    whereClause += " AND (CategorySubgroupCode == @2)";
                //if (stateCountry != "__ALL__")
                //    whereClause += " AND (StateCountry == @3)";
                //if (functionalAreaCode != "__ALL__")
                //    whereClause += " AND (FunctionalAreaCode == @4)";
                //if (costCenterCode != "__ALL__")
                //    whereClause += " AND (CostCenterCode == @5)";

                switch (payPlan)
                {
                    case "AE":
                    case "NE":
                    case "RE":
                        gradeLevels = gradeLevels.OrderBy(g => g.GradeLevel).ToList().AsQueryable();
                        return (from g in gradeLevels
                                select new ListItem()
                                {
                                    Text = "E" + g.GradeLevel.ToString(),
                                    Value = g.GradeLevel.ToString()
                                }).Distinct().ToList();
                    case "AO":
                    case "NO":
                    case "RO":
                        gradeLevels = gradeLevels.OrderBy(g => g.GradeLevel).ToList().AsQueryable();
                        return (from g in gradeLevels
                                select new ListItem()
                                {
                                    Text = "O" + g.GradeLevel.ToString(),
                                    Value = g.GradeLevel.ToString()
                                }).Distinct().ToList();
                    case "AWO":
                    case "NWO":
                    case "RWO":
                        gradeLevels = gradeLevels.OrderBy(g => g.GradeLevel).ToList().AsQueryable();
                        return (from g in gradeLevels
                                select new ListItem()
                                {
                                    Text = "WO" + g.GradeLevel.ToString(),
                                    Value = g.GradeLevel.ToString()
                                }).Distinct().ToList();
                    case "GG":
                    case "GL":
                    case "GS":
                        gradeLevels = gradeLevels.OrderBy(g => g.GradeLevel).ToList().AsQueryable();
                        return (from g in gradeLevels
                                select new ListItem()
                                {
                                    Text = payPlan + g.GradeLevel.ToString(),
                                    Value = g.GradeLevel.ToString()
                                }).Distinct().ToList();
                    case "DB":
                    case "DE":
                    case "DJ":
                    case "DK":
                    case "GP":
                    case "NH":
                    case "NJ":
                    case "NK":
                        var list = from g in gradeLevels
                                   group g by g.GradeLevel into distinctGrades
                                   orderby distinctGrades.Min(g => g.GradeLevel)
                                   select new
                                   {
                                       GradeLevel = distinctGrades.Key
                                   };


                        //var list = gradeLevels.GroupBy(g => g.GradeLevel)
                        //    .OrderBy(g => g.GradeLevel)
                        //    .Select(g => new { g.GradeLevel });

                        return (from l in list
                                select new ListItem()
                                {
                                    Text = payPlan + l.GradeLevel.ToString(),
                                    Value = l.GradeLevel.ToString()
                                }).Distinct().ToList();
                    case "WG":
                    case "WL":
                    case "WS":
                        gradeLevels = gradeLevels.OrderBy(g => g.GradeLevel).ToList().AsQueryable();
                        return (from g in gradeLevels
                                select new ListItem()
                                {
                                    Text = payPlan + g.GradeLevel.ToString(),
                                    Value = g.GradeLevel.ToString()
                                }).Distinct().ToList();
                    case "CCE":
                        row = gradeLevelsTable.NewRow();
                        row["Value"] = "1";
                        row["Text"] = "A_PCT10";
                        gradeLevelsTable.Rows.Add(row);

                        row = gradeLevelsTable.NewRow();
                        row["Value"] = "2";
                        row["Text"] = "A_PCT25";
                        gradeLevelsTable.Rows.Add(row);

                        row = gradeLevelsTable.NewRow();
                        row["Value"] = "3";
                        row["Text"] = "A_MEDIAN";
                        gradeLevelsTable.Rows.Add(row);

                        row = gradeLevelsTable.NewRow();
                        row["Value"] = "4";
                        row["Text"] = "A_PCT75";
                        gradeLevelsTable.Rows.Add(row);

                        row = gradeLevelsTable.NewRow();
                        row["Value"] = "5";
                        row["Text"] = "A_PCT90";
                        gradeLevelsTable.Rows.Add(row);

                        return gradeLevelsTable.AsEnumerable().Select(myRow => new ListItem()
                        {
                            Text = myRow["Text"].ToString(),
                            Value = myRow["Value"].ToString()
                        });
                    case "SES":
                        row = gradeLevelsTable.NewRow();
                        row["Text"] = "MIN";
                        row["Value"] = "1";
                        gradeLevelsTable.Rows.Add(row);

                        row = gradeLevelsTable.NewRow();
                        row["Text"] = "AVG";
                        row["Value"] = "2";
                        gradeLevelsTable.Rows.Add(row);

                        row = gradeLevelsTable.NewRow();
                        row["Text"] = "MAX";
                        row["Value"] = "3";
                        gradeLevelsTable.Rows.Add(row);

                        return gradeLevelsTable.AsEnumerable().Select(myRow => new ListItem()
                        {
                            Text = myRow["Text"].ToString(),
                            Value = myRow["Value"].ToString()
                        });
                    default:
                        return (from g in gradeLevels
                                select new ListItem()
                                {
                                    Text = g.GradeLevel.ToString(),
                                    Value = g.GradeLevel.ToString()
                                }).Distinct().OrderBy(l => l.Text).ToList();
                }
            }
        }
        public IEnumerable<ListItem> GetLocalityListWithSpecialPayLocations(string occupationalSeriesNumber)
        {
            using (var context = new ApplicationDbContext())
            {
                IQueryable<int> innerquery = from s in context.OPMSpecialRate
                                             where s.OccupationalSeriesNumber == occupationalSeriesNumber
                                             group s by s.LocalityId into sg
                                             select sg.Key;

                return (from lr in context.LocalityRates1
                        where (lr.SortOrder == 1) || (lr.SortOrder == 2) || (innerquery.Contains(lr.LocalityId))
                        orderby lr.SortOrder, lr.LocalityDescription
                        select new ListItem()
                        {
                            Text = lr.LocalityDescription,
                            Value = lr.LocalityId.ToString()
                        }).Distinct().ToList();
            }
        }
        public IEnumerable<ListItem> GetLocalityPayAreas()
        {
            using (var context = new ApplicationDbContext())
            {
                return (from l in context.LocalityRates
                        where (l.Id == l.LocalityId) && (l.Amount > 0)
                        select new ListItem()
                        {
                            Text = l.Description,
                            Value = l.Id.ToString()
                        }).OrderBy(l => l.Text).ToList();
            }
        }
        public IEnumerable<ListItem> GetLocationAndLocalityPayAreas()
        {
            using (var context = new ApplicationDbContext())
            {
                return (from l in context.LocalityRates
                        select new ListItem()
                        {
                            Text = l.Description,
                            Value = l.Id.ToString()
                        }).OrderBy(l => l.Text).ToList();
            }
        }
        public List<LocationDto> GetMilitaryInstallations()
        {
            List<LocationDto> options = new List<LocationDto>();
            IEnumerable<LocationDto> installations = null;

            using (var context = new ApplicationDbContext())
            {
                installations = context.Locations.AsNoTracking()
                    .Where(p => (p.LocationType == "Military Installation"))
                    .AsEnumerable()
                    .Select(p => new LocationDto()
                    {
                        Value = string.Format("{0}.{1}", p.LocationId, "installation"),
                        OptionGroup = "installation",
                        Text = p.DisplayName
                    })
                    .Distinct();

                if (installations != null)
                {
                    options = options.Concat(installations).ToList();
                }
                return options;
            }
        }
        public List<GradeLevelDto> GetOptionListGradeLevel(string payPlan, string categoryGroupCode, string categorySubgroupCode, string careerProgramNumber, int locationId, int amcosVersionId)
        {
            using (var context = new ApplicationDbContext())
            {
                var gradeLevelList = context.Costs.AsNoTracking()
                    .Where(p => p.PayPlan == payPlan)
                    .Where(p => p.CategoryGroupCode == categoryGroupCode)
                    .Where(p => p.CategorySubgroupCode == categorySubgroupCode)
                    .Where(p => p.CareerProgramNumber == careerProgramNumber)
                    .Where(p => p.LocationId == locationId)
                    .Where(p => p.AmcosVersionId == amcosVersionId)
                    .Select(p => new GradeLevelDto()
                    {
                        Value = p.GradeLevel,
                        Text = p.GradeLevel.ToString()
                    })
                    .Distinct()
                    .ToList();
                switch (payPlan)
                {
                    case "SES":
                        string[] sesGrades = { "Min", "Avg", "Max" };
                        for (int i=0; i < gradeLevelList.Count(); i++)
                        {                            
                            gradeLevelList[i].Text = sesGrades[Int32.Parse(gradeLevelList[i].Text) - 1];
                        }
                        break;
                    case "CCE":
                        string[] cceGrades = { "A_PCT10", "A_PCT25", "A_MEDIAN", "A_PCT75", "A_PCT90" };
                        for (int i = 0; i < gradeLevelList.Count(); i++)
                        {
                            gradeLevelList[i].Text = cceGrades[Int32.Parse(gradeLevelList[i].Text) - 1];
                        }
                        break;
                }
                return gradeLevelList;
            }
        }
        public List<CategoryDto> GetOptionListCategory(string payPlan)
        {
            if (payPlan == null)
            {
                throw new ArgumentNullException(nameof(payPlan));
            }

            switch (payPlanType[payPlan])
            {
                case "military":
                    return GetOptionListCategory(payPlan, false, true);
                case "civilian-g/s/c":
                    if (payPlan == "CCE")
                    {
                        return GetOptionListCategory(payPlan, false, false);
                    }
                    else
                    {
                        return GetOptionListCategory(payPlan, true, true);
                    }
                case "laboratory demo":
                    return GetOptionListCategory(payPlan, true, true);
                case "acquisition demo":
                    return GetOptionListCategory(payPlan, true, true);
                case "wage(af)":
                case "wage(naf)":
                    return GetOptionListCategory(payPlan, false, true);
                default:
                    return GetOptionListCategory(payPlan, false, true);
            }
        }
        private List<CategoryDto> GetOptionListCategory(string payPlan, bool includeCareerPrograms, bool includeAllOption)
        {
            IEnumerable<CategoryDto> allOption = null;
            IEnumerable<CategoryDto> categoryGroups = null;
            IEnumerable<CategoryDto> categorySubgroups = null;
            IEnumerable<CategoryDto> careerPrograms = null;

            using (var context = new ApplicationDbContext())
            {
                allOption = new List<CategoryDto>
                {
                    new CategoryDto() { Value = "-1", OptionGroup = "categoryGroup", Text = "All" }
                };

                categoryGroups = context.Category.AsNoTracking()
                    .Where(p => p.PayPlan == payPlan && p.CategoryGroupDisplay != null)
                    .Select(p => new CategoryDto()
                    {
                        Value = p.CategoryGroupCode,
                        OptionGroup = "categoryGroup",
                        Text = p.CategoryGroupDisplay
                    })
                    .Distinct();

                categorySubgroups = context.Category.AsNoTracking()
                    .Where(p => p.PayPlan == payPlan && p.CategorySubgroupDisplay != null)
                    .Select(p => new CategoryDto()
                    {
                        Value = p.CategorySubgroupCode,
                        OptionGroup = "categorySubgroup",
                        Text = p.CategorySubgroupDisplay
                    })
                    .Distinct();

                careerPrograms = context.Category.AsNoTracking()
                    .Where(p => p.PayPlan == payPlan && p.CareerProgramDisplay != null)
                    .Select(p => new CategoryDto()
                    {
                        Value = p.CareerProgramNumber,
                        OptionGroup = "careerProgram",
                        Text = p.CareerProgramDisplay
                    })
                    .Distinct();

                if (includeAllOption)
                {
                    if (includeCareerPrograms)
                    {
                        return allOption.Concat(categoryGroups).Concat(categorySubgroups).Concat(careerPrograms).ToList();
                    }
                    else
                    {
                        return allOption.Concat(categoryGroups).Concat(categorySubgroups).ToList();
                    }
                }
                else
                {
                    if (includeCareerPrograms)
                    {
                        return categoryGroups.Concat(categorySubgroups).Concat(careerPrograms).ToList();
                    }
                    else
                    {
                        return categoryGroups.Concat(categorySubgroups).ToList();
                    }
                }                
            }
        }
        public List<LocationDto> GetOptionListLocation(string payPlan, string categoryGroupCode, string categorySubgroupCode, string armyCareerProgramNumber = "-1")
        {
            if (string.IsNullOrEmpty(payPlan))
            {
                throw new ArgumentException("message", nameof(payPlan));
            }

            if (string.IsNullOrEmpty(categoryGroupCode))
            {
                throw new ArgumentException("message", nameof(categoryGroupCode));
            }

            if (string.IsNullOrEmpty(categorySubgroupCode))
            {
                throw new ArgumentException("message", nameof(categorySubgroupCode));
            }

            List<string> optionGroups = new List<string>();

            switch (payPlanType[payPlan])
            {
                case "military":
                    optionGroups.Add("installation");
                    optionGroups.Add("mha-conus");
                    optionGroups.Add("mha-oconus");
                    return GetOptionListLocation(payPlan, categoryGroupCode, categorySubgroupCode, armyCareerProgramNumber, optionGroups, true);
                case "wage(af)":
                case "wage(naf)":
                    if (payPlan == "CY")
                    {
                        optionGroups.Add("installation");
                        optionGroups.Add("localityPayArea");
                    } else
                    {
                        optionGroups.Add("installation");
                        optionGroups.Add("wageSchedule");
                        optionGroups.Add("cityCounty");
                    }
                    if (payPlan == "WG" || payPlan == "WL" || payPlan == "WS")
                    {
                        optionGroups.Add("civilianOverseasArea");
                    }
                    return GetOptionListLocation(payPlan, categoryGroupCode, categorySubgroupCode, armyCareerProgramNumber, optionGroups, true);
                case "acquisition demo":
                    optionGroups.Add("installation");
                    optionGroups.Add("localityPayArea");
                    optionGroups.Add("gfebsCountry");
                    return GetOptionListLocation(payPlan, categoryGroupCode, categorySubgroupCode, armyCareerProgramNumber, optionGroups, true);
                case "laboratory demo":
                    optionGroups.Add("installation");
                    optionGroups.Add("localityPayArea");
                    optionGroups.Add("gfebsCountry");
                    return GetOptionListLocation(payPlan, categoryGroupCode, categorySubgroupCode, armyCareerProgramNumber, optionGroups, true);
                case "civilian-g/s/c":
                    bool includeAllOption = true;
                    optionGroups.Add("installation");
                    if (payPlan == "GG" || payPlan == "GS" || payPlan == "SES")
                    {
                        optionGroups.Add("civilianOverseasArea");
                    }
                    if (payPlan != "CCE")
                    {
                        optionGroups.Add("localityPayArea");
                    }
                    if (payPlan != "GG" || payPlan != "AD")
                    {
                        optionGroups.Add("specialPayArea");
                    }
                    if (payPlan == "GP" || payPlan== "AD" || payPlan == "ZZ")
                    {
                        optionGroups.Add("gfebsCountry");
                    }
                    if (payPlan == "CCE")
                    {
                        optionGroups.Add("metropolitanStatisticalArea");
                        includeAllOption = false;
                    }                    
                    return GetOptionListLocation(payPlan, categoryGroupCode, categorySubgroupCode, armyCareerProgramNumber, optionGroups, includeAllOption);
                default:
                    optionGroups.Add("installation");
                    optionGroups.Add("mha-conus");
                    optionGroups.Add("mha-oconus");
                    return GetOptionListLocation(payPlan, categoryGroupCode, categorySubgroupCode, armyCareerProgramNumber, optionGroups, true);
            }
        }
        private List<LocationDto> GetOptionListLocation(string payPlan, string categoryGroupCode, string categorySubgroupCode, string armyCareerProgramNumber, List<string> optionGroups, bool includeAllOption)
        {
            List<LocationDto> options = new List<LocationDto>();
            IEnumerable<LocationDto> installations = null;
            IEnumerable<LocationDto> conusMilitaryHousingAreas = null;
            IEnumerable<LocationDto> oconusMilitaryHousingAreas = null;
            IEnumerable<LocationDto> localityPayAreas = null;
            IEnumerable<LocationDto> specialPayAreas = null;
            IEnumerable<LocationDto> wageSchedules = null;
            IEnumerable<LocationDto> cityCounties = null;
            IEnumerable<LocationDto> gfebsCountries = null;
            IEnumerable<LocationDto> metropolitanStatisticalAreas = null;
            IEnumerable<LocationDto> civilianOverseasAreas = null;

            using (var context = new ApplicationDbContext())
            {
                if (includeAllOption)
                {
                    if (payPlan == "SES")
                    {
                        options.Add(new LocationDto() { Value = "-1.-1", OptionGroup = "all", Text = "CONUS" });
                    } else
                    {
                        options.Add(new LocationDto() { Value = "-1.-1", OptionGroup = "all", Text = "All" });
                    }
                }

                if (optionGroups.Contains("installation"))
                {
                    installations = context.LocationByCategory.AsNoTracking()
                        .Where(p => (p.PayPlan == payPlan)) 
                        .Where(p => (p.CategoryGroupCode == categoryGroupCode))
                        .Where(p => (p.CategorySubgroupCode == categorySubgroupCode))
                        .Where(p => (p.CareerProgramNumber == armyCareerProgramNumber))
                        .Where(p => (p.Installation != null))
                        .AsEnumerable()
                        .Select(p => new LocationDto()
                        {
                            Value = string.Format("{0}.{1}.{2}", p.LocationId, p.Id, "installation"),
                            OptionGroup = "installation",
                            Text = p.Installation
                        })
                        .Distinct();
                }
                if (optionGroups.Contains("mha-conus"))
                {
                    conusMilitaryHousingAreas = context.LocationByCategory.AsNoTracking()                    
                        .Where(p => (p.PayPlan == payPlan))
                        .Where(p => (p.CategoryGroupCode == categoryGroupCode))
                        .Where(p => (p.CategorySubgroupCode == categorySubgroupCode))
                        .Where(p => (p.CareerProgramNumber == armyCareerProgramNumber))
                        .Where(p => (p.ConusMHA != null))
                        .AsEnumerable()
                        .Select(p => new LocationDto()
                        {
                            Value = string.Format("{0}.{1}.{2}", p.LocationId, p.Id, "mha-conus"),
                            OptionGroup = "mha-conus",
                            Text = p.ConusMHA
                        })
                        .Distinct();
                }
                if (optionGroups.Contains("mha-oconus"))
                {
                    oconusMilitaryHousingAreas = context.LocationByCategory.AsNoTracking()
                        .Where(p => (p.PayPlan == payPlan))
                        .Where(p => (p.CategoryGroupCode == categoryGroupCode))
                        .Where(p => (p.CategorySubgroupCode == categorySubgroupCode))
                        .Where(p => (p.CareerProgramNumber == armyCareerProgramNumber))
                        .Where(p => (p.OconusMHA != null))
                        .AsEnumerable()
                        .Select(p => new LocationDto()
                        {
                            Value = string.Format("{0}.{1}.{2}", p.LocationId, p.Id, "mha-oconus"),
                            OptionGroup = "mha-oconus",
                            Text = p.OconusMHA
                        })
                        .Distinct();
                }
                if (optionGroups.Contains("localityPayArea"))
                {
                    localityPayAreas = context.LocationByCategory.AsNoTracking()
                        .Where(p => (p.PayPlan == payPlan))
                        .Where(p => (p.CategoryGroupCode == categoryGroupCode))
                        .Where(p => (p.CategorySubgroupCode == categorySubgroupCode))
                        .Where(p => (p.CareerProgramNumber == armyCareerProgramNumber))
                        .Where(p => (p.LocalityPayArea != null))
                        .AsEnumerable()
                        .Select(p => new LocationDto()
                        {
                            Value = string.Format("{0}.{1}.{2}", p.LocationId, p.Id, "localityPayArea"),
                            OptionGroup = "localityPayArea",
                            Text = p.LocalityPayArea
                        })
                        .Distinct();
                }
                if (optionGroups.Contains("specialPayArea"))
                {
                    specialPayAreas = context.LocationByCategory.AsNoTracking()
                        .Where(p => (p.PayPlan == payPlan))
                        .Where(p => (p.CategoryGroupCode == categoryGroupCode))
                        .Where(p => (p.CategorySubgroupCode == categorySubgroupCode))
                        .Where(p => (p.CareerProgramNumber == armyCareerProgramNumber))
                        .Where(p => (p.SpecialPayArea != null))
                        .AsEnumerable()
                        .Select(p => new LocationDto()
                        {
                            Value = string.Format("{0}.{1}.{2}", p.LocationId, p.Id, "specialPayArea"),
                            OptionGroup = "specialPayArea",
                            Text = p.SpecialPayArea
                        })
                        .Distinct();
                }
                if (optionGroups.Contains("wageSchedule"))
                {
                    wageSchedules = context.LocationByCategory.AsNoTracking()
                        .Where(p => (p.PayPlan == payPlan))
                        .Where(p => (p.CategoryGroupCode == categoryGroupCode))
                        .Where(p => (p.CategorySubgroupCode == categorySubgroupCode))
                        .Where(p => (p.CareerProgramNumber == armyCareerProgramNumber))
                        .Where(p => (p.WageSchedule != null))
                        .AsEnumerable()
                        .Select(p => new LocationDto()
                        {
                            Value = string.Format("{0}.{1}.{2}", p.LocationId, p.Id, "wageSchedule"),
                            OptionGroup = "wageSchedule",
                            Text = p.WageSchedule
                        })
                        .Distinct();
                }
                if (optionGroups.Contains("cityCounty"))
                {
                    cityCounties = context.LocationByCategory.AsNoTracking()
                        .Where(p => (p.PayPlan == payPlan))
                        .Where(p => (p.CategoryGroupCode == categoryGroupCode))
                        .Where(p => (p.CategorySubgroupCode == categorySubgroupCode))
                        .Where(p => (p.CareerProgramNumber == armyCareerProgramNumber))
                        .Where(p => (p.CityCounty != null))
                        .AsEnumerable()
                        .Select(p => new LocationDto()
                        {
                            Value = string.Format("{0}.{1}.{2}", p.LocationId, p.Id, "cityCounty"),
                            OptionGroup = "cityCounty",
                            Text = p.CityCounty
                        })
                        .Distinct();
                }
                if (optionGroups.Contains("gfebsCountry"))
                {
                    gfebsCountries = context.LocationByCategory.AsNoTracking()
                        .Where(p => (p.PayPlan == payPlan))
                        .Where(p => (p.CategoryGroupCode == categoryGroupCode))
                        .Where(p => (p.CategorySubgroupCode == categorySubgroupCode))
                        .Where(p => (p.CareerProgramNumber == armyCareerProgramNumber))
                        .Where(p => (p.Country != null))
                        .AsEnumerable()
                        .Select(p => new LocationDto()
                        {
                            Value = string.Format("{0}.{1}.{2}", p.LocationId, p.Id, "country"),
                            OptionGroup = "country",
                            Text = p.Country
                        })
                        .Distinct();
                }
                if (optionGroups.Contains("metropolitanStatisticalArea"))
                {
                    metropolitanStatisticalAreas = context.LocationByCategory.AsNoTracking()
                        .Where(p => (p.PayPlan == payPlan))
                        .Where(p => (p.CategoryGroupCode == categoryGroupCode))
                        .Where(p => (p.CategorySubgroupCode == categorySubgroupCode))
                        .Where(p => (p.CareerProgramNumber == armyCareerProgramNumber))
                        .Where(p => (p.MSA != null))
                        .AsEnumerable()
                        .Select(p => new LocationDto()
                        {
                            Value = string.Format("{0}.{1}.{2}", p.LocationId, p.Id, "metropolitanStatisticalArea"),
                            OptionGroup = "metropolitanStatisticalArea",
                            Text = p.MSA
                        })
                        .Distinct();
                }
                if (optionGroups.Contains("civilianOverseasArea"))
                {
                    civilianOverseasAreas = context.LocationByCategory.AsNoTracking()
                        .Where(p => (p.PayPlan == payPlan))
                        .Where(p => (p.CategoryGroupCode == categoryGroupCode))
                        .Where(p => (p.CategorySubgroupCode == categorySubgroupCode))
                        .Where(p => (p.CareerProgramNumber == armyCareerProgramNumber))
                        .Where(p => (p.CivOverseas != null))
                        .AsEnumerable()
                        .Select(p => new LocationDto()
                        {
                            Value = string.Format("{0}.{1}.{2}", p.LocationId, p.Id, "civilianOverseasArea"),
                            OptionGroup = "civilianOverseasArea",
                            Text = p.CivOverseas
                        })
                        .Distinct();
                }

                if (installations != null)
                {
                    options = options.Concat(installations).ToList();
                }

                if (conusMilitaryHousingAreas != null)
                {
                    options = options.Concat(conusMilitaryHousingAreas).ToList();
                }

                if (oconusMilitaryHousingAreas != null)
                {
                    options = options.Concat(oconusMilitaryHousingAreas).ToList();
                }

                if (localityPayAreas != null)
                {
                    options = options.Concat(localityPayAreas).ToList();
                }

                if (specialPayAreas != null)
                {
                    options = options.Concat(specialPayAreas).ToList();
                }

                if (wageSchedules != null)
                {
                    options = options.Concat(wageSchedules).ToList();
                }

                if (cityCounties != null)
                {
                    options = options.Concat(cityCounties).ToList();
                }

                if (gfebsCountries != null)
                {
                    options = options.Concat(gfebsCountries).ToList();
                }

                if (metropolitanStatisticalAreas != null)
                {
                    options = options.Concat(metropolitanStatisticalAreas).ToList();
                }

                if (civilianOverseasAreas != null)
                {
                    options = options.Concat(civilianOverseasAreas).ToList();
                }

                return options;
            }
        }
        public List<PayPlanDto> GetOptionListPayPlan()
        {
            using (var context = new ApplicationDbContext())
            {
                var results = context.PayPlan
                .Where(p => p.DisplayTitle != "")
                .Select(p => new PayPlanDto()
                {
                    Value = p.Name,
                    OptionGroup = p.GroupTitle,
                    Text = p.DisplayTitle
                });
                return results.ToList();
            }
        }
        public List<ScienceAndTechnologyReinventionLaboratoryDto> GetOptionListScienceTechnologyReinventionLaboratory(string payPlan, string categoryGroupCode, string categorySubgroupCode, string armyCareerProgramNumber, int locationId)
        {
            List<ScienceAndTechnologyReinventionLaboratoryDto> options = new List<ScienceAndTechnologyReinventionLaboratoryDto>();
            IEnumerable<ScienceAndTechnologyReinventionLaboratoryDto> strls = null;

            using (var context = new ApplicationDbContext())
            {
                strls = context.LocationByCategory.AsNoTracking()
                    .Where(p => (p.PayPlan == payPlan))
                    .Where(p => (p.CategoryGroupCode == categoryGroupCode))
                    .Where(p => (p.CategorySubgroupCode == categorySubgroupCode))
                    .Where(p => (p.CareerProgramNumber == armyCareerProgramNumber))
                    .Where(p => (p.LocationId == locationId))
                    .Where(p => (p.STRL != null))
                    .AsEnumerable()
                    .Select(p => new ScienceAndTechnologyReinventionLaboratoryDto()
                    {
                        Value = p.STRL,
                        Text = p.STRL
                    })
                    .Distinct();

                if (strls != null)
                {
                    options = options.Concat(strls).ToList();
                }

                return options;
            }
        }
        public void LogSelections(string pageAction, string pageElement, AmcosLiteViewModel amcosLiteViewModelObject)
        {
            if (amcosLiteViewModelObject == null)
            {
                throw new ArgumentNullException("amcosLiteViewModelObject");
            }

            ApplicationDbContext context = new ApplicationDbContext();
            var auditRecord = new AMCOSLiteAudit
            {
                UserId = amcosLiteViewModelObject.UserId,
                CreateDate = DateTime.Now,
                PageAction = pageAction,
                PageElement = pageElement,
                PayPlan = amcosLiteViewModelObject.PayPlan,
                CostSummaryName = amcosLiteViewModelObject.CostSummaryName,
                CategoryGroupCode = amcosLiteViewModelObject.CategoryGroupCode,
                CategorySubgroupCode = amcosLiteViewModelObject.CategorySubgroupCode,
                CareerProgramNumber = amcosLiteViewModelObject.CareerProgramNumber,
                LocationId = amcosLiteViewModelObject.LocationId,
                LocationText = amcosLiteViewModelObject.LocationText,
                STRL = amcosLiteViewModelObject.ScienceTechnologyReinventionLaboratory,
                DependentStatus = amcosLiteViewModelObject.DependentStatus,
                NumberOfDependents = amcosLiteViewModelObject.NumberOfDependents,
                OverheadPercent = amcosLiteViewModelObject.OverheadPercent,
                InflationConversionType = amcosLiteViewModelObject.InflationConversionType,
                InflationYear = amcosLiteViewModelObject.InflationYear
            };

            context.AMCOSLiteAudit.Add(auditRecord);
            context.SaveChanges();
            context.Dispose();
        }
    }
}