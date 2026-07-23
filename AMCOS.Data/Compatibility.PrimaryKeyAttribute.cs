#if NET48
using System;

namespace Microsoft.EntityFrameworkCore
{
    /// <summary>
    /// Compile shim for the net48 (classic AMCOS.Web) build. EF Core 3.1 — the last EF Core
    /// line that runs on .NET Framework — predates the <c>[PrimaryKey]</c> attribute (added in
    /// EF Core 7), which the entity classes use to declare composite keys. This no-op stand-in
    /// lets those entities compile; the keys are configured for the net48 model via fluent
    /// <c>HasKey</c> calls in <see cref="AMCOS.Data.ApplicationDbContext.OnModelCreating"/>.
    /// Not compiled for net8.0, where the real EF Core 8 attribute is used.
    /// </summary>
    [AttributeUsage(AttributeTargets.Class, AllowMultiple = false)]
    public sealed class PrimaryKeyAttribute : Attribute
    {
        public PrimaryKeyAttribute(string propertyName, params string[] additionalPropertyNames)
        {
            PropertyNames = new string[additionalPropertyNames.Length + 1];
            PropertyNames[0] = propertyName;
            Array.Copy(additionalPropertyNames, 0, PropertyNames, 1, additionalPropertyNames.Length);
        }

        public string[] PropertyNames { get; }
    }
}
#endif
