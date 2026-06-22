using Npgsql;
using NpgsqlTypes;
using System.Data;
using System.Text;
using System;

namespace AMCOS.Logic
{
    public class DataAccessUtility
    {
        public static void ExecuteStoredProc(string storedProcedureName, string[] parameterNames, NpgsqlDbType[] parameterTypes, object[] parameterValues)
        {
            using (NpgsqlConnection connection = new NpgsqlConnection(AppConfiguration.GetConnectionString()))
            {
                connection.Open();
                using (NpgsqlCommand sqlCmd = new NpgsqlCommand(storedProcedureName, connection))
                {
                    sqlCmd.CommandType = CommandType.StoredProcedure;
                    for (int i = 0; i <= parameterNames.Length - 1; i++)
                    {
                        sqlCmd.Parameters.Add(parameterNames[i], parameterTypes[i]).Value = parameterValues[i];
                    }
                    sqlCmd.ExecuteNonQuery();
                }
            }
        }
        public static DataSet ExecuteStoredProcDataSet(string storedProcedureName, string[] parameterNames, NpgsqlDbType[] parameterTypes, object[] parameterValues)
        {
            DataSet dataSet = new DataSet();

            using (NpgsqlConnection connection = new NpgsqlConnection(AppConfiguration.GetConnectionString()))
            {
                connection.Open();
                using (NpgsqlCommand command = new NpgsqlCommand(storedProcedureName, connection))
                {
                    command.CommandType = CommandType.StoredProcedure;
                    command.CommandTimeout = 900000;
                    for (int i = 0; i <= parameterNames.Length - 1; i++)
                    {
                        command.Parameters.Add(parameterNames[i], parameterTypes[i]).Value = parameterValues[i];
                    }
                    NpgsqlDataAdapter dataAdapter = new NpgsqlDataAdapter
                    {
                        SelectCommand = command
                    };
                    dataAdapter.Fill(dataSet);
                }
            }
            return dataSet;
        }
        public static object GetScalarByStaticSql(string sqlStatement, string[] parameterNames = null, object[] parameterValues = null)
        {
            object oScalar = null;
            using (NpgsqlConnection connection = new NpgsqlConnection(AppConfiguration.GetConnectionString()))
            {
                connection.Open();
                using (NpgsqlCommand sqlCmd = new NpgsqlCommand())
                {
                    sqlCmd.CommandText = sqlStatement;
                    sqlCmd.Connection = connection;
                    if (!(parameterNames == null) && (parameterNames.Length > 0))
                    {
                        for (int i = 0; i <= parameterNames.Length - 1; i++)
                        {
                            if (!(parameterNames[i] == null))
                            {
                                sqlCmd.Parameters.AddWithValue(parameterNames[i], parameterValues[i]);
                            }
                        }
                    }
                    try
                    {
                        oScalar = sqlCmd.ExecuteScalar();
                    }
                    catch (Exception ex)
                    {
                        oScalar = 1;
                    }
                }
            }
            return oScalar;
        }
        public static DataTable GetDataTableByStaticSql(string sqlStatement, string[] parameterNames = null, object[] parameterValues = null)
        {
            DataTable dt = new DataTable();
            using (NpgsqlConnection connection = new NpgsqlConnection(AppConfiguration.GetConnectionString()))
            {
                connection.Open();
                using (NpgsqlCommand command = new NpgsqlCommand(sqlStatement, connection))
                {
                    if (!(parameterNames == null) && (parameterNames.Length > 0))
                    {
                        for (int i = 0; i <= parameterNames.Length - 1; i++)
                        {
                            if (!(parameterNames[i] == null))
                            {
                                command.Parameters.AddWithValue(parameterNames[i], parameterValues[i]);
                            }
                        }
                    }
                    using (NpgsqlDataReader objDataReader = command.ExecuteReader())
                    {
                        dt.Load(objDataReader);
                    }
                }
            }
            return dt;
        }
        public static DataTable GetDataTableByDynamicSql(string sqlStatement, bool[] applyFilter, string[] columnNames, object[] columnValues, string endSQL = "")
        {
            int parameterCount = 0;
            string[] parameterNames = new string[applyFilter.Length];
            object[] parameterValues = new object[applyFilter.Length];

            StringBuilder sb = new StringBuilder(sqlStatement);
            for (int i = 0; i <= applyFilter.Length - 1; i++)
            {
                if (applyFilter[i])
                {
                    sb.Append(String.Format(" and {0} = @{0}", columnNames[i], i));
                    parameterNames[parameterCount] = columnNames[i];
                    parameterValues[parameterCount] = columnValues[i];
                    parameterCount++;
                }
            }
            if (parameterCount == 0)
            {
                return GetDataTableByStaticSql(sqlStatement + " " + endSQL, null, null);
            }
            else
            {
                Array.Resize(ref parameterNames, parameterCount);
                Array.Resize(ref parameterValues, parameterCount);
                string sql = sb.ToString() + " " + endSQL;
                return GetDataTableByStaticSql(sql, parameterNames, parameterValues);
            }
        }
    }
}