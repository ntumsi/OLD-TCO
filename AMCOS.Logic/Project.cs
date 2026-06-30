using AMCOS.Data;
using AMCOS.Data.DataTransferObjects;
using AMCOS.Data.Entities;
using AMCOS.Data.ViewModels;
using System;
using System.Collections.Generic;
using System.Data;
using Npgsql;
using NpgsqlTypes;
using System.Linq;

namespace AMCOS.Logic
{
    public class Project
    {
        public DateTime CreateDate { get; set; }
        public string Description { get; set; }
        public double[] DiscountRate { get; set; }
        public DateTime LastUpdate { get; set; }
        public string ProjectName { get; set; }
        public string ProjectCreator { get; set; }
        public int ProjectId { get; set; }
        public string ProjectType { get; set; }
        public int ReserveDaysActive { get; set; }
        public int ReserveDaysInActive { get; set; }
        public string UserId { get; set; }
        public int YearDuration { get; set; }
        public int YearStart { get; set; }


        public int Copy(int projectId, string projectName, string projectDescription)
        {
            int rowsAffected = 0;
            using (var context = new ApplicationDbContext())
            {
                // web.pmcopyproject is a FUNCTION (RETURNS void), so it must be invoked with
                // SELECT, not CALL (CALL is only valid for procedures in PostgreSQL).
                rowsAffected = context.Database.ExecuteSqlRaw("SELECT web.pmcopyproject(@ProjectId, @ProjectName, @Description)",
                    new NpgsqlParameter("@ProjectId", projectId),
                    new NpgsqlParameter("@ProjectName", projectName),
                    new NpgsqlParameter("@Description", projectDescription));
            }
            return rowsAffected;
        }
        private int GetMainCategoryId(int ProjectId)
        {
            int returnValue = 0;
            using (var context = new ApplicationDbContext())
            {
                var query = (from category in context.PMCategory.AsNoTracking()
                            join project in context.PMProject on category.ProjectId equals project.ProjectId
                            where project.ProjectName == category.CategoryName
                            where project.ProjectId == ProjectId
                            select category).FirstOrDefault();
                if (query != null)
                {
                    returnValue = query.CategoryId;
                }
            }
            return returnValue;
        }
        public List<MtoeUnitYearDto> GetMtoeUnitYears(string unitIdentificationCode)
        {
            using (var context = new ApplicationDbContext())
            {
                return context.UnitPersonnel.AsNoTracking()
                    .Where(c => c.UIC == unitIdentificationCode)
                    .OrderBy(c => c.UnitYear)
                    .Select(c => new MtoeUnitYearDto()
                    {
                        Value = c.UnitYear,
                        Text = c.UnitYear
                    })
                    .Distinct()
                    .ToList();
            }
        }
        public PMProject GetProject(int projectId)
        {
            using (var context = new ApplicationDbContext())
            {
                var result = context.PMProject.Find(projectId);
                return result;
            }
        }
        public List<ProjectOutputListDto> GetProjectOutputs(int projectId)
        {
            using (var context = new ApplicationDbContext())
            {
                return context.ViewPMCategorySkill.AsNoTracking()
                    .Where(c => c.ProjectId == projectId)
                    .GroupBy(c => new { c.CategoryName, c.CategoryId, c.PayPlan })
                    .Select(output => new ProjectOutputListDto()
                    {
                        CategoryId = output.Key.CategoryId,
                        Category = output.Key.CategoryName,
                        PayPlan = output.Key.PayPlan
                    })
                    .ToList();
            }
        }
        public List<UnitLocationDto> GetUnitLocations(string unitIdentificationCode)
        {
            using (var context = new ApplicationDbContext())
            {
                return context.UnitPersonnel.AsNoTracking()
                    .Where(c => c.UIC == unitIdentificationCode)
                    .GroupBy(c => new { c.PayPlan, c.LocationText })
                    .Select(group => new UnitLocationDto()
                    {
                        PayPlan = group.Key.PayPlan,
                        Location = group.Key.LocationText
                    })
                    .ToList();
            }
        }
        //public List<UnitPersonnel> GetUnitPersonnel(string unitIdentificationCode)
        //{
        //    using (var context = new ApplicationDbContext())
        //    {
        //        return context.UnitPersonnel.AsNoTracking()
        //            .Where(c => c.UIC == unitIdentificationCode)
        //            .ToList();
        //    }
        //}
        public List<UnitPersonnelDto> GetUnitPersonnel(string unitIdentificationCode)
        {
            using (var context = new ApplicationDbContext())
            {
                return context.UnitPersonnel.AsNoTracking()
                    .Where(c => c.UIC == unitIdentificationCode)
                    .GroupBy(c => c.PayPlan)
                    .Select(group => new UnitPersonnelDto()
                    {
                        PayPlan = group.Key,
                        Inventory = group.Sum(c => c.Inventory)
                    })
                    .ToList();
            }
        }
        private bool IsTda(string unitIdentificationCode)
        {
            using (var context = new ApplicationDbContext())
            {
                string unitType = context.UnitPersonnel.AsNoTracking()
                    .Where(c => c.UIC == unitIdentificationCode)
                    .Select(c => c.AuthorizationDocument)
                    .First();

                if (unitType.Contains("TDA"))
                {
                    return true;
                } else
                {
                    return false;
                }
            }
        }
        private bool IsMtoe(string unitIdentificationCode)
        {
            using (var context = new ApplicationDbContext())
            {
                string unitType = context.UnitPersonnel.AsNoTracking()
                    .Where(c => c.UIC == unitIdentificationCode)
                    .Select(c => c.AuthorizationDocument)
                    .First();

                if (unitType == "MTOE")
                {
                    return true;
                }
                else
                {
                    return false;
                }
            }
        }
        public List<UnitPersonnelAndLocationDto> GetUnitPersonnelAndLocation(string unitIdentificationCode, int projectStartYear)
        {
            using (var context = new ApplicationDbContext())
            {
                if (IsTda(unitIdentificationCode)) {
                    var query = from c in context.UnitPersonnel.AsNoTracking()
                                group c by new { c.UIC, c.PayPlan, c.LocationText, c.UnitYear, c.AsOf, c.AuthorizationDocument } into g
                                where g.Key.UIC == unitIdentificationCode
                                select new UnitPersonnelAndLocationDto()
                                {
                                    UIC = g.Key.UIC,
                                    PayPlan = g.Key.PayPlan,
                                    Location = g.Key.LocationText,
                                    AuthorizationDocument = g.Key.AuthorizationDocument,
                                    Inventory = g.Sum(x => x.Inventory),
                                    UnitYear = g.Key.UnitYear,
                                    AsOf = g.Key.AsOf,
                                    NumUnitYears = 0
                                };
                    return query.ToList();

                } else {
                    var maxYear = context.UnitPersonnel.AsNoTracking()
                        .Where(c => c.UIC == unitIdentificationCode)
                        .Where(c => c.UnitYear != "OTOE")
                        .Select(c => c.UnitYear)
                        .Max();

                    var numUnitYears = context.UnitPersonnel.AsNoTracking()
                        .Where(c => c.UIC == unitIdentificationCode)
                        .Where(c => c.UnitYear != "OTOE")
                        .Select(c => c.UnitYear)
                        .Distinct()
                        .Count();

                    var unitYear = Math.Min(projectStartYear, Int32.Parse(maxYear));
                    var query = from c in context.UnitPersonnel.AsNoTracking()
                                group c by new { c.UIC, c.PayPlan, c.LocationText, c.UnitYear, c.AsOf, c.AuthorizationDocument } into g
                                where g.Key.UIC == unitIdentificationCode && g.Key.UnitYear == unitYear.ToString()
                                select new UnitPersonnelAndLocationDto()
                                {
                                    UIC = g.Key.UIC,
                                    PayPlan = g.Key.PayPlan,
                                    Location = g.Key.LocationText,
                                    AuthorizationDocument = g.Key.AuthorizationDocument,
                                    Inventory = g.Sum(x => x.Inventory),
                                    UnitYear = unitYear.ToString(),
                                    AsOf = g.Key.AsOf,
                                    NumUnitYears = numUnitYears
                                };
                    return query.ToList();
                }                
            }
        }
        public void DeleteReportByCategory(int categoryId)
        {
            using (var context = new ApplicationDbContext())
            {
                var recordsToRemove = context.PMReport
                    .Where(c => c.CategoryId == categoryId)
                    .Select(c => c.CategoryId);

                if (recordsToRemove != null)
                {
                    context.PMReport.RemoveRange(context.PMReport.Where(c => recordsToRemove.Contains(c.CategoryId)));
                    context.SaveChanges();
                }
            }
        }
        public void DeleteReportByProject(int projectId)
        {
            using (var context = new ApplicationDbContext())
            {
                var recordsToRemove = context.PMCategory
                    .Where(c => c.ProjectId == projectId)
                    .Select(c => c.CategoryId);

                if (recordsToRemove != null)
                {
                    context.PMReport.RemoveRange(context.PMReport.Where(c => recordsToRemove.Contains(c.CategoryId)));
                    context.SaveChanges();
                }
            }
        }
        public DiscountFactor GetDiscountFactors(int amcosVersionId)
        {
            DiscountFactor returnValue = new DiscountFactor
            {
                DiscountFactorYear3 = SingleValue.Get("ALL", "projectReport_DiscountFactor_Year3", amcosVersionId),
                DiscountFactorYear5 = SingleValue.Get("ALL", "projectReport_DiscountFactor_Year5", amcosVersionId),
                DiscountFactorYear7 = SingleValue.Get("ALL", "projectReport_DiscountFactor_Year7", amcosVersionId),
                DiscountFactorYear10 = SingleValue.Get("ALL", "projectReport_DiscountFactor_Year10", amcosVersionId),
                DiscountFactorYear20 = SingleValue.Get("ALL", "projectReport_DiscountFactor_Year20", amcosVersionId),
                DiscountFactorYear30 = SingleValue.Get("ALL", "projectReport_DiscountFactor_Year30", amcosVersionId)
            };
            return returnValue;
        }
        public void InsertReport(int categoryId, string payPlan)
        {
            using (var context = new ApplicationDbContext())
            {
                context.PMReport.Add(new PMReport { CategoryId = categoryId, PayPlan = payPlan });
                context.SaveChanges();
            }
        }
        private short? ActiveDutyDaysDisplay(string payPlan, short activeDutyDays)
        {
            _ = payPlan ?? throw new ArgumentNullException(nameof(payPlan));

            string[] payPlansThatRequireActiveDutyDays = { "NE", "NO", "NWO", "RE", "RO", "RWO" };
            if (Array.Exists(payPlansThatRequireActiveDutyDays, element => element == payPlan))
            {
                if (activeDutyDays == -1)
                {
                    return null;
                }
                else
                {
                    return activeDutyDays;
                }
            }
            else
            {
                return null;
            }
        }
        public void AddProject()
        {
            using (var context = new ApplicationDbContext())
            {
                var pmProject = new PMProject
                {
                    UserId = UserId,
                    ProjectName = ProjectName,
                    YearStart = YearStart,
                    Description = Description                    
                };
                context.PMProject.Add(pmProject);
                context.SaveChanges();
            }
        }
        public void ReplaceProject(int projectId, string uic, string notSelectedPayPlans, string unitLocation, string mtoeProjectInventoryYear, string mtoeSyncExtendedDuration, decimal userOverheadPercent, int amcosVersionId)
        {
            int categoryId = GetMainCategoryId(projectId);
            if (categoryId != 0) {
                ProjectRequirement projectRequirement = new ProjectRequirement();
                projectRequirement.DeletePMCategorySkillAll(categoryId);
                AddUnit(categoryId, uic, notSelectedPayPlans, unitLocation, mtoeProjectInventoryYear, mtoeSyncExtendedDuration, userOverheadPercent, amcosVersionId);
            }
        }
        public void AddRequirements(int categoryId, List<ProjectRequirement> projectRequirements)
        {
            for (int index = 0; index < projectRequirements.Count; index++){
                ProjectRequirement projectRequirement = new ProjectRequirement {
                    CategoryId = categoryId,
                    PayPlan = projectRequirements[index].PayPlan,
                    CategoryGroupCode = projectRequirements[index].CategoryGroupCode,
                    CategorySubgroupCode = projectRequirements[index].CategorySubgroupCode,
                    CareerProgramNumber = projectRequirements[index].CareerProgramNumber,
                    LocationId = projectRequirements[index].LocationId,
                    LocationText = projectRequirements[index].LocationText,
                    STRL = projectRequirements[index].STRL,
                    GradeLevel = projectRequirements[index].GradeLevel,
                    DependentStatus = projectRequirements[index].DependentStatus,
                    NumberOfDependents = projectRequirements[index].NumberOfDependents,
                    ActiveDutyDays = projectRequirements[index].ActiveDutyDays,
                    OverheadPercent = projectRequirements[index].OverheadPercent,
                    Inventory = projectRequirements[index].Inventory
                };
                projectRequirement.CreatePMCategorySkill();
            };
        }
        public void AddUnitEF(int categoryId)
        {
            List<ProjectRequirement> projectRequirements = new List<ProjectRequirement>
            {
                new ProjectRequirement{
                    CategoryId = categoryId,
                    PayPlan = "AE",
                    CategoryGroupCode = "11",
                    CategorySubgroupCode = "-1",
                    CareerProgramNumber = "-1",
                    LocationId = -1,
                    LocationText = "-1",
                    STRL = "-1",
                    GradeLevel = 3,
                    DependentStatus = "-1",
                    NumberOfDependents = -1,
                    ActiveDutyDays = 15,
                    OverheadPercent = 0,
                    Inventory = new int[] { 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31 }
                },
                new ProjectRequirement{
                    CategoryId = categoryId,
                    PayPlan = "AE",
                    CategoryGroupCode = "11",
                    CategorySubgroupCode = "-1",
                    CareerProgramNumber = "-1",
                    LocationId = -1,
                    LocationText = "-1",
                    STRL = "-1",
                    GradeLevel = 5,
                    DependentStatus = "-1",
                    NumberOfDependents = -1,
                    ActiveDutyDays = 15,
                    OverheadPercent = 0,
                    Inventory = new int[] {1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1 }
                },
                new ProjectRequirement{
                    CategoryId = categoryId,
                    PayPlan = "AE",
                    CategoryGroupCode = "11",
                    CategorySubgroupCode = "-1",
                    CareerProgramNumber = "-1",
                    LocationId = -1,
                    LocationText = "-1",
                    STRL = "-1",
                    GradeLevel = 7,
                    DependentStatus = "-1",
                    NumberOfDependents = -1,
                    ActiveDutyDays = 15,
                    OverheadPercent = 0,
                    Inventory = new int[] { 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31 }
                },
                new ProjectRequirement{
                    CategoryId = categoryId,
                    PayPlan = "AE",
                    CategoryGroupCode = "11",
                    CategorySubgroupCode = "-1",
                    CareerProgramNumber = "-1",
                    LocationId = -1,
                    LocationText = "-1",
                    STRL = "-1",
                    GradeLevel = 9,
                    DependentStatus = "-1",
                    NumberOfDependents = -1,
                    ActiveDutyDays = 15,
                    OverheadPercent = 0,
                    Inventory = new int[] {1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1 }
                },
                new ProjectRequirement{
                    CategoryId = categoryId,
                    PayPlan = "AO",
                    CategoryGroupCode = "12",
                    CategorySubgroupCode = "-1",
                    CareerProgramNumber = "-1",
                    LocationId = -1,
                    LocationText = "-1",
                    STRL = "-1",
                    GradeLevel = 5,
                    DependentStatus = "-1",
                    NumberOfDependents = -1,
                    ActiveDutyDays = 15,
                    OverheadPercent = 0,
                    Inventory = new int[] { 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31 }
                },
                new ProjectRequirement{
                    CategoryId = categoryId,
                    PayPlan = "A0",
                    CategoryGroupCode = "12",
                    CategorySubgroupCode = "-1",
                    CareerProgramNumber = "-1",
                    LocationId = -1,
                    LocationText = "-1",
                    STRL = "-1",
                    GradeLevel = 7,
                    DependentStatus = "-1",
                    NumberOfDependents = -1,
                    ActiveDutyDays = 15,
                    OverheadPercent = 0,
                    Inventory = new int[] {1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1 }
                },
                new ProjectRequirement{
                    CategoryId = categoryId,
                    PayPlan = "AO",
                    CategoryGroupCode = "11",
                    CategorySubgroupCode = "-1",
                    CareerProgramNumber = "-1",
                    LocationId = -1,
                    LocationText = "-1",
                    STRL = "-1",
                    GradeLevel = 9,
                    DependentStatus = "-1",
                    NumberOfDependents = -1,
                    ActiveDutyDays = 15,
                    OverheadPercent = 0,
                    Inventory = new int[] { 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31 }
                },
                new ProjectRequirement{
                    CategoryId = categoryId,
                    PayPlan = "AWO",
                    CategoryGroupCode = "12",
                    CategorySubgroupCode = "-1",
                    CareerProgramNumber = "-1",
                    LocationId = -1,
                    LocationText = "-1",
                    STRL = "-1",
                    GradeLevel = 5,
                    DependentStatus = "-1",
                    NumberOfDependents = -1,
                    ActiveDutyDays = 15,
                    OverheadPercent = 0,
                    Inventory = new int[] {1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1 }
                }

            };

            AddRequirements(categoryId, projectRequirements);
        }
        public int AddUnit(int categoryId, string uic, string notSelectedPayPlans, string unitLocation, string mtoeProjectInventoryYear, string mtoeSyncExtendedDuration, decimal userOverheadPercent, int amcosVersionId)
        {
            int rowsAffected = 0;
            using (var context = new ApplicationDbContext())
            {
                // web.projectaddunit is a FUNCTION (RETURNS void) — invoke with SELECT, not CALL.
                var sql = "SELECT web.projectaddunit(@CategoryId, @UIC, @NotSelectedPayPlans, @UnitLocation, @MtoeProjectInventoryYear, @MtoeSyncExtendedDurationFillValue, @UserOverheadPercent, @AmcosVersionId, @Debug)";
                context.Database.SetCommandTimeout(120);
                rowsAffected = context.Database.ExecuteSqlRaw(
                    sql,
                    new NpgsqlParameter("@CategoryId", categoryId),
                    new NpgsqlParameter("@UIC", uic),
                    new NpgsqlParameter("@NotSelectedPayPlans", string.IsNullOrEmpty(notSelectedPayPlans) ? (object)DBNull.Value : (object)notSelectedPayPlans),
                    new NpgsqlParameter("@UnitLocation", unitLocation),
                    new NpgsqlParameter("@MtoeProjectInventoryYear", string.IsNullOrEmpty(mtoeProjectInventoryYear) ? (object)DBNull.Value : (object)mtoeProjectInventoryYear),
                    new NpgsqlParameter("@MtoeSyncExtendedDurationFillValue", mtoeSyncExtendedDuration),
                    new NpgsqlParameter("@UserOverheadPercent", userOverheadPercent),
                    new NpgsqlParameter("@AmcosVersionId", amcosVersionId),
                    new NpgsqlParameter("@Debug", (object)0));
            }
            return rowsAffected;
        }
        public string GetProjectName(int projectId)
        {
            using (var context = new ApplicationDbContext())
            {
                return context.PMProject
                    .Where(p => p.ProjectId == projectId)
                    .Select(p => p.ProjectName)
                    .First();
            }
        }
        public List<ListItemDto> GetCategoryList(int projectId, int categoryId)
        {
            IEnumerable<ListItemDto> listItems = null;

            using (var context = new ApplicationDbContext())
            {
                listItems = context.PMCategory.AsNoTracking()
                    .Where(c => c.ProjectId == projectId)
                    .Where(c => c.CategoryId != categoryId)
                    .OrderBy(c => c.CategoryName)
                    .Select(c => new ListItemDto()
                    {
                        Value = c.CategoryId.ToString(),
                        Text = c.CategoryName
                    })
                    .Distinct();
                return listItems?.ToList();
            }
        }
        public int CreateProjectCategory(int projectId, string categoryName)
        {
            if (SubprojectNameExists(projectId, categoryName)) {
                return 0;
            }

            using (var context = new ApplicationDbContext())
            {
                var pmCategory = new PMCategory
                {
                    ProjectId = projectId,
                    CategoryName = categoryName
                };
                context.PMCategory.Add(pmCategory);
                context.SaveChanges();
                return pmCategory.CategoryId;
            }
        }
        public void DeleteSubProject(int categoryId)
        {
            using (var context = new ApplicationDbContext())
            {
                var pmCategoryRowToRemove = context.PMCategory
                    .Where(c => c.CategoryId == categoryId)
                    .Single();

                if (pmCategoryRowToRemove != null)
                {
                    DeleteReportByCategory(categoryId);
                    context.PMCategory.Remove(pmCategoryRowToRemove);
                    context.SaveChanges();
                }
            }
        }
        private string LocationDisplay(string payPlan, string locationName)
        {
            _ = payPlan ?? throw new ArgumentNullException(nameof(payPlan));
            _ = locationName ?? throw new ArgumentNullException(nameof(locationName));

            string[] payPlansThatDoNotRequireLocation = { "NE", "NO", "NWO", "RE", "RO", "RWO" };
            if (Array.Exists(payPlansThatDoNotRequireLocation, element => element == payPlan))
            {
                return "N/A";
            }
            else
            {
                if (locationName == "" || locationName == "-1")
                {
                    return "All";
                }
                else
                {
                    return locationName;
                }
            }
        }
        public bool SubprojectNameExists(int projectId, string categoryName)
        {
            bool recordExists = false;
            using (var context = new ApplicationDbContext())
            {
                recordExists = context.PMCategory.Any(c => c.ProjectId == projectId
                && c.CategoryName == categoryName
                );
            }
            return recordExists;
        }
        public DataTable UpdateActiveDutyDaysDisplay(DataTable dataTable)
        {
            _ = dataTable ?? throw new ArgumentNullException(nameof(dataTable));

            foreach (DataRow dr in dataTable.Rows)
            {
                dr["Active Duty Days"] = ActiveDutyDaysDisplay(dr["PayPlan"].ToString(), short.Parse(dr["Active Duty Days"].ToString()));
            }
            return dataTable;
        }
        public void UpdateCategoryName(int projectId, string categoryNameNew, string categoryNameOld)
        {
            using (var context = new ApplicationDbContext())
            {
                var pmCategory = context.PMCategory
                    .Where(c => c.ProjectId == projectId)
                    .Where(c => c.CategoryName == categoryNameOld)
                    .First();
                pmCategory.CategoryName = categoryNameNew;
                context.SaveChanges();
            }
        }
        public void UpdateProjectProperties(string ProjectName, string Description, int YearStart, int YearDuration, int originalProjectId)
        {
            using (var context = new ApplicationDbContext())
            {
                var recordToUpdate = context.PMProject
                    .Where(c => c.ProjectId == originalProjectId)
                    .Single();

                if (recordToUpdate != null)
                {
                    recordToUpdate.ProjectName = ProjectName;
                    recordToUpdate.Description = Description;
                    recordToUpdate.YearStart = YearStart;
                    recordToUpdate.YearDuration = YearDuration;
                    recordToUpdate.LastUpdate = DateTime.Now;
                    context.SaveChanges();
                }
            }
        }
        public DataTable UpdateLocationDisplay(DataTable dataTable)
        {
            _ = dataTable ?? throw new ArgumentNullException(nameof(dataTable));

            foreach (DataRow dr in dataTable.Rows)
            {
                dr["Location"] = LocationDisplay(dr["PayPlan"].ToString(), dr["Location"].ToString());
            }
            return dataTable;
        }
        public List<PMProject> GetAllProjectsForUserId(string userId)
        {
            using (var context = new ApplicationDbContext())
            {
                return context.PMProject.AsNoTracking()
                    .Where(c => c.UserId == userId)
                    .OrderByDescending(c => c.LastUpdate)
                    .ToList();
            }
        }
        public void DeleteProject(int projectId)
        {
            using (var context = new ApplicationDbContext())
            {
                // web.deleteproject is a FUNCTION (RETURNS void) — invoke with SELECT, not CALL.
                context.Database.ExecuteSqlRaw("SELECT web.deleteproject(@ProjectId)",
                    new NpgsqlParameter("@ProjectId", projectId));
            }
        }
        public void LogAddUnit(ProjectAddUnitViewModel projectAddUnitViewModelObject)
        {
            if (projectAddUnitViewModelObject == null)
            {
                throw new ArgumentNullException("projectAddUnitViewModelObject");
            }

            ApplicationDbContext context = new ApplicationDbContext();
            var auditRecord = new ProjectAddUnitAudit
            {
                UserId = projectAddUnitViewModelObject.UserId,
                CreateDate = DateTime.Now,
                CategoryId = projectAddUnitViewModelObject.CategoryId,
                UIC = projectAddUnitViewModelObject.UIC,
                ExcludedPayPlans = projectAddUnitViewModelObject.ExcludedPayPlans,
                DataAction = projectAddUnitViewModelObject.DataAction,
                NewSubprojectName = projectAddUnitViewModelObject.NewSubprojectName,
                UnitLocation = projectAddUnitViewModelObject.UnitLocation,
                MtoeProjectInventoryYear = projectAddUnitViewModelObject.MtoeProjectInventoryYear,
                ProjectExtendsSacsYears = projectAddUnitViewModelObject.ProjectExtendsSacsYears,
                ContractorOverheadPercent = projectAddUnitViewModelObject.ContractorOverheadPercent
            };

            context.ProjectAddUnitAudit.Add(auditRecord);
            context.SaveChanges();
            context.Dispose();
        }
    }
}
