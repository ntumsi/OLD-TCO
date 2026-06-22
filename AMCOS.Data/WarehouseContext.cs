using AMCOS.Data.Entities;
using System.Data.Entity;

namespace AMCOS.Data
{
    public class WarehouseContext : DbContext
    {
        public WarehouseContext() : base("name=AmcosEF")
        {
            this.Configuration.LazyLoadingEnabled = false;
            this.Configuration.ProxyCreationEnabled = false;
        }

        protected override void OnModelCreating(DbModelBuilder modelBuilder)
        {
            modelBuilder.Entity<Category>().ToTable("Category", "warehouse");
            modelBuilder.Entity<Category>().HasKey(e => new { e.PayPlan, e.CategoryGroupCode, e.CategorySubgroupCode });
            modelBuilder.Entity<Category>().Property(e => e.PayPlan).IsUnicode(true);
            modelBuilder.Entity<Category>().Property(e => e.PayPlan).HasMaxLength(3);
            modelBuilder.Entity<Category>().Property(e => e.CategoryGroupCode).IsUnicode(true);
            modelBuilder.Entity<Category>().Property(e => e.CategoryGroupCode).HasMaxLength(7);
            modelBuilder.Entity<Category>().Property(e => e.CategoryGroupDescription).IsUnicode(true);
            modelBuilder.Entity<Category>().Property(e => e.CategoryGroupDescription).HasMaxLength(150);
            modelBuilder.Entity<Category>().Property(e => e.CategoryGroupDisplay).IsUnicode(true);
            modelBuilder.Entity<Category>().Property(e => e.CategoryGroupDisplay).HasMaxLength(175);
            modelBuilder.Entity<Category>().Property(e => e.CategorySubgroupCode).IsUnicode(true);
            modelBuilder.Entity<Category>().Property(e => e.CategorySubgroupCode).HasMaxLength(7);
            modelBuilder.Entity<Category>().Property(e => e.CategorySubgroupDescription).IsUnicode(true);
            modelBuilder.Entity<Category>().Property(e => e.CategorySubgroupDescription).HasMaxLength(150);
            modelBuilder.Entity<Category>().Property(e => e.CategorySubgroupDisplay).IsUnicode(true);
            modelBuilder.Entity<Category>().Property(e => e.CategorySubgroupDisplay).HasMaxLength(175);
        }

        public virtual DbSet<Category> Category { get; set; }
        public virtual DbSet<Costs> Costs { get; set; }
    }
}
