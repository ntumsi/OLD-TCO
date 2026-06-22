using System.Data.Entity;
using System.Data.Entity.SqlServer;
using AMCOS.Data.Entities;
using Microsoft.SqlServer.Types;

namespace AMCOS.Data
{
    public class ApplicationDbContext : DbContext
    {
        public ApplicationDbContext() : base("name=AmcosEF")
        {
            this.Configuration.LazyLoadingEnabled = false;
            this.Configuration.ProxyCreationEnabled = false;
        }
        protected override void OnModelCreating(DbModelBuilder modelBuilder)
        {
            modelBuilder.Entity<AMCOSLiteAudit>().ToTable("AMCOSLiteAudit", "webuser");
            modelBuilder.Entity<AMCOSLiteAudit>().HasKey(e => new { e.UserId, e.CreateDate, e.PageAction, e.PageElement });
            modelBuilder.Entity<AMCOSLiteAudit>().Property(e => e.UserId).HasMaxLength(50);
            modelBuilder.Entity<AMCOSLiteAudit>().Property(e => e.PageAction).HasMaxLength(50);
            modelBuilder.Entity<AMCOSLiteAudit>().Property(e => e.PageElement).HasMaxLength(50);
            modelBuilder.Entity<AMCOSLiteAudit>().Property(e => e.PayPlan).HasMaxLength(3);
            modelBuilder.Entity<AMCOSLiteAudit>().Property(e => e.CostSummaryName).HasMaxLength(50);
            modelBuilder.Entity<AMCOSLiteAudit>().Property(e => e.CategoryGroupCode).HasMaxLength(7);
            modelBuilder.Entity<AMCOSLiteAudit>().Property(e => e.CategorySubgroupCode).HasMaxLength(7);
            modelBuilder.Entity<AMCOSLiteAudit>().Property(e => e.CareerProgramNumber).HasMaxLength(2);
            modelBuilder.Entity<AMCOSLiteAudit>().Property(e => e.STRL).IsUnicode(true);
            modelBuilder.Entity<AMCOSLiteAudit>().Property(e => e.STRL).HasMaxLength(20);
            modelBuilder.Entity<AMCOSLiteAudit>().Property(e => e.InflationConversionType).HasMaxLength(25);
            modelBuilder.Entity<AMCOSLiteAudit>().Property(e => e.InflationYear).HasMaxLength(4);

            modelBuilder.Entity<AMCOSUser>().ToTable("AMCOSUser", "webuser");
            modelBuilder.Entity<AMCOSUser>().HasKey(e => e.UserId);
            modelBuilder.Entity<AMCOSUser>().Property(e => e.UserId).HasMaxLength(50);
            modelBuilder.Entity<AMCOSUser>().Property(e => e.FirstName).HasMaxLength(50);
            modelBuilder.Entity<AMCOSUser>().Property(e => e.FirstName).IsRequired();
            modelBuilder.Entity<AMCOSUser>().Property(e => e.MiddleName).HasMaxLength(50);
            modelBuilder.Entity<AMCOSUser>().Property(e => e.LastName).HasMaxLength(50);
            modelBuilder.Entity<AMCOSUser>().Property(e => e.LastName).IsRequired();
            modelBuilder.Entity<AMCOSUser>().Property(e => e.Email).HasMaxLength(50);
            modelBuilder.Entity<AMCOSUser>().Property(e => e.Email).IsRequired();
            modelBuilder.Entity<AMCOSUser>().Property(e => e.CACEmail).HasMaxLength(500);
            modelBuilder.Entity<AMCOSUser>().Property(e => e.Prefix).HasMaxLength(5);
            modelBuilder.Entity<AMCOSUser>().Property(e => e.AKOId).HasMaxLength(50);
            modelBuilder.Entity<AMCOSUser>().Property(e => e.DodId).HasMaxLength(50);
            modelBuilder.Entity<AMCOSUser>().Property(e => e.ComPhone).HasMaxLength(50);
            modelBuilder.Entity<AMCOSUser>().Property(e => e.Dsn).HasMaxLength(50);
            modelBuilder.Entity<AMCOSUser>().Property(e => e.InternationalNo).HasMaxLength(30);
            modelBuilder.Entity<AMCOSUser>().Property(e => e.ArmyAccountType).HasMaxLength(50);
            modelBuilder.Entity<AMCOSUser>().Property(e => e.ArmyRank).HasMaxLength(50);
            modelBuilder.Entity<AMCOSUser>().Property(e => e.OfficeName).HasMaxLength(100);
            modelBuilder.Entity<AMCOSUser>().Property(e => e.CompanyName).HasMaxLength(100);
            modelBuilder.Entity<AMCOSUser>().Property(e => e.Macom).HasMaxLength(50);
            modelBuilder.Entity<AMCOSUser>().Property(e => e.UserStatus).HasMaxLength(14);
            modelBuilder.Entity<AMCOSUser>().Property(e => e.UserRole).HasMaxLength(50);
            modelBuilder.Entity<AMCOSUser>().Property(e => e.SelfAccountType).HasMaxLength(10);
            modelBuilder.Entity<AMCOSUser>().Property(e => e.SponsorUserId).HasMaxLength(50);

            modelBuilder.Entity<ArmyCareerProgram>().ToTable("ArmyCareerProgram", "lookup");
            modelBuilder.Entity<ArmyCareerProgram>().HasKey(e => new { e.CareerProgramNumber });
            modelBuilder.Entity<ArmyCareerProgram>().Property(e => e.CareerProgramNumber).IsUnicode(true);
            modelBuilder.Entity<ArmyCareerProgram>().Property(e => e.CareerProgramNumber).HasMaxLength(2);
            modelBuilder.Entity<ArmyCareerProgram>().Property(e => e.Title).IsUnicode(true);
            modelBuilder.Entity<ArmyCareerProgram>().Property(e => e.Title).HasMaxLength(75);

            modelBuilder.Entity<AvalaraStateTax>().ToTable("AvalaraStateTax", "data");
            modelBuilder.Entity<AvalaraStateTax>().HasKey(e => new { e.State, e.ZipCode, e.AmcosVersionIdEnd });
            modelBuilder.Entity<AvalaraStateTax>().Property(e => e.State).HasMaxLength(2).IsRequired();
            modelBuilder.Entity<AvalaraStateTax>().Property(e => e.ZipCode).HasMaxLength(5).IsRequired();
            modelBuilder.Entity<AvalaraStateTax>().Property(e => e.TaxRegionName).HasMaxLength(255).IsRequired();            

            modelBuilder.Entity<CategoryGroup>().ToTable("CategoryGroup", "data");
            modelBuilder.Entity<CategoryGroup>().HasKey(e => new { e.PayPlan, e.CategoryGroupCode });
            modelBuilder.Entity<CategoryGroup>().Property(e => e.PayPlan).IsUnicode(false);
            modelBuilder.Entity<CategoryGroup>().Property(e => e.PayPlan).HasMaxLength(3);
            modelBuilder.Entity<CategoryGroup>().Property(e => e.CategoryGroupCode).IsUnicode(false);
            modelBuilder.Entity<CategoryGroup>().Property(e => e.CategoryGroupCode).HasMaxLength(7);
            modelBuilder.Entity<CategoryGroup>().Property(e => e.CategoryGroupDescription).IsUnicode(false);
            modelBuilder.Entity<CategoryGroup>().Property(e => e.CategoryGroupDescription).HasMaxLength(255);

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
            modelBuilder.Entity<Category>().Property(e => e.CareerProgramNumber).IsUnicode(true);
            modelBuilder.Entity<Category>().Property(e => e.CareerProgramNumber).HasMaxLength(7);
            modelBuilder.Entity<Category>().Property(e => e.CareerProgramDescription).IsUnicode(true);
            modelBuilder.Entity<Category>().Property(e => e.CareerProgramDescription).HasMaxLength(150);
            modelBuilder.Entity<Category>().Property(e => e.CareerProgramDisplay).IsUnicode(true);
            modelBuilder.Entity<Category>().Property(e => e.CategorySubgroupDisplay).HasMaxLength(175);

            modelBuilder.Entity<CategorySubgroup>().ToTable("CategorySubgroup", "data");
            modelBuilder.Entity<CategorySubgroup>().HasKey(e => new { e.PayPlan, e.CategoryGroupCode, e.CategorySubgroupCode });
            modelBuilder.Entity<CategorySubgroup>().Property(e => e.PayPlan).IsUnicode(false);
            modelBuilder.Entity<CategorySubgroup>().Property(e => e.PayPlan).HasMaxLength(3);
            modelBuilder.Entity<CategorySubgroup>().Property(e => e.CategoryGroupCode).HasMaxLength(7);
            modelBuilder.Entity<CategorySubgroup>().Property(e => e.CategoryGroupDescription).HasMaxLength(250);
            modelBuilder.Entity<CategorySubgroup>().Property(e => e.CategorySubgroupCode).HasMaxLength(7);
            modelBuilder.Entity<CategorySubgroup>().Property(e => e.CategorySubgroupDescription).HasMaxLength(255);

            modelBuilder.Entity<CivLocationPerDiem>().ToTable("CivLocationPerDiem", "web");
            modelBuilder.Entity<CivLocationPerDiem>().HasKey(e => new { e.LocationId });

            modelBuilder.Entity<CostElement>().ToTable("CostElement", "lookup");
            modelBuilder.Entity<CostElement>().HasKey(e => e.CostElementId);
            modelBuilder.Entity<CostElement>().Property(e => e.CostElementId).HasDatabaseGeneratedOption(System.ComponentModel.DataAnnotations.Schema.DatabaseGeneratedOption.Identity);
            modelBuilder.Entity<CostElement>().Property(e => e.PayPlan).HasMaxLength(3);
            modelBuilder.Entity<CostElement>().Property(e => e.Appn).HasMaxLength(25);
            modelBuilder.Entity<CostElement>().Property(e => e.CostElementCategory).HasMaxLength(50);
            modelBuilder.Entity<CostElement>().Property(e => e.CostElementName).HasMaxLength(250);
            modelBuilder.Entity<CostElement>().Property(e => e.Description).HasMaxLength(3000);
            modelBuilder.Entity<CostElement>().Property(e => e.BusinessLogic).HasMaxLength(3000);
            modelBuilder.Entity<CostElement>().Property(e => e.BasisOfComputation).HasMaxLength(3000);
            modelBuilder.Entity<CostElement>().Property(e => e.Source).HasMaxLength(3000);
            modelBuilder.Entity<CostElement>().Property(e => e.ArmyCesTitle).HasMaxLength(300);
            modelBuilder.Entity<CostElement>().Property(e => e.OsdCapeCesTitle).HasMaxLength(300);
            modelBuilder.Entity<CostElement>().HasMany(e => e.CostSummaryElements).WithRequired(e => e.CostElement);

            modelBuilder.Entity<CostSummary>().ToTable("CostSummary", "lookup");
            modelBuilder.Entity<CostSummary>().HasKey(e => e.SummaryId);
            modelBuilder.Entity<CostSummary>().Property(e => e.SummaryId).HasDatabaseGeneratedOption(System.ComponentModel.DataAnnotations.Schema.DatabaseGeneratedOption.Identity);
            modelBuilder.Entity<CostSummary>().Property(e => e.PayPlan).HasMaxLength(3);
            modelBuilder.Entity<CostSummary>().Property(e => e.PayPlan).IsRequired();
            modelBuilder.Entity<CostSummary>().Property(e => e.Name).HasMaxLength(50);
            modelBuilder.Entity<CostSummary>().Property(e => e.Name).IsRequired();
            modelBuilder.Entity<CostSummary>().HasMany(e => e.CostSummaryElements).WithRequired(e => e.CostSummary);

            modelBuilder.Entity<CostSummaryElement>().ToTable("CostSummaryElement", "lookup");
            modelBuilder.Entity<CostSummaryElement>().HasKey(e => new { e.SummaryId, e.CostElementId });

            modelBuilder.Entity<Costs>().ToTable("Costs", "data");
            modelBuilder.Entity<Costs>().HasKey(e => e.RowId);
            modelBuilder.Entity<Costs>().Property(e => e.PayPlan).IsUnicode(true);
            modelBuilder.Entity<Costs>().Property(e => e.PayPlan).HasMaxLength(3);
            modelBuilder.Entity<Costs>().Property(e => e.CategoryGroupCode).IsUnicode(true);
            modelBuilder.Entity<Costs>().Property(e => e.CategoryGroupCode).HasMaxLength(4);
            modelBuilder.Entity<Costs>().Property(e => e.CategorySubgroupCode).IsUnicode(true);
            modelBuilder.Entity<Costs>().Property(e => e.CategorySubgroupCode).HasMaxLength(5);
            modelBuilder.Entity<Costs>().Property(e => e.CareerProgramNumber).IsUnicode(true);
            modelBuilder.Entity<Costs>().Property(e => e.CareerProgramNumber).HasMaxLength(2);
            modelBuilder.Entity<Costs>().Property(e => e.STRL).IsUnicode(true);
            modelBuilder.Entity<Costs>().Property(e => e.STRL).HasMaxLength(20);
            modelBuilder.Entity<Costs>().Property(e => e.AppropriationGroup).HasMaxLength(50);
            modelBuilder.Entity<Costs>().Property(e => e.Appn).HasMaxLength(25);
            modelBuilder.Entity<Costs>().Property(e => e.CostElementCategory).HasMaxLength(50);
            modelBuilder.Entity<Costs>().Property(e => e.CostElementName).HasMaxLength(250);
            modelBuilder.Entity<Costs>().Property(e => e.Description).HasMaxLength(3000);
            modelBuilder.Entity<Costs>().Property(e => e.GradeType).HasMaxLength(3);
            modelBuilder.Entity<Costs>().HasRequired(e => e.CategoryLookup).WithMany(e => e.Costs).HasForeignKey(e => new { e.PayPlan, e.CategoryGroupCode, e.CategorySubgroupCode });
            modelBuilder.Entity<Costs>().HasRequired(e => e.CategoryGroupLookup).WithMany(e => e.Costs).HasForeignKey(e => new { e.PayPlan, e.CategoryGroupCode });
            modelBuilder.Entity<Costs>().HasRequired(e => e.CategorySubgroupLookup).WithMany(e => e.Costs).HasForeignKey(e => new { e.PayPlan, e.CategoryGroupCode, e.CategorySubgroupCode });
            modelBuilder.Entity<Costs>().HasRequired(e => e.CareerProgramLookup).WithMany(e => e.Costs).HasForeignKey(e => new { e.CareerProgramNumber });

            modelBuilder.Entity<CostsAE>().Property(e => e.Amount).HasPrecision(26, 6);

            modelBuilder.Entity<CostsAO>().Property(e => e.Amount).HasPrecision(26, 6);

            modelBuilder.Entity<CostsAWO>().Property(e => e.Amount).HasPrecision(26, 6);

            modelBuilder.Entity<GFEBSCostCenter>().ToTable("GFEBS_CostCenter", "lookup");
            modelBuilder.Entity<GFEBSCostCenter>().HasKey(e => e.CostCenterCode);
            modelBuilder.Entity<GFEBSCostCenter>().Property(e => e.CostCenterCode).HasMaxLength(50);
            modelBuilder.Entity<GFEBSCostCenter>().Property(e => e.CostCenterText).HasMaxLength(250);

            modelBuilder.Entity<GFEBSFunctionalArea>().ToTable("GFEBS_FunctionalArea", "lookup");
            modelBuilder.Entity<GFEBSFunctionalArea>().HasKey(e => e.FunctionalAreaCode);
            modelBuilder.Entity<GFEBSFunctionalArea>().Property(e => e.FunctionalAreaCode).HasMaxLength(50);
            modelBuilder.Entity<GFEBSFunctionalArea>().Property(e => e.FunctionalAreaText).HasMaxLength(250);

            modelBuilder.Entity<Inventory>().ToTable("Inventory", "data");
            modelBuilder.Entity<Inventory>().HasKey(e => new { e.PayPlan, e.CategoryGroupCode, e.CategorySubgroupCode, e.Strl, e.LocationId, e.GradeType, e.GradeLevel, e.Step, e.AmcosVersionId });
            modelBuilder.Entity<Inventory>().Property(e => e.PayPlan).HasMaxLength(3);
            modelBuilder.Entity<Inventory>().Property(e => e.CategoryGroupCode).HasMaxLength(20);
            modelBuilder.Entity<Inventory>().Property(e => e.CategorySubgroupCode).HasMaxLength(4);
            modelBuilder.Entity<Inventory>().Property(e => e.Strl).HasMaxLength(20);
            modelBuilder.Entity<Inventory>().Property(e => e.GradeType).HasMaxLength(3);
            modelBuilder.Entity<Inventory>().Property(e => e.InventoryAmount).HasColumnName("Inventory");
            modelBuilder.Entity<Inventory>().HasRequired(e => e.LocationLookup).WithMany(e => e.Inventory).HasForeignKey(e => e.LocationId);

            modelBuilder.Entity<JicInflationRates>().ToTable("JicInflationRates", "lookup");
            modelBuilder.Entity<JicInflationRates>().HasKey(e => new { e.ConversionType, e.Year, e.Appropriation, e.AmcosVersionId });
            modelBuilder.Entity<JicInflationRates>().Property(e => e.ConversionType).HasMaxLength(25);
            modelBuilder.Entity<JicInflationRates>().Property(e => e.Year).HasColumnType("smallint");
            modelBuilder.Entity<JicInflationRates>().Property(e => e.Amount).HasPrecision(18, 15);

            modelBuilder.Entity<LocalityRates>().Property(e => e.Amount).HasPrecision(18, 4);

            modelBuilder.Entity<LocalityRates1>().ToTable("LocalityRates", "data");
            modelBuilder.Entity<LocalityRates1>().HasKey(e => e.LocalityId);
            modelBuilder.Entity<LocalityRates1>().Property(e => e.LocalityPay).HasColumnType("numeric");
            modelBuilder.Entity<LocalityRates1>().Property(e => e.LocalityPay).HasPrecision(18, 4);
            modelBuilder.Entity<LocalityRates1>().Property(e => e.LocalityDescription).HasMaxLength(120);

            modelBuilder.Entity<Location>().ToTable("Location", "warehouse");
            modelBuilder.Entity<Location>().HasKey(e => e.LocationId);
            modelBuilder.Entity<Location>().Property(e => e.SourceSystemCode).HasMaxLength(100);
            modelBuilder.Entity<Location>().Property(e => e.LocationType).HasMaxLength(100);
            modelBuilder.Entity<Location>().Property(e => e.DisplayName).HasMaxLength(100);

            modelBuilder.Entity<LocationByCategory>().ToTable("LocationByCategory", "warehouse");
            modelBuilder.Entity<LocationByCategory>().HasKey(e => e.Id);

            modelBuilder.Entity<MetropolitanStatisticalArea>().ToTable("MetropolitanStatisticalArea", "lookup");
            modelBuilder.Entity<MetropolitanStatisticalArea>().HasKey(e => new { e.MSACode, e.AmcosVersionIdEnd });
            modelBuilder.Entity<MetropolitanStatisticalArea>().Property(e => e.MSACode).HasMaxLength(7);
            modelBuilder.Entity<MetropolitanStatisticalArea>().Property(e => e.MSAName).HasMaxLength(100);

            modelBuilder.Entity<OccupationalEmploymentStatisticsMetro>().ToTable("OccupationalEmploymentStatisticsMetro", "BLS_OES");
            modelBuilder.Entity<OccupationalEmploymentStatisticsMetro>().HasKey(e => new { e.SOC, e.MSACode, e.AmcosVersionId });
            modelBuilder.Entity<OccupationalEmploymentStatisticsMetro>().Property(e => e.SOC).HasMaxLength(7);
            modelBuilder.Entity<OccupationalEmploymentStatisticsMetro>().Property(e => e.MSACode).HasMaxLength(7);
            modelBuilder.Entity<OccupationalEmploymentStatisticsMetro>().Property(e => e.Emp_Prse).HasPrecision(5, 2);
            modelBuilder.Entity<OccupationalEmploymentStatisticsMetro>().Property(e => e.A_Mean).HasPrecision(18, 0);
            modelBuilder.Entity<OccupationalEmploymentStatisticsMetro>().Property(e => e.Mean_Prse).HasPrecision(5, 2);
            modelBuilder.Entity<OccupationalEmploymentStatisticsMetro>().Property(e => e.A_Pct10).HasPrecision(18, 0);
            modelBuilder.Entity<OccupationalEmploymentStatisticsMetro>().Property(e => e.A_Pct25).HasPrecision(18, 0);
            modelBuilder.Entity<OccupationalEmploymentStatisticsMetro>().Property(e => e.A_Median).HasPrecision(18, 0);
            modelBuilder.Entity<OccupationalEmploymentStatisticsMetro>().Property(e => e.A_Pct75).HasPrecision(18, 0);
            modelBuilder.Entity<OccupationalEmploymentStatisticsMetro>().Property(e => e.A_Pct90).HasPrecision(18, 0);
            modelBuilder.Entity<OccupationalEmploymentStatisticsMetro>().HasRequired(e => e.MetropolitanStatisticalArea).WithMany(e => e.OccupationalEmploymentStatisticsMetros).HasForeignKey(e => new { e.MSACode, e.AmcosVersionId });
            modelBuilder.Entity<OccupationalEmploymentStatisticsMetro>().HasRequired(e => e.SOCStructure).WithMany(e => e.OccupationalEmploymentStatisticsMetros).HasForeignKey(e => e.SOC);

            modelBuilder.Entity<OccupationalEmploymentStatisticsNational>().ToTable("OccupationalEmploymentStatisticsNational", "BLS_OES");
            modelBuilder.Entity<OccupationalEmploymentStatisticsNational>().HasKey(e => e.SOC);
            modelBuilder.Entity<OccupationalEmploymentStatisticsNational>().Property(e => e.SOC).HasMaxLength(7);
            modelBuilder.Entity<OccupationalEmploymentStatisticsNational>().Property(e => e.Emp_Prse).HasPrecision(5, 2);
            modelBuilder.Entity<OccupationalEmploymentStatisticsNational>().Property(e => e.A_Mean).HasPrecision(18, 0);
            modelBuilder.Entity<OccupationalEmploymentStatisticsNational>().Property(e => e.Mean_Prse).HasPrecision(5, 2);
            modelBuilder.Entity<OccupationalEmploymentStatisticsNational>().Property(e => e.A_Pct10).HasPrecision(18, 0);
            modelBuilder.Entity<OccupationalEmploymentStatisticsNational>().Property(e => e.A_Pct25).HasPrecision(18, 0);
            modelBuilder.Entity<OccupationalEmploymentStatisticsNational>().Property(e => e.A_Median).HasPrecision(18, 0);
            modelBuilder.Entity<OccupationalEmploymentStatisticsNational>().Property(e => e.A_Pct75).HasPrecision(18, 0);
            modelBuilder.Entity<OccupationalEmploymentStatisticsNational>().Property(e => e.A_Pct90).HasPrecision(18, 0);

            modelBuilder.Entity<OPMSpecialRate>().ToTable("OPM_SpecialRate", "lookup");
            modelBuilder.Entity<OPMSpecialRate>().HasKey(e => new { e.SpecialRateTableNumber, e.OccupationalSeriesNumber, e.LocalityId });
            modelBuilder.Entity<OPMSpecialRate>().Property(e => e.SpecialRateTableNumber).HasMaxLength(4);
            modelBuilder.Entity<OPMSpecialRate>().Property(e => e.OccupationalSeriesNumber).HasMaxLength(4);
            modelBuilder.Entity<OPMSpecialRate>().Property(e => e.OccupationName).HasMaxLength(100);

            modelBuilder.Entity<PayPlan>().ToTable("PayPlan", "lookup");
            modelBuilder.Entity<PayPlan>().HasKey(e => new { e.Name, e.AmcosVersionIdEnd });
            modelBuilder.Entity<PayPlan>().Property(e => e.Name).HasMaxLength(3);
            modelBuilder.Entity<PayPlan>().Property(e => e.Name).HasColumnName("PayPlan");
            modelBuilder.Entity<PayPlan>().Property(e => e.Description).HasMaxLength(50);
            modelBuilder.Entity<PayPlan>().Property(e => e.CategoryGroupLabel).HasMaxLength(50);
            modelBuilder.Entity<PayPlan>().Property(e => e.CategorySubgroupLabel).HasMaxLength(50);
            modelBuilder.Entity<PayPlan>().Property(e => e.DisplayTitle).HasMaxLength(75);
            modelBuilder.Entity<PayPlan>().Property(e => e.GroupTitle).HasMaxLength(50);
            modelBuilder.Entity<PayPlan>().Property(e => e.Explanation).HasMaxLength(500);

            modelBuilder.Entity<PayPlanTag>().ToTable("PayPlanTag", "web");
            modelBuilder.Entity<PayPlanTag>().HasKey(e => new { e.PayPlan, e.Tag });
            modelBuilder.Entity<PayPlanTag>().Property(e => e.PayPlan).HasMaxLength(3);
            modelBuilder.Entity<PayPlanTag>().Property(e => e.Tag).HasMaxLength(25);

            modelBuilder.Entity<PayScheduleMinMax>().ToTable("PayScheduleMinMax", "crunch");
            modelBuilder.Entity<PayScheduleMinMax>().HasKey(e => new { e.PayPlan, e.CategoryGroupCode, e.CategorySubgroupCode, e.CareerProgramNumber, e.LocationId, e.Strl, e.GradeLevel });
            modelBuilder.Entity<PayScheduleMinMax>().Property(e => e.PayPlan).HasMaxLength(3);
            modelBuilder.Entity<PayScheduleMinMax>().Property(e => e.CategoryGroupCode).HasMaxLength(4);
            modelBuilder.Entity<PayScheduleMinMax>().Property(e => e.CategorySubgroupCode).HasMaxLength(5);
            modelBuilder.Entity<PayScheduleMinMax>().Property(e => e.CareerProgramNumber).HasMaxLength(3);
            modelBuilder.Entity<PayScheduleMinMax>().Property(e => e.Strl).HasMaxLength(3);
            modelBuilder.Entity<PayScheduleMinMax>().Property(e => e.MinRate).HasPrecision(18, 2);
            modelBuilder.Entity<PayScheduleMinMax>().Property(e => e.MaxRate).HasPrecision(18, 2);

            modelBuilder.Entity<PaySchedules>().ToTable("PaySchedules", "data");
            modelBuilder.Entity<PaySchedules>().HasKey(e => new { e.PayPlan, e.CategoryGroupCode, e.CategorySubgroupCode, e.LocationId, e.Strl, e.GradeType, e.GradeLevel, e.Step, e.YOS, e.RateType, e.AmcosVersionId });
            modelBuilder.Entity<PaySchedules>().Property(e => e.PayPlan).HasMaxLength(3);
            modelBuilder.Entity<PaySchedules>().Property(e => e.CategoryGroupCode).HasMaxLength(4);
            modelBuilder.Entity<PaySchedules>().Property(e => e.CategorySubgroupCode).HasMaxLength(5);
            modelBuilder.Entity<PaySchedules>().Property(e => e.Strl).HasMaxLength(20);
            modelBuilder.Entity<PaySchedules>().Property(e => e.GradeType).HasMaxLength(3);
            modelBuilder.Entity<PaySchedules>().Property(e => e.RateType).HasMaxLength(25);
            modelBuilder.Entity<PaySchedules>().Property(e => e.Rate).HasColumnType("numeric");
            modelBuilder.Entity<PaySchedules>().HasRequired(e => e.LocationLookup).WithMany(e => e.PaySchedules).HasForeignKey(e => e.LocationId );

            modelBuilder.Entity<PCSProject>().ToTable("PCSProject", "webuser");
            modelBuilder.Entity<PCSProject>().HasKey(e => new { e.UserId, e.ProjectName });
            modelBuilder.Entity<PCSProject>().Property(e => e.UserId).HasMaxLength(50).IsRequired();
            modelBuilder.Entity<PCSProject>().Property(e => e.ProjectName).HasMaxLength(50).IsRequired();
            modelBuilder.Entity<PCSProject>().Property(e => e.ProjectSaveDate).IsRequired();
            modelBuilder.Entity<PCSProject>().Property(e => e.ConversionType).HasMaxLength(25).IsRequired();
            modelBuilder.Entity<PCSProject>().Property(e => e.Appropriation).HasMaxLength(25).IsRequired();
            modelBuilder.Entity<PCSProject>().Property(e => e.AmcosVersionId).IsRequired();
            modelBuilder.Entity<PCSProject>().Property(e => e.OriginationId).IsRequired();
            modelBuilder.Entity<PCSProject>().Property(e => e.DestinationId).IsRequired();

            modelBuilder.Entity<PendingUsers>().ToTable("PendingUsers", "web");
            modelBuilder.Entity<PendingUsers>().HasKey(e => e.UserInfo);

            modelBuilder.Entity<PMCategory>().ToTable("PMCategory", "webuser");
            modelBuilder.Entity<PMCategory>().HasKey(e => new { e.CategoryId });
            modelBuilder.Entity<PMCategory>().Property(e => e.CategoryId).HasDatabaseGeneratedOption(System.ComponentModel.DataAnnotations.Schema.DatabaseGeneratedOption.Identity);
            modelBuilder.Entity<PMCategory>().Property(e => e.CategoryName).HasMaxLength(50);

            modelBuilder.Entity<PMCategorySkill>().ToTable("PMCategorySkill", "webuser");
            modelBuilder.Entity<PMCategorySkill>().HasKey(e => new { e.SkillId });
            modelBuilder.Entity<PMCategorySkill>().HasIndex(e => new { e.CategoryId, e.PayPlan, e.CategoryGroupCode, e.CategorySubgroupCode, e.CareerProgramNumber, e.LocationId, e.STRL, e.GradeLevel, e.DependentStatus, e.ActiveDutyDays, e.OverheadPercent }).HasName("AK_PMCategorySkill_Unique").IsUnique();
            modelBuilder.Entity<PMCategorySkill>().Property(e => e.SkillId).HasDatabaseGeneratedOption(System.ComponentModel.DataAnnotations.Schema.DatabaseGeneratedOption.Identity);
            modelBuilder.Entity<PMCategorySkill>().Property(e => e.Uic).HasMaxLength(6);
            modelBuilder.Entity<PMCategorySkill>().Property(e => e.PayPlan).HasMaxLength(3);
            modelBuilder.Entity<PMCategorySkill>().Property(e => e.CategoryGroupCode).HasMaxLength(10);
            modelBuilder.Entity<PMCategorySkill>().Property(e => e.CategorySubgroupCode).HasMaxLength(10);
            modelBuilder.Entity<PMCategorySkill>().Property(e => e.CareerProgramNumber).HasMaxLength(2);
            modelBuilder.Entity<PMCategorySkill>().Property(e => e.STRL).HasMaxLength(20);
            modelBuilder.Entity<PMCategorySkill>().Property(e => e.DependentStatus).HasMaxLength(25);

            modelBuilder.Entity<PMCategorySkillInventory>().ToTable("PMCategorySkillInventory", "webuser");
            modelBuilder.Entity<PMCategorySkillInventory>().HasKey(e => new { e.InventoryId });
            modelBuilder.Entity<PMCategorySkillInventory>().Property(e => e.InventoryId).HasDatabaseGeneratedOption(System.ComponentModel.DataAnnotations.Schema.DatabaseGeneratedOption.Identity);
            modelBuilder.Entity<PMCategorySkillInventory>().HasRequired(e => e.PMCategorySkillRecord).WithMany(e => e.Inventories).HasForeignKey(e => e.SkillId);

            modelBuilder.Entity<PMProject>().ToTable("PMProject", "webuser");
            modelBuilder.Entity<PMProject>().HasKey(e => e.ProjectId);
            modelBuilder.Entity<PMProject>().Property(e => e.ProjectId).HasDatabaseGeneratedOption(System.ComponentModel.DataAnnotations.Schema.DatabaseGeneratedOption.Identity);
            modelBuilder.Entity<PMProject>().Property(e => e.UserId).HasMaxLength(50);
            modelBuilder.Entity<PMProject>().Property(e => e.ProjectName).HasMaxLength(50);
            modelBuilder.Entity<PMProject>().Property(e => e.ProjectCreator).HasMaxLength(50);

            modelBuilder.Entity<PMReport>().ToTable("PMReport", "webuser");
            modelBuilder.Entity<PMReport>().HasKey(e => e.ReportId);
            modelBuilder.Entity<PMReport>().Property(e => e.ReportId).HasDatabaseGeneratedOption(System.ComponentModel.DataAnnotations.Schema.DatabaseGeneratedOption.Identity);
            modelBuilder.Entity<PMReport>().Property(e => e.PayPlan).HasMaxLength(3);

            modelBuilder.Entity<ProjectAddUnitAudit>().ToTable("ProjectAddUnitAudit", "webuser");
            modelBuilder.Entity<ProjectAddUnitAudit>().HasKey(e => new { e.UserId, e.CreateDate });
            modelBuilder.Entity<ProjectAddUnitAudit>().Property(e => e.UserId).HasMaxLength(50);
            modelBuilder.Entity<ProjectAddUnitAudit>().Property(e => e.UIC).HasMaxLength(6);
            modelBuilder.Entity<ProjectAddUnitAudit>().Property(e => e.ExcludedPayPlans).HasMaxLength(50);
            modelBuilder.Entity<ProjectAddUnitAudit>().Property(e => e.DataAction).HasMaxLength(7);
            modelBuilder.Entity<ProjectAddUnitAudit>().Property(e => e.NewSubprojectName).HasMaxLength(50);


            modelBuilder.Entity<SingleValues>().ToTable("SingleValues", "dataload");
            modelBuilder.Entity<SingleValues>().HasKey(e => new { e.PayPlan, e.ParamName, e.AmcosVersionId });
            modelBuilder.Entity<SingleValues>().Property(e => e.PayPlan).HasMaxLength(10);
            modelBuilder.Entity<SingleValues>().Property(e => e.ParamName).HasMaxLength(100);
            modelBuilder.Entity<SingleValues>().Property(e => e.ParamValue).HasPrecision(26, 6);
            modelBuilder.Entity<SingleValues>().Property(e => e.ParamDesc).HasMaxLength(500);
            modelBuilder.Entity<SingleValues>().Property(e => e.Comments).HasMaxLength(300);

            modelBuilder.Entity<SOCStructure>().ToTable("SOCStructure", "lookup");
            modelBuilder.Entity<SOCStructure>().HasKey(e => e.OccupationCode);
            modelBuilder.Entity<SOCStructure>().Property(e => e.OccupationCode).HasMaxLength(7);
            modelBuilder.Entity<SOCStructure>().Property(e => e.GroupLevel).HasMaxLength(10);
            modelBuilder.Entity<SOCStructure>().Property(e => e.OccupationTitle).HasMaxLength(255);
            modelBuilder.Entity<SOCStructure>().Property(e => e.Definition).HasMaxLength(3000);

            modelBuilder.Entity<SubgroupMapping>().ToTable("SubgroupMapping", "lookup");
            modelBuilder.Entity<SubgroupMapping>().HasKey(e => new { e.PayPlan, e.CategorySubgroupCode, e.ToPayPlan, e.ToCategorySubgroupCode });
            modelBuilder.Entity<SubgroupMapping>().Property(e => e.PayPlan).HasMaxLength(3);
            modelBuilder.Entity<SubgroupMapping>().Property(e => e.CategorySubgroupCode).HasMaxLength(7);
            modelBuilder.Entity<SubgroupMapping>().Property(e => e.ToPayPlan).HasMaxLength(3);
            modelBuilder.Entity<SubgroupMapping>().Property(e => e.ToCategorySubgroupCode).HasMaxLength(7);

            modelBuilder.Entity<UnitPersonnel>().ToTable("UnitPersonnel", "warehouse");
            modelBuilder.Entity<UnitPersonnel>().HasKey(e => new { e.UIC, e.PayPlan, e.CategoryGroupCode, e.CategorySubgroupCode, e.LocationId, e.STRL, e.GradeLevel, e.DependentStatus, e.NumberOfDependents, e.UnitYear, e.AsOf });
            modelBuilder.Entity<UnitPersonnel>().Property(e => e.UIC).HasMaxLength(6);
            modelBuilder.Entity<UnitPersonnel>().Property(e => e.UICTitle).HasMaxLength(150);
            modelBuilder.Entity<UnitPersonnel>().Property(e => e.PayPlan).HasMaxLength(3);
            modelBuilder.Entity<UnitPersonnel>().Property(e => e.CategoryGroupCode).HasMaxLength(10);
            modelBuilder.Entity<UnitPersonnel>().Property(e => e.CategorySubgroupCode).HasMaxLength(10);
            modelBuilder.Entity<UnitPersonnel>().Property(e => e.LocationText).HasMaxLength(150);
            modelBuilder.Entity<UnitPersonnel>().Property(e => e.STRL).HasMaxLength(20);
            modelBuilder.Entity<UnitPersonnel>().Property(e => e.DependentStatus).HasMaxLength(25);
            modelBuilder.Entity<UnitPersonnel>().Property(e => e.UnitYear).HasMaxLength(4);
            modelBuilder.Entity<UnitPersonnel>().Property(e => e.AsOf).HasMaxLength(8);
            modelBuilder.Entity<UnitPersonnel>().Property(e => e.AuthorizationDocument).HasMaxLength(50);

            modelBuilder.Entity<UserLoginHistory>().Property(e => e.UserId).IsUnicode(false);
            modelBuilder.Entity<UserLoginHistory>().Property(e => e.Browser).IsUnicode(false);
            modelBuilder.Entity<UserLoginHistory>().Property(e => e.BrowserVersion).IsUnicode(false);

            modelBuilder.Entity<UserLoginHistoryDeletedUsers>().Property(e => e.UserId).IsUnicode(false);
            modelBuilder.Entity<UserLoginHistoryDeletedUsers>().Property(e => e.Browser).IsUnicode(false);
            modelBuilder.Entity<UserLoginHistoryDeletedUsers>().Property(e => e.BrowserVersion).IsUnicode(false);

            modelBuilder.Entity<UserMACOM>().Property(e => e.MACOM).IsFixedLength().IsUnicode(false);
            modelBuilder.Entity<UserMACOM>().Property(e => e.MACOM_Name).IsFixedLength().IsUnicode(false);
            modelBuilder.Entity<UserMACOM>().Property(e => e.Description).IsFixedLength().IsUnicode(false);

            modelBuilder.Entity<ValidEmailSuffix>().ToTable("ValidEmailSuffix", "lookup");
            modelBuilder.Entity<ValidEmailSuffix>().HasKey(e => new { e.EmailSuffix });
            modelBuilder.Entity<ValidEmailSuffix>().Property(e => e.EmailSuffix).HasMaxLength(25);

            modelBuilder.Entity<ViewPMCategorySkill>().ToTable("PMCategorySkill", "web");
            modelBuilder.Entity<ViewPMCategorySkill>().HasKey(e => new { e.ProjectId, e.CategoryName, e.PayPlan });
            modelBuilder.Entity<ViewPMCategorySkill>().Property(e => e.ProjectName).HasMaxLength(50);
            modelBuilder.Entity<ViewPMCategorySkill>().Property(e => e.CategoryName).HasMaxLength(50);
            modelBuilder.Entity<ViewPMCategorySkill>().Property(e => e.PayPlan).HasMaxLength(3);
            modelBuilder.Entity<ViewPMCategorySkill>().Property(e => e.CategoryGroupCode).HasMaxLength(10);
            modelBuilder.Entity<ViewPMCategorySkill>().Property(e => e.CategorySubgroupCode).HasMaxLength(10);
            modelBuilder.Entity<ViewPMCategorySkill>().Property(e => e.CareerProgramNumber).HasMaxLength(2);
            modelBuilder.Entity<ViewPMCategorySkill>().Property(e => e.LocationText).HasMaxLength(150);
            modelBuilder.Entity<ViewPMCategorySkill>().Property(e => e.STRL).HasMaxLength(20);
            modelBuilder.Entity<ViewPMCategorySkill>().Property(e => e.DependentStatus).HasMaxLength(25);

            modelBuilder.Entity<VCostsProd>().Property(e => e.PayPlan).IsUnicode(false);
            modelBuilder.Entity<VCostsProd>().Property(e => e.CategoryGroupCode).IsUnicode(false);
            modelBuilder.Entity<VCostsProd>().Property(e => e.CategorySubgroupCode).IsUnicode(false);
            modelBuilder.Entity<VCostsProd>().Property(e => e.WageArea).IsUnicode(false);
            modelBuilder.Entity<VCostsProd>().Property(e => e.GradeType).IsUnicode(false);

            modelBuilder.Entity<QuickSightDashboard>().ToTable("QuickSightDashboard", "web");
            modelBuilder.Entity<QuickSightDashboard>().HasKey(e => e.InitialDashboardId);

            modelBuilder.Entity<QuickSightEnvironment>().ToTable("QuickSightEnvironment", "web");
            modelBuilder.Entity<QuickSightEnvironment>().HasKey(e => e.AwsAccountId);

        }
        public void AddLogging(AMCOSLiteAudit amcosLiteAuditObject)
        {
            AMCOSLiteAudit.Add(amcosLiteAuditObject);
            SaveChanges();
        }                
        public virtual DbSet<AMCOSLiteAudit> AMCOSLiteAudit { get; set; }
        public virtual DbSet<AMCOSVersion> AMCOSVersion { get; set; }
        public virtual DbSet<AOC> AOC { get; set; }
        public virtual DbSet<AvalaraStateTax> AvalaraStateTax { get; set; }
        public virtual DbSet<Category> Category { get; set; }
        public virtual DbSet<CategoryGroup> CategoryGroup { get; set; }
        public virtual DbSet<CategorySubgroup> CategorySubgroup { get; set; }
        public virtual DbSet<CivLocationPerDiem> CivLocationPerDiem { get; set; }
        public virtual DbSet<Costs> Costs { get; set; }
        public virtual DbSet<CostsAE> CostsAE { get; set; }
        public virtual DbSet<CostsAO> CostsAO { get; set; }
        public virtual DbSet<CostsAWO> CostsAWO { get; set; }
        public virtual DbSet<CostsNGRes1> CostsNGRes1 { get; set; }
        public virtual DbSet<CMFBranchFA> CMFBranchFA { get; set; }
        public virtual DbSet<CostElement> CostElement { get; set; }
        public virtual DbSet<CostSummary> CostSummary { get; set; }
        public virtual DbSet<CostSummaryElement> CostSummaryElement { get; set; }
        public virtual DbSet<CostsGPProd> CostsGPProd { get; set; }
        public virtual DbSet<CostsProd> CostsProd { get; set; }
        public virtual DbSet<CostsTest> CostsTest { get; set; }
        public virtual DbSet<FIPSZip> FIPSZip { get; set; }
        public virtual DbSet<GFEBSCostCenter> GFEBSCostCenter { get; set; }
        public virtual DbSet<GFEBSFunctionalArea> GFEBSFunctionalArea { get; set; }
        public virtual DbSet<GSOccupationalGroup> GSOccupationalGroup { get; set; }
        public virtual DbSet<GSOccupationalSeries> GSOccupationalSeries { get; set; }
        public virtual DbSet<GPInventory> GPInventory { get; set; }
        public virtual DbSet<JicInflationRates> JicInflationRates { get; set; }
        public virtual DbSet<LocalityRates> LocalityRates { get; set; }
        public virtual DbSet<Location> Locations { get; set; }
        public virtual DbSet<LocationByCategory> LocationByCategory { get; set; }
        public virtual DbSet<MetropolitanStatisticalArea> MetropolitanStatisticalArea { get; set; }
        public virtual DbSet<MOS> MOS { get; set; }
        public virtual DbSet<OccupationalEmploymentStatisticsMetro> OccupationalEmploymentStatisticsMetro { get; set; }
        public virtual DbSet<OccupationalEmploymentStatisticsNational> OccupationalEmploymentStatisticsNational { get; set; }
        public virtual DbSet<OPMSpecialRate> OPMSpecialRate { get; set;  }        
        public virtual DbSet<Organization> Organization { get; set; }
        public virtual DbSet<PayPlan> PayPlan { get; set; }
        public virtual DbSet<PayPlanTag> PayPlanTags { get; set; }
        public virtual DbSet<PayScheduleMinMax> PayScheduleMinMax { get; set; }
        public virtual DbSet<PendingUsers> PendingUsers { get; set; }
        public virtual DbSet<ProjectAddUnitAudit> ProjectAddUnitAudit { get; set; }
        public virtual DbSet<SOCStructure> SOCStructure { get; set; }
        public virtual DbSet<AMCOSUser> AMCOSUser { get; set; }
        public virtual DbSet<PCSProject> PCSProject { get; set; }
        public virtual DbSet<PMCategory> PMCategory { get; set; }
        public virtual DbSet<PMCategorySkill> PMCategorySkill { get; set; }
        public virtual DbSet<PMCategorySkillInventory> PMCategorySkillInventory { get; set; }
        public virtual DbSet<PMProject> PMProject { get; set; }
        public virtual DbSet<PMReport> PMReport { get; set; }
        public virtual DbSet<ApplicationErrorLog> ApplicationErrorLog { get; set; }
        public virtual DbSet<UserLoginHistory> UserLoginHistory { get; set; }
        public virtual DbSet<InventoryProduction> InventoryProduction { get; set; }
        public virtual DbSet<Grade> Grade { get; set; }
        public virtual DbSet<LocalityPayAreaFIPS> LocalityPayAreaFIPS { get; set; }
        public virtual DbSet<SubgroupMapping> SubgroupMapping { get; set; }
        public virtual DbSet<UnitPersonnel> UnitPersonnel { get; set; }
        public virtual DbSet<UserLoginHistoryDeletedUsers> UserLoginHistoryDeletedUsers { get; set; }
        public virtual DbSet<UserMACOM> UserMACOM { get; set; }
        public virtual DbSet<Inventory> Inventory { get; set; }
        public virtual DbSet<LocalityRates1> LocalityRates1 { get; set; }
        public virtual DbSet<PaySchedules> PaySchedules { get; set; }
        public virtual DbSet<SingleValues> SingleValues { get; set; }  
        public virtual DbSet<ValidEmailSuffix> ValidEmailSuffix { get; set; }
        public virtual DbSet<VCostsProd> VCostsProd { get; set; }
        public virtual DbSet<VCostsTest> VCostsTest { get; set; }
        public virtual DbSet<ViewPMCategorySkill> ViewPMCategorySkill { get; set; }
        public virtual DbSet<WageArea> WageArea { get; set; }
        public virtual DbSet<WOMOS> WOMOS { get; set; }
        public virtual DbSet<QuickSightDashboard> QuickSightDashboards { get; set; }
        public virtual DbSet<QuickSightEnvironment> QuickSightEnvironments { get; set; }
    }
}
