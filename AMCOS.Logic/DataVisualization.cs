using Newtonsoft.Json;
using Newtonsoft.Json.Linq;
using System;
using System.Collections.Generic;
using System.Data;
using System.Globalization;
using System.IO;
using System.Linq;
using System.Text;
using System.Text.RegularExpressions;
using System.Threading.Tasks;

namespace AMCOS.Logic
{
    public class DataVisualization
    {
        public static string CreateAmcosLiteC3DataJson(DataSet costs, bool writeToFile)
        {
            if (costs == null)
            {
                throw new ArgumentNullException("costs");
            }

            var costElementCategories = (from myRow in costs.Tables[1].AsEnumerable()
                                         select new
                                         {
                                             CostElementCategory = myRow.Field<string>("CostElementCategory")
                                         }).Distinct();

            var gradeLevels = (from myRow in costs.Tables[1].AsEnumerable()
                               select new
                               {
                                   GradeLevel = myRow.Field<byte>("GradeLevel")
                               })
                          .Distinct();

            var costElementCategoriesByGrade = from c in costElementCategories
                                               from g in gradeLevels
                                               select new
                                               {
                                                   g.GradeLevel,
                                                   c.CostElementCategory
                                               };

            var cost = from myRow in costs.Tables[1].AsEnumerable()
                       select new
                       {
                           GradeLevel = myRow.Field<byte>("GradeLevel"),
                           CostElementCategory = myRow.Field<string>("CostElementCategory"),
                           Amount = myRow.Field<double>("Amount")
                       };

            var allCostElementCategoriesWithCosts = from e in costElementCategoriesByGrade
                                                    join c in cost on new { e.CostElementCategory, e.GradeLevel } equals new { c.CostElementCategory, c.GradeLevel } into costsAll
                                                    from c in costsAll.DefaultIfEmpty()
                                                    select new
                                                    {
                                                        e.GradeLevel,
                                                        e.CostElementCategory,
                                                        Amount = c == null ? 0 : c.Amount
                                                    };

            //[
            //        ['Grade', 'BasePay', 'MilitaryCompensation', 'MedicalSupportCosts', 'MoraleWelfareandRecreationCosts', 'OfficerAcquisitionCosts', 'OtherBenefits', 'PermanentChangeofStationCosts', 'RetiredPayAccrual', 'Retirement', 'SeparationCosts', 'SpecialPays', 'TrainingCosts', 'VeteranBenefits', 'Inventory', 'PayMin', 'PayMax']
            //        , ['O1', 34019.758403, 20287.224103, 11017, 473.965403, 35473.202695, 12963.080108, 834.832911, 9695.631145, 8577, 93.7434, 1946.423615, 13555.252069, 9014, 1803, 37292.4, 46922.4]
            //        , ['O2', 52286.578512, 22802.443543, 11017, 473.965403, 35473.202695, 13957.226215, 2776.140501, 14901.674876, 8577, 1256.905003, 2966.604327, 26476.165974, 9014, 2057, 42966, 59461.2]
            //        , ['O3', 70084.176716, 26619.788152, 11017, 473.965403, 35473.202695, 13996.202948, 2829.361733, 19973.990364, 8577, 2619.981941, 2668.992345, 35531.735401, 9014, 2680, 49726.8, 80899.2]
            //        , ['O4', 90520.025337, 31145.857919, 11017, 473.965403, 35473.202695, 14014.528694, 3464.345947, 25798.207221, 8577, 3098.91691, 3192.112044, 40808.920004, 9014, 742, 56556, 94431.6]
            //        , ['O5', 106274.362292, 35082.408306, 11017, 473.965403, 35473.202695, 13996.372317, 3649.996613, 30288.193253, 8577, 2627.410566, 3637.494546, 14169.383488, 9014, 541, 65548.8, 111362.4]
            //        , ['O6', 131299.587845, 37277.893096, 11017, 473.965403, 35473.202695, 14014.528694, 3908.00031, 37420.382536, 8577, 2352.428517, 3525.829148, 14507.565355, 9014, 362, 78627.6, 139197.6]
            //        , ['O7', 152568.469565, 37685.875, 11017, 473.965403, 35473.202695, 14014.528694, 3530.511603, 43482.013826, 8577, 6107.489532, 3396.349672, 674.154598, 9014, 23, 103687.2, 154915.2]
            //        , ['O8', 177509.380645, 38589.016393, 11017, 473.965403, 35473.202695, 14014.528694, 4000.932562, 50590.173484, 8577, 2563.115394, 2556.313811, 882.260169, 9014, 31, 124783.2, 179892]
            //        , ['O9', 176961.12, 30917.465116, 11017, 473.965403, 35473.202695, 13359.688694, 3629.213305, 50433.9192, 8577, 18058.989585, 1880.179613, 0, 9014, 15, 176356.8, 189601.2]
            //        , ['O10', 189601.2, 23897, 11017, 473.965403, 35473.202695, 14014.528694, 2411.401256, 54036.342, 8577, 34178.039037, 2292.484094, 0, 9014, 7, 189601.2, 189601.2]
            //    ]

            JArray amcosLiteChartData =
                new JArray(
                    from g in gradeLevels
                    orderby g.GradeLevel
                    select new JObject(
                        new JProperty("grade", g.GradeLevel),
                        from c in allCostElementCategoriesWithCosts
                        where c.GradeLevel == g.GradeLevel
                        select new JProperty(c.CostElementCategory, c.Amount.ToString(CultureInfo.CurrentCulture))));

            if (writeToFile)
            {
                File.WriteAllText(@"c:\temp\amcoslite-c3data.js", amcosLiteChartData.ToString());
            }

            return amcosLiteChartData.ToString();
        }
        public string CreateD3Json(DataSet costs, bool writeToFile)
        {
            if (costs == null)
            {
                throw new ArgumentNullException("costs");
            }

            var costElementNames = (from myRow in costs.Tables[1].AsEnumerable()
                                    select new
                                    {
                                        CostElementName = myRow.Field<string>("CostElementName")
                                    }).Distinct();

            var gradeLevels = (from myRow in costs.Tables[1].AsEnumerable()
                               select new
                               {
                                   Grade = myRow.Field<string>("Grade")
                               })
                          .Distinct();

            var costElementsByGrade = from c in costElementNames
                                      from g in gradeLevels
                                      select new
                                      {
                                          g.Grade,
                                          c.CostElementName
                                      };

            var cost = from myRow in costs.Tables[1].AsEnumerable()
                       select new
                       {
                           Grade = myRow.Field<string>("Grade"),
                           CostElementName = myRow.Field<string>("CostElementName"),
                           Amount = myRow.Field<double>("Amount")
                       };

            var allCostElementNamesWithCosts = from e in costElementsByGrade
                                               join c in cost on new { e.CostElementName, e.Grade } equals new { c.CostElementName, c.Grade } into costsAll
                                               from c in costsAll.DefaultIfEmpty()
                                               select new
                                               {
                                                   e.Grade,
                                                   e.CostElementName,
                                                   Amount = c == null ? 0 : c.Amount
                                               };

            JArray amcosLiteChartData =
                new JArray(
                    from g in gradeLevels
                    orderby g.Grade
                    select new JObject(
                        new JProperty("grade", g.Grade),
                        from c in allCostElementNamesWithCosts
                        where c.Grade == g.Grade
                        select new JProperty(c.CostElementName, c.Amount.ToString(CultureInfo.CurrentCulture))));

            if (writeToFile)
            {
                File.WriteAllText(@"c:\temp\amcoslite-d3data.js", amcosLiteChartData.ToString());
            }

            return amcosLiteChartData.ToString();
        }
        public string CreateC3Json(string payPlan, DataSet costs, bool writeToFile)
        {
            if (costs == null)
            {
                throw new ArgumentNullException("costs");
            }

            var inventoryByGrade = costs.Tables[0].AsEnumerable().
                Select(c => new
                {
                    Grade = c.Field<string>("Grade"),
                    Inventory = c.Field<int>("Inventory")
                });

            var minMaxPayByGrade = costs.Tables[1].AsEnumerable().
                Select(c => new
                {
                    Grade = c.Field<string>("Grade"),
                    MinimumPay = c.Field<decimal>("MinimumPay"),
                    MaximumPay = c.Field<decimal>("MaximumPay")
                });

            var costElementCategories = costs.Tables[3].AsEnumerable().
                Select(c => new
                {
                    CostElementCategory = c.Field<string>("CostElementCategory"),
                    ShowOrder = c.Field<int>("ShowOrder")
                }).Distinct().
                OrderBy(c => c.ShowOrder);

            var gradeLevels = costs.Tables[3].AsEnumerable().
                Select(c => new
                {
                    Grade = c.Field<string>("Grade"),
                    GradeLevel = c.Field<byte>("GradeLevel")
                })
                .OrderBy(c => c.GradeLevel)
                .Distinct();
                

            var cost = costs.Tables[3].AsEnumerable().
                Select(c => new
                {
                    Grade = c.Field<string>("Grade"),
                    CostElementCategory = c.Field<string>("CostElementCategory"),
                    Amount = c.Field<double>("Amount")
                });

            var basePayByGrade = costs.Tables[4].AsEnumerable().
            Select(c => new
            {
                Grade = c.Field<string>("Grade"),
                AveragePay = c.Field<double>("AveragePay")
            });

            var costElementCategoriesByGrade = from c in costElementCategories
                                               from g in gradeLevels
                                               select new
                                               {
                                                   g.Grade,
                                                   c.CostElementCategory
                                               };

            var allCostElementCategoriesWithCosts = from e in costElementCategoriesByGrade
                                                    join c in cost on new { e.CostElementCategory, e.Grade } equals new { c.CostElementCategory, c.Grade } into costsAll
                                                    from c in costsAll.DefaultIfEmpty()
                                                    select new
                                                    {
                                                        e.Grade,
                                                        e.CostElementCategory,
                                                        Amount = c == null ? 0 : c.Amount
                                                    };

            StringBuilder sb = new StringBuilder();
            StringWriter sw = new StringWriter(sb);

            using (var writer = new JsonTextWriter(sw))
            {
                writer.Formatting = Formatting.Indented;
                writer.StringEscapeHandling = StringEscapeHandling.EscapeHtml;

                //data.x
                writer.WriteStartObject();
                writer.QuoteName = false;
                writer.WritePropertyName("x");
                writer.WriteValue("Grade");

                //data.rows
                writer.WritePropertyName("rows");
                writer.WriteStartArray();
                writer.WriteStartArray();
                writer.WriteValue("Grade");
                writer.WriteValue("Base Pay");
                foreach (var x in costElementCategories)
                {
                    writer.WriteValue(x.CostElementCategory);
                }
                writer.WriteValue("Inventory");
                if (payPlan != "SES")
                {
                    writer.WriteValue("Minimum Pay");
                    writer.WriteValue("Maximum Pay");
                }                
                writer.WriteEndArray();

                foreach (var x in gradeLevels)
                {
                    writer.WriteStartArray();
                    writer.WriteValue(x.Grade);
                    var basePay = basePayByGrade?.Where(g => g.Grade == x.Grade)?.Select(g => g.AveragePay).FirstOrDefault();
                    writer.WriteValue(basePay);
                    foreach (var grade in allCostElementCategoriesWithCosts.Where(g => g.Grade == x.Grade))
                    {
                        if (grade.CostElementCategory == "Compensation - Basic" || grade.CostElementCategory == "Military Compensation")
                        {
                            writer.WriteValue(grade.Amount - basePay);
                        }
                        else
                        {
                            writer.WriteValue(grade.Amount);
                        }                        
                    }
                    if (payPlan == "SES")
                    {
                        writer.WriteValue(inventoryByGrade.Select(g => g.Inventory).First());
                    }
                    else
                    {
                        foreach (var grade in inventoryByGrade.Where(g => g.Grade == x.Grade))
                        {
                            writer.WriteValue(grade.Inventory);
                        }
                    }
                    if (payPlan != "SES")
                    {
                        foreach (var grade in minMaxPayByGrade.Where(g => g.Grade == x.Grade))
                        {
                            writer.WriteValue(grade.MinimumPay);
                            writer.WriteValue(grade.MaximumPay);
                        }
                    }
                    writer.WriteEndArray();
                }
                writer.WriteEndArray();

                //data.axes
                writer.QuoteName = true;
                writer.WritePropertyName("axes");
                writer.WriteStartObject();
                writer.WritePropertyName("Base Pay");
                writer.WriteValue("y");
                foreach (var x in costElementCategories)
                {
                    writer.WritePropertyName(x.CostElementCategory);
                    writer.WriteValue("y");
                }
                writer.WritePropertyName("Inventory");
                writer.WriteValue("y2");
                if (payPlan != "SES")
                {
                    writer.WritePropertyName("Minimum Pay");
                    writer.WriteValue("y");
                    writer.WritePropertyName("Maximum Pay");
                    writer.WriteValue("y");
                }
                writer.WriteEndObject();

                //data.types
                writer.QuoteName = true;
                writer.WritePropertyName("types");
                writer.WriteStartObject();
                writer.WritePropertyName("Base Pay");
                writer.WriteValue("bar");
                foreach (var x in costElementCategories)
                {
                    writer.WritePropertyName(x.CostElementCategory);
                    writer.WriteValue("bar");
                }
                writer.WritePropertyName("Inventory");
                writer.WriteValue("line");
                if (payPlan != "SES")
                {
                    writer.WritePropertyName("Minimum Pay");
                    writer.WriteValue("line");
                    writer.WritePropertyName("Maximum Pay");
                    writer.WriteValue("line");
                }
                writer.WriteEndObject();

                //data.groups
                writer.WritePropertyName("groups");
                writer.WriteStartArray();
                writer.WriteStartArray();
                writer.WriteValue("Base Pay");
                foreach (var x in costElementCategories)
                {
                    writer.WriteValue(x.CostElementCategory);
                }
                writer.WriteEndArray();
                writer.WriteEndArray();

                //data.colors
                writer.QuoteName = true;
                writer.WritePropertyName("colors");
                writer.WriteStartObject();
                writer.WritePropertyName("Minimum Pay");
                writer.WriteValue("#000000");
                writer.WritePropertyName("Maximum Pay");
                writer.WriteValue("#000000");
                writer.WritePropertyName("Inventory");
                writer.WriteValue("#d11668");
                writer.WriteEndObject();

                //data.order
                writer.QuoteName = false;
                writer.WritePropertyName("order");
                writer.WriteNull();
                writer.WriteEndObject();
            }

            if (writeToFile)
            {
                File.WriteAllText(@"c:\temp\amcoslite-c3data.js", sb.ToString());
            }
            return sb.ToString();
        }
    }
}
