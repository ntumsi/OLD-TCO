using AMCOS.Data;
using System;
using System.Collections.Generic;
using System.Data;
using System.Linq;
using System.Text.Json;
using Npgsql;

namespace AMCOS.Logic.Helpers
{
    /// <summary>
    /// Invokes a <c>web.*</c> PostgreSQL function that returns the
    /// <c>(result_set_name text, row_data jsonb)</c> shape used by the migrated procedures in
    /// <c>007_stored_procedures.sql</c>, and projects the jsonb rows into a flat
    /// <see cref="DataTable"/> whose columns are the keys of each JSON object.
    /// <para>
    /// This replaces the legacy SQL Server <c>CommandType.StoredProcedure</c> + <c>adapter.Fill</c>
    /// pattern, which is broken on PostgreSQL: Npgsql turns <c>CommandType.StoredProcedure</c> into
    /// <c>CALL</c> (invalid on a function), and the raw result is two columns
    /// (name + jsonb), not the flat tabular shape the callers expect (e.g. <c>row["LocationId"]</c>,
    /// pivot grade/step columns, <c>V1..Vn</c>).
    /// </para>
    /// <para>
    /// Parameters are bound positionally in the order supplied, matching each function's signature,
    /// so callers pass the same <see cref="NpgsqlParameter"/> list they used before. DataTable column
    /// lookups are case-insensitive, so callers may keep their original PascalCase column names even
    /// though PostgreSQL folds the jsonb keys to lowercase.
    /// </para>
    /// </summary>
    public static class StoredFunction
    {
        public static DataTable QueryAsTable(string functionName, params NpgsqlParameter[] parameters)
        {
            var argList = string.Join(", ", parameters.Select(p => "@" + p.ParameterName.TrimStart('@')));
            var sql = $"SELECT row_data FROM {functionName}({argList})";

            var columns = new List<string>();
            var rows = new List<Dictionary<string, object>>();

            using (var connection = new NpgsqlConnection(AppConfiguration.GetConnectionString()))
            {
                connection.Open();
                using (var command = new NpgsqlCommand(sql, connection))
                {
                    command.Parameters.AddRange(parameters);
                    using (var reader = command.ExecuteReader())
                    {
                        while (reader.Read())
                        {
                            if (reader.IsDBNull(0)) continue;
                            var json = reader.GetFieldValue<string>(0);
                            using (var doc = JsonDocument.Parse(json))
                            {
                                if (doc.RootElement.ValueKind != JsonValueKind.Object) continue;
                                var dict = new Dictionary<string, object>(StringComparer.OrdinalIgnoreCase);
                                foreach (var prop in doc.RootElement.EnumerateObject())
                                {
                                    if (!columns.Contains(prop.Name, StringComparer.OrdinalIgnoreCase))
                                        columns.Add(prop.Name);
                                    dict[prop.Name] = JsonValueToClr(prop.Value);
                                }
                                rows.Add(dict);
                            }
                        }
                    }
                }
            }

            var table = new DataTable();
            foreach (var col in columns)
                table.Columns.Add(col, typeof(object));
            foreach (var dict in rows)
            {
                var row = table.NewRow();
                foreach (var col in columns)
                    row[col] = (dict.TryGetValue(col, out var v) && v != null) ? v : DBNull.Value;
                table.Rows.Add(row);
            }
            return table;
        }

        private static object JsonValueToClr(JsonElement element)
        {
            switch (element.ValueKind)
            {
                case JsonValueKind.Null:
                case JsonValueKind.Undefined:
                    return DBNull.Value;
                case JsonValueKind.Number:
                    return element.TryGetDecimal(out var d) ? d : (object)element.GetDouble();
                case JsonValueKind.True:
                case JsonValueKind.False:
                    return element.GetBoolean();
                case JsonValueKind.String:
                    return element.GetString();
                default:
                    return element.GetRawText();
            }
        }
    }
}
