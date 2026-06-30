using Npgsql;
using NpgsqlTypes;
using System.Data;
using System.Linq;
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
            // The migrated web.* "procedures" are PostgreSQL FUNCTIONS, and the multi-result-set
            // ones return rows of (result_set_name text, row_data jsonb). Invoke with
            // SELECT * FROM fn(...) (CommandType.StoredProcedure -> CALL is invalid on a function)
            // and re-expand the jsonb into one DataTable per result_set_name so callers see the
            // original tabular multi-grid shape. Flat-returning functions fall through unchanged.
            var argList = string.Join(", ", parameterNames.Select(p => "@" + p.TrimStart('@')));
            var sql = $"SELECT * FROM {storedProcedureName}({argList})";

            using (NpgsqlConnection connection = new NpgsqlConnection(AppConfiguration.GetConnectionString()))
            {
                connection.Open();
                using (NpgsqlCommand command = new NpgsqlCommand(sql, connection))
                {
                    command.CommandType = CommandType.Text;
                    command.CommandTimeout = 900; // seconds
                    for (int i = 0; i <= parameterNames.Length - 1; i++)
                    {
                        command.Parameters.Add(parameterNames[i], parameterTypes[i]).Value = parameterValues[i] ?? DBNull.Value;
                    }

                    var raw = new DataSet();
                    new NpgsqlDataAdapter { SelectCommand = command }.Fill(raw);

                    return IsJsonbResultShape(raw) ? ExpandJsonbResultSets(raw.Tables[0]) : raw;
                }
            }
        }

        // True when the result is the (result_set_name text, row_data jsonb) convention.
        private static bool IsJsonbResultShape(DataSet ds)
        {
            if (ds.Tables.Count != 1) return false;
            var cols = ds.Tables[0].Columns;
            return cols.Count == 2
                && cols.Contains("result_set_name")
                && cols.Contains("row_data");
        }

        // Expands the (result_set_name, row_data jsonb) result into one DataTable per grid.
        // Handles BOTH conventions used by the migrated procedures:
        //   (a) one row per data row:        row_data = { col: val, ... }  -> appended to table[result_set_name]
        //   (b) a single nested payload row: row_data = { costs:[{...}], appropriationsummary:[{...}], ... }
        //       -> each array-valued key becomes its own table of rows.
        private static DataSet ExpandJsonbResultSets(DataTable raw)
        {
            var ds = new DataSet();
            foreach (DataRow row in raw.Rows)
            {
                var name = row["result_set_name"] == DBNull.Value ? "Result" : row["result_set_name"].ToString();
                var json = row["row_data"] == DBNull.Value ? null : row["row_data"].ToString();
                if (string.IsNullOrEmpty(json)) continue;

                using (var doc = System.Text.Json.JsonDocument.Parse(json))
                {
                    var rootEl = doc.RootElement;
                    if (rootEl.ValueKind != System.Text.Json.JsonValueKind.Object) continue;

                    var isNestedPayload = rootEl.EnumerateObject()
                        .Any(p => p.Value.ValueKind == System.Text.Json.JsonValueKind.Array);

                    if (isNestedPayload)
                    {
                        foreach (var prop in rootEl.EnumerateObject())
                        {
                            if (prop.Value.ValueKind != System.Text.Json.JsonValueKind.Array) continue;
                            var t = ds.Tables.Contains(prop.Name) ? ds.Tables[prop.Name] : ds.Tables.Add(prop.Name);
                            foreach (var el in prop.Value.EnumerateArray())
                                AppendJsonObjectRow(t, el);
                        }
                    }
                    else
                    {
                        var t = ds.Tables.Contains(name) ? ds.Tables[name] : ds.Tables.Add(name);
                        AppendJsonObjectRow(t, rootEl);
                    }
                }
            }
            if (ds.Tables.Count == 0)
                ds.Tables.Add("Result");
            return ds;
        }

        // Appends one JSON object as a DataRow, adding columns (union of keys) on demand.
        private static void AppendJsonObjectRow(DataTable table, System.Text.Json.JsonElement obj)
        {
            if (obj.ValueKind != System.Text.Json.JsonValueKind.Object) return;
            var newRow = table.NewRow();
            foreach (var prop in obj.EnumerateObject())
            {
                if (!table.Columns.Contains(prop.Name))
                    table.Columns.Add(prop.Name, typeof(object));
                newRow[prop.Name] = JsonValueToClr(prop.Value);
            }
            table.Rows.Add(newRow);
        }

        private static object JsonValueToClr(System.Text.Json.JsonElement element)
        {
            switch (element.ValueKind)
            {
                case System.Text.Json.JsonValueKind.Null:
                case System.Text.Json.JsonValueKind.Undefined:
                    return DBNull.Value;
                case System.Text.Json.JsonValueKind.Number:
                    return element.TryGetDecimal(out var d) ? d : (object)element.GetDouble();
                case System.Text.Json.JsonValueKind.True:
                case System.Text.Json.JsonValueKind.False:
                    return element.GetBoolean();
                case System.Text.Json.JsonValueKind.String:
                    return element.GetString();
                default:
                    return element.GetRawText();
            }
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