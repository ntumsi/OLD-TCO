using System;
using System.IO;
using Microsoft.Extensions.Configuration;

namespace AMCOS.Data
{
    public static class AppConfiguration
    {
        private static readonly Lazy<IConfigurationRoot> ConfigurationRoot = new Lazy<IConfigurationRoot>(BuildConfiguration);

        public static string GetConnectionString()
        {
            var environmentConnectionString = Environment.GetEnvironmentVariable("AMCOS_POSTGRES_CONNECTION");
            if (!string.IsNullOrWhiteSpace(environmentConnectionString))
            {
                return environmentConnectionString;
            }

            var configuration = ConfigurationRoot.Value;
            var connectionString = configuration.GetConnectionString("AmcosPostgres")
                ?? configuration["ConnectionStrings:AmcosPostgres"];

            if (string.IsNullOrWhiteSpace(connectionString))
            {
                throw new InvalidOperationException("A PostgreSQL connection string named 'AmcosPostgres' was not found.");
            }

            return connectionString;
        }

        public static string GetSetting(string key, string defaultValue = null)
        {
            return ConfigurationRoot.Value[key] ?? defaultValue;
        }

        public static int GetInt32(string key, int defaultValue)
        {
            var value = GetSetting(key);
            return int.TryParse(value, out var parsedValue) ? parsedValue : defaultValue;
        }

        private static IConfigurationRoot BuildConfiguration()
        {
            return new ConfigurationBuilder()
                .SetBasePath(AppContext.BaseDirectory)
                .AddJsonFile("appsettings.json", optional: true, reloadOnChange: false)
                .AddEnvironmentVariables()
                .Build();
        }
    }
}
