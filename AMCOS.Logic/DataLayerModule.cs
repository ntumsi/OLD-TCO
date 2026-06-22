using System.Data;
using Npgsql;
using NpgsqlTypes;

namespace AMCOS.Logic
{
    public static class DataLayerModule
    {
        public static DataSet GetUserStats()
        {
            DataSet userStats = new DataSet();
            string sqlStatement = "spGetUserStats";

            using (NpgsqlConnection connection = new NpgsqlConnection(AppConfiguration.GetConnectionString()))
            {
                connection.Open();
                NpgsqlDataAdapter adapter = new NpgsqlDataAdapter();
                using (NpgsqlCommand command = new NpgsqlCommand(sqlStatement, connection))
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
