using AMCOS.Data;
using AMCOS.Data.ViewModels;
using System;
using System.Data;
using Npgsql;
using NpgsqlTypes;
using System.Globalization;

namespace AMCOS.Logic
{
    public class Costs
    {
        public ContractorCostEstimateCostsViewModel GetCceCosts(int amcosVersionId)
        {
            using (var context = new ApplicationDbContext())
            {
                ContractorCostEstimateCostsViewModel cceCosts = new ContractorCostEstimateCostsViewModel
                {
                    WagesAndSalaries = SingleValue.Get("CCE", "WagesAndSalaries", amcosVersionId).ToString(CultureInfo.CurrentCulture),
                    BenefitsAll = SingleValue.Get("CCE", "Benefits_All", amcosVersionId).ToString(CultureInfo.CurrentCulture),
                    BenefitsPaidLeave = SingleValue.Get("CCE", "Benefits_PaidLeave", amcosVersionId).ToString(CultureInfo.CurrentCulture),
                    BenefitsSupplementalPay = SingleValue.Get("CCE", "Benefits_SupplementalPay", amcosVersionId).ToString(CultureInfo.CurrentCulture),
                    BenefitsInsurance = SingleValue.Get("CCE", "Benefits_Insurance_All", amcosVersionId).ToString(CultureInfo.CurrentCulture),
                    BenefitsRetirementAndSavingsAll = SingleValue.Get("CCE", "Benefits_RetirementAndSavings_All", amcosVersionId).ToString(CultureInfo.CurrentCulture),
                    BenefitsLegallyRequired = SingleValue.Get("CCE", "Benefits_LegallyRequired", amcosVersionId).ToString(CultureInfo.CurrentCulture)
                };
                return cceCosts;
            }
        }
        public DataSet GetCosts(string payPlan, string categorySubgroupCode, string metroAreaCode, string overheadPercent)
        {
            DataSet ds = new DataSet
            {
                Locale = CultureInfo.InvariantCulture
            };

            switch (payPlan)
            {
                case "CCE":
                    string sqlStatement = "SELECT * FROM web.costsCCE(@CategorySubgroupCode, @Area, @OverheadPercent);";

                    using (NpgsqlConnection connection = new NpgsqlConnection(AppConfiguration.GetConnectionString()))
                    {
                        connection.Open();
                        NpgsqlDataAdapter adapter = new NpgsqlDataAdapter();
                        using (NpgsqlCommand command = new NpgsqlCommand(sqlStatement, connection))
                        {
                            command.Parameters.AddWithValue("@CategorySubgroupCode", categorySubgroupCode);
                            command.Parameters.AddWithValue("@Area", metroAreaCode);
                            command.Parameters.AddWithValue("@OverheadPercent", Single.Parse(overheadPercent));
                            command.CommandType = CommandType.Text;
                            adapter.SelectCommand = command;
                            adapter.Fill(ds);
                        }
                        adapter.Dispose();
                    }
                    return ds;
                default:
                    return ds;

            }
        }
        public DataSet GetCosts(string payPlan, string categorySubgroupCode, string metroAreaCode, string overheadPercent, string inflationConversion, string inflationYear, int amcosVersionId)
        {
            DataSet ds = new DataSet
            {
                Locale = CultureInfo.InvariantCulture
            };

            switch (payPlan)
            {
                case "CCE":
                    string sqlStatement = "SELECT * FROM web.costsCCEInflated(@CategorySubgroupCode, @Area, @OverheadPercent, @InflationConversion, @InflationYear, @AmcosVersionId);";

                    using (NpgsqlConnection connection = new NpgsqlConnection(AppConfiguration.GetConnectionString()))
                    {
                        connection.Open();
                        NpgsqlDataAdapter adapter = new NpgsqlDataAdapter();
                        using (NpgsqlCommand command = new NpgsqlCommand(sqlStatement, connection))
                        {
                            command.Parameters.AddWithValue("@CategorySubgroupCode", categorySubgroupCode);
                            command.Parameters.AddWithValue("@Area", metroAreaCode);
                            command.Parameters.AddWithValue("@OverheadPercent", Single.Parse(overheadPercent));
                            command.Parameters.AddWithValue("@InflationConversion", inflationConversion);
                            command.Parameters.AddWithValue("@InflationYear", inflationYear);
                            command.Parameters.AddWithValue("@AmcosVersionId", amcosVersionId);
                            command.CommandType = CommandType.Text;
                            adapter.SelectCommand = command;
                            adapter.Fill(ds);
                        }
                        adapter.Dispose();
                    }
                    return ds;
                default:
                    return ds;

            }
        }
    }
}
