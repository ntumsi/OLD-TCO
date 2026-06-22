using System.Configuration;
using System.Data;
using System.Data.SqlClient;

namespace AMCOS.Logic
{
    public static class DataLayerModule
    {
        public static DataSet GetUserStats()
        {
            DataSet userStats = new DataSet();
            string sqlStatement = "spGetUserStats";

            using (SqlConnection connection = new SqlConnection(ConfigurationManager.ConnectionStrings["AmcosAdo"].ConnectionString))
            {
                connection.Open();
                SqlDataAdapter adapter = new SqlDataAdapter();
                using (SqlCommand command = new SqlCommand(sqlStatement, connection))
                {
                    command.CommandType = CommandType.StoredProcedure;
                    adapter.SelectCommand = command;
                    adapter.Fill(userStats);
                }
            }

            return userStats;
        }
    }
}
