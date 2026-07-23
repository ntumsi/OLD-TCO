#if NET48
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace AMCOS.Data
{
    /// <summary>
    /// The net48 (classic AMCOS.Web) build uses EF Core 3.1 — the last EF Core line that runs
    /// on .NET Framework. A few fluent-API members used by the shared model configuration
    /// (<see cref="ApplicationDbContext.OnModelCreating"/>) were added/renamed in later EF Core
    /// versions. These extension shims map them to their 3.1 equivalents so the exact same model
    /// config compiles for both targets. Only compiled for net48 (net8.0 uses the real API).
    /// </summary>
    internal static class EfCore31FluentShims
    {
        /// <summary>EF Core 5+ <c>HasPrecision(precision, scale)</c> → a 3.1 numeric column type.</summary>
        public static PropertyBuilder<T> HasPrecision<T>(this PropertyBuilder<T> builder, int precision, int scale)
            => builder.HasColumnType($"numeric({precision},{scale})");

        /// <summary>EF Core 5 renamed <c>IndexBuilder.HasName</c> → <c>HasDatabaseName</c>.</summary>
        public static IndexBuilder<T> HasDatabaseName<T>(this IndexBuilder<T> builder, string name)
            => builder.HasName(name);
    }
}
#endif
