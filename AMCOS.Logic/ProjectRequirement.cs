using AMCOS.Data;
using AMCOS.Data.DataTransferObjects;
using AMCOS.Data.Entities;
using System;
using System.Collections.Generic;
using System.Collections.ObjectModel;
using System.Data;
using Npgsql;
using NpgsqlTypes;
using System.Linq;

namespace AMCOS.Logic
{
    public class ProjectRequirement
    {
        public string UserId { get; set; }
        public int ProjectId { get; set; }
        public int CategoryId { get; set; }
        public string PayPlan { get; set; }
        public string CategoryGroupCode { get; set; }
        public string CategorySubgroupCode { get; set; }
        public string CareerProgramNumber { get; set; }
        public int LocationId { get; set; }
        public string LocationText { get; set; }
        public string STRL { get; set; }
        public byte GradeLevel { get; set; }
        public string DependentStatus { get; set; }
        public int NumberOfDependents { get; set; }
        public short ActiveDutyDays { get; set; }
        public double OverheadPercent { get; set; }
        public int[] Inventory { get; set; }

        public int CreatePMCategorySkill()
        {
            int skillId = 0;
            int projectDuration = GetProjectDuration(CategoryId);

            if (RequirementExists())
            {
                return 0;
            }

            using (var context = new ApplicationDbContext())
            {
                var pmCategorySkill = new PMCategorySkill
                {
                    CategoryId = CategoryId,
                    PayPlan = PayPlan,
                    CategoryGroupCode = CategoryGroupCode,
                    CategorySubgroupCode = CategorySubgroupCode,
                    CareerProgramNumber = CareerProgramNumber,
                    LocationId = LocationId,
                    LocationText = LocationText,
                    STRL = STRL,
                    GradeLevel = GradeLevel,
                    DependentStatus = DependentStatus,
                    NumberOfDependents = NumberOfDependents,
                    ActiveDutyDays = ActiveDutyDays,
                    OverheadPercent = OverheadPercent
                };
                context.PMCategorySkill.Add(pmCategorySkill);
                context.SaveChanges();
                skillId = pmCategorySkill.SkillId;

                for (int projectYearIndex = 0; projectYearIndex <= projectDuration - 1; projectYearIndex++)
                {
                    CreatePMCategorySkillInventory(skillId, projectYearIndex, Inventory[projectYearIndex]);
                }

                return skillId;
            }
        }
        public void CreatePMCategorySkillInventory(int skillId, int year, int amount)
        {
            using (var context = new ApplicationDbContext())
            {
                var pmCategorySkillInventory = new PMCategorySkillInventory
                {
                    SkillId = skillId,
                    Year = year,
                    Amount = amount
                };
                context.PMCategorySkillInventory.Add(pmCategorySkillInventory);
                context.SaveChanges();
            }
        }
        public void DeletePMCategorySkill(int skillId)
        {
            DeletePMCategorySkillInventoryAll(skillId);
            using (var context = new ApplicationDbContext())
            {
                var recordToRemove = context.PMCategorySkill
                    .Where(c => c.SkillId == skillId)
                    .First();

                if (recordToRemove != null)
                {
                    context.PMCategorySkill.Remove(recordToRemove);
                    context.SaveChanges();
                }
            }
        }
        public void DeletePMCategorySkillAll(int categoryId)
        {
            using (var context = new ApplicationDbContext())
            {
                var skillsToRemove = context.PMCategorySkill
                    .Where(c => c.CategoryId == categoryId)
                    .Select(c => c.SkillId);
                foreach (var skill in skillsToRemove)
                {
                    DeletePMCategorySkillInventoryAll(skill);
                }               

                context.PMCategorySkill.RemoveRange(context.PMCategorySkill.Where(c => c.CategoryId == categoryId));
                context.SaveChanges();
            }
        }
        public void DeletePMCategorySkillInventoryAll(int skillId)
        {
            using (var context = new ApplicationDbContext())
            {
                context.PMCategorySkillInventory.RemoveRange(context.PMCategorySkillInventory.Where(c => c.SkillId == skillId));
                context.SaveChanges();
            }
        }
        public Collection<PMCategory> GetCategories(int projectId)
        {
            Collection<PMCategory> categories = new Collection<PMCategory>();
            string sqlStatement = "SELECT * FROM web.PMGetCategories(@ProjectId)";

            using (NpgsqlConnection connection = new NpgsqlConnection(AppConfiguration.GetConnectionString()))
            {
                connection.Open();
                using (NpgsqlCommand command = new NpgsqlCommand(sqlStatement, connection))
                {
                    command.Parameters.AddWithValue("@ProjectId", projectId);
                    command.CommandType = CommandType.Text;
                    using (NpgsqlDataReader reader = command.ExecuteReader())
                    {
                        while (reader.Read())
                        {
                            categories.Add(MapCategory(reader));
                        }
                    }
                }
            }

            return categories;
        }
        public Collection<PMCategory> GetCategoriesAll(int projectId)
        {
            Collection<PMCategory> categories = new Collection<PMCategory>();
            string sqlStatement = "SELECT * FROM web.PMGetCategoriesAll(@ProjectId);";

            using (NpgsqlConnection connection = new NpgsqlConnection(AppConfiguration.GetConnectionString()))
            {
                connection.Open();
                using (NpgsqlCommand command = new NpgsqlCommand(sqlStatement, connection))
                {
                    command.Parameters.AddWithValue("@ProjectId", projectId);
                    command.CommandType = CommandType.Text;
                    using (NpgsqlDataReader reader = command.ExecuteReader())
                    {
                        while (reader.Read())
                        {
                            categories.Add(MapCategory(reader));
                        }
                    }
                }
            }

            return categories;
        }
        public PMCategory GetCategory(int projectId, int categoryId)
        {
            PMCategory category;
            string sqlStatement = "SELECT * FROM webuser.PMCategory WHERE ProjectID = @ProjectId AND CategoryID = @CategoryID;";

            using (NpgsqlConnection connection = new NpgsqlConnection(AppConfiguration.GetConnectionString()))
            {
                connection.Open();
                using (NpgsqlCommand command = new NpgsqlCommand(sqlStatement, connection))
                {
                    command.Parameters.AddWithValue("@ProjectId", projectId);
                    command.Parameters.AddWithValue("@CategoryID", categoryId);
                    command.CommandType = CommandType.Text;
                    using (NpgsqlDataReader reader = command.ExecuteReader())
                    {
                        reader.Read();
                        category = MapCategory(reader);
                    }
                }
            }

            return category;
        }
        public List<PMCategorySkillInventory> GetCategorySkillInventory(int skillId)
        {
            using (var context = new ApplicationDbContext())
            {
                return context.PMCategorySkillInventory.AsNoTracking()
                    .Where(c => c.SkillId == skillId)
                    .OrderBy(c => c.Year)
                    .ToList();
            }
        }
        private int GetProjectDuration(int categoryId)
        {
            using (var context = new ApplicationDbContext())
            {
                var query = (from category in context.PMCategory
                            join project in context.PMProject on category.ProjectId equals project.ProjectId
                            where category.CategoryId == categoryId
                            select project.YearDuration).Single();
                return query;
            }
        }
        public bool RequirementExists()
        {
            bool recordExists = false;
            using (var context = new ApplicationDbContext())
            {
                recordExists = context.PMCategorySkill.Any(c => c.CategoryId == CategoryId
                && c.PayPlan == PayPlan
                && c.CategoryGroupCode == CategoryGroupCode
                && c.CategorySubgroupCode == CategorySubgroupCode
                && c.CareerProgramNumber == CareerProgramNumber
                && c.LocationId == LocationId
                && c.STRL == STRL
                && c.GradeLevel == GradeLevel
                && c.DependentStatus == DependentStatus
                && c.ActiveDutyDays == ActiveDutyDays
                && c.OverheadPercent == OverheadPercent
                );
            }
            return recordExists;
        }
        public Collection<PMCategory> GetRequirements(int projectId)
        {
            Collection<PMCategory> categories = new Collection<PMCategory>();
            string sqlStatement = "SELECT * FROM web.PMGetCategoriesAll(@ProjectId);";

            using (NpgsqlConnection connection = new NpgsqlConnection(AppConfiguration.GetConnectionString()))
            {
                connection.Open();
                using (NpgsqlCommand command = new NpgsqlCommand(sqlStatement, connection))
                {
                    command.Parameters.AddWithValue("@ProjectId", projectId);
                    command.CommandType = CommandType.Text;
                    using (NpgsqlDataReader reader = command.ExecuteReader())
                    {
                        while (reader.Read())
                        {
                            categories.Add(MapCategory(reader));
                        }
                    }
                }
            }

            return categories;
        }
        public List<ProjectRequirementListDto> GetRequirementsAndInventory(int categoryId)
        {
            using (var context = new ApplicationDbContext())
            {
                return context.PMCategorySkill.AsNoTracking()
                    .Where(c => c.CategoryId == categoryId)
                    .AsEnumerable()
                    .Select(c => new ProjectRequirementListDto()
                    {
                        CategoryId = c.CategoryId,
                        SkillId = c.SkillId,
                        Uic = c.Uic,
                        PayPlan = c.PayPlan,
                        CategoryGroupCode = CategoryGroupCodeDisplay(c.PayPlan, c.CategoryGroupCode),
                        CategorySubgroupCode = CategorySubgroupCodeDisplay(c.PayPlan, c.CategorySubgroupCode),
                        CareerProgramNumber = CareerProgramNumberDisplay(c.PayPlan, c.CareerProgramNumber),
                        Location = LocationDisplay(c.PayPlan, c.LocationId, c.LocationText),
                        STRL = ScienceTechnologyReinventionLaboratoryDisplay(c.PayPlan, c.STRL),
                        Grade = GradeLevelDisplay(c.PayPlan, c.GradeLevel.ToString()),
                        DependentStatus = DependentStatusDisplay(c.PayPlan, c.DependentStatus),
                        NumberOfDependents = NumberOfDependentsDisplay(c.PayPlan, c.NumberOfDependents),
                        ActiveDutyDays = ActiveDutyDaysDisplay(c.PayPlan, c.ActiveDutyDays),
                        OverheadPercent = OverheadPercentDisplay(c.PayPlan, c.OverheadPercent)
                    }
                    )
                    .OrderBy(c => c.PayPlan)
                    .ToList();
            }
        }
        private string CategoryGroupCodeDisplay(string payPlan, string categoryGroupCode)
        {
            if (payPlan == null)
            {
                throw new System.ArgumentNullException(nameof(payPlan));
            }

            if (categoryGroupCode == null)
            {
                throw new System.ArgumentNullException(nameof(categoryGroupCode));
            }

            if (categoryGroupCode == "-1")
            {
                return "All";
            }
            else
            {
                return categoryGroupCode;
            }

        }
        private string CategorySubgroupCodeDisplay(string payPlan, string categorySubgroupCode)
        {
            if (payPlan == null)
            {
                throw new System.ArgumentNullException(nameof(payPlan));
            }

            if (categorySubgroupCode == null)
            {
                throw new System.ArgumentNullException(nameof(categorySubgroupCode));
            }

            if (categorySubgroupCode == "-1")
            {
                return "All";
            }
            else
            {
                return categorySubgroupCode;
            }
        }
        private string GradeLevelDisplay(string payPlan, string gradeLevel)
        {
            if (string.IsNullOrEmpty(payPlan))
            {
                throw new ArgumentException("message", nameof(payPlan));
            }

            switch (payPlan)
            {
                case "CCE":
                    string[] cceGrades = { "A_PCT10", "A_PCT25", "A_MEDIAN", "A_PCT75", "A_PCT90" };
                    return cceGrades[Int32.Parse(gradeLevel) - 1];
                case "SES":
                    string[] sesGrades = { "Min", "Avg", "Max" };
                    return sesGrades[Int32.Parse(gradeLevel) - 1];
                default:
                    return gradeLevel;
            }
        }
        private string OverheadPercentDisplay(string payPlan, double overheadPercent)
        {
            if (payPlan == null)
            {
                throw new System.ArgumentNullException(nameof(payPlan));
            }

            if (payPlan == "CCE")
            {
                return overheadPercent.ToString();
            } else
            {
                return "N/A";
            }
        }
        private string ActiveDutyDaysDisplay(string payPlan, short activeDutyDays)
        {
            if (payPlan == null)
            {
                throw new System.ArgumentNullException(nameof(payPlan));
            }

            string[] payPlansThatRequireActiveDutyDays = { "NE", "NO", "NWO", "RE", "RO", "RWO" };
            if (Array.Exists(payPlansThatRequireActiveDutyDays, element => element == payPlan))
            {
                return activeDutyDays.ToString();
            } else
            {
                return "N/A";
            }
        }
        private string NumberOfDependentsDisplay(string payPlan, int numberOfDependents)
        {
            if (payPlan == null)
            {
                throw new System.ArgumentNullException(nameof(payPlan));
            }

            if (numberOfDependents == -1)
            {
                return "N/A";
            } else
            {
                return numberOfDependents.ToString();
            }
        }
        private string CareerProgramNumberDisplay(string payPlan, string careerProgramNumber)
        {
            if (payPlan == null)
            {
                throw new System.ArgumentNullException(nameof(payPlan));
            }

            if (careerProgramNumber == null)
            {
                throw new System.ArgumentNullException(nameof(careerProgramNumber));
            }

            if (careerProgramNumber == "-1")
            {
                return "All";
            }
            else
            {
                return careerProgramNumber;
            }
        }
        private string ScienceTechnologyReinventionLaboratoryDisplay(string payPlan, string scienceTechnologyReinventionLaboratory)
        {
            if (payPlan == null)
            {
                throw new System.ArgumentNullException(nameof(payPlan));
            }

            if (scienceTechnologyReinventionLaboratory == null)
            {
                throw new System.ArgumentNullException(nameof(scienceTechnologyReinventionLaboratory));
            }

            if (payPlan.Substring(0,1) == "D")
            {
                return scienceTechnologyReinventionLaboratory;
            } else
            {
                return "N/A";
            }
        }
        private string LocationDisplay(string payPlan, int locationId, string locationName)
        {
            if (payPlan == null)
            {
                throw new System.ArgumentNullException(nameof(payPlan));
            }

            if (locationName == null)
            {
                throw new System.ArgumentNullException(nameof(locationName));
            }

            string[] payPlansThatDoNotRequireLocation = { "NE", "NO", "NWO", "RE", "RO", "RWO" };
            if (Array.Exists(payPlansThatDoNotRequireLocation, element => element == payPlan))
            {
                return "N/A";
            } else
            {
                if (locationId == -1)
                {
                    return "All";
                }
                else
                {
                    return locationName;
                }
            }            
        }
        private string DependentStatusDisplay(string payPlan, string dependentStatus)
        {
            if (payPlan == null)
            {
                throw new System.ArgumentNullException(nameof(payPlan));
            }

            if (dependentStatus == null)
            {
                throw new System.ArgumentNullException(nameof(dependentStatus));
            }

            if (dependentStatus == "-1")
            {
                return "N/A";
            }
            else
            {
                return dependentStatus;
            }
        }
        private PMCategory MapCategory(NpgsqlDataReader reader)
        {

            PMCategory category = new PMCategory();

            if (!reader.IsDBNull(reader.GetOrdinal("ProjectId")))
            {
                category.ProjectId = reader.GetInt32(reader.GetOrdinal("ProjectId"));
            }

            if (!reader.IsDBNull(reader.GetOrdinal("CategoryId")))
            {
                category.CategoryId = reader.GetInt32(reader.GetOrdinal("CategoryId"));
            }

            if (!reader.IsDBNull(reader.GetOrdinal("CategoryName")))
            {
                category.CategoryName = reader.GetString(reader.GetOrdinal("CategoryName"));
            }

            return category;
        }
    }
}
