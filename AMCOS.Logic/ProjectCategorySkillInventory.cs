using AMCOS.Data;
using AMCOS.Data.Entities;
using System.Collections.Generic;
using System.Collections.ObjectModel;
using System.Configuration;
using System.Data;
using System.Data.SqlClient;
using System.Linq;

namespace AMCOS.Logic
{
    public class ProjectCategorySkillInventory
    {
        public int InventoryId { get; set; }
        public int SkillId { get; set; }
        public int Year { get; set; }
        public int Amount { get; set; }

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
        public static Collection<PMCategorySkillInventory> GetSkillInventories(int SkillID)
        {
            Collection<PMCategorySkillInventory> skillInventories = new Collection<PMCategorySkillInventory>();
            string sqlStatement = "SELECT * FROM webuser.PMCategorySkillInventory WHERE SkillID = @SkillID;";

            using (SqlConnection connection = new SqlConnection(ConfigurationManager.ConnectionStrings["AmcosAdo"].ConnectionString))
            {
                connection.Open();
                using (SqlCommand command = new SqlCommand(sqlStatement, connection))
                {
                    command.Parameters.AddWithValue("@SkillID", SkillID);
                    command.CommandType = CommandType.Text;
                    using (SqlDataReader reader = command.ExecuteReader())
                    {
                        while (reader.Read())
                        {
                            skillInventories.Add(MapSkillInventory(reader));
                        }
                    }
                }
            }

            return skillInventories;
        }
        private static PMCategorySkillInventory MapSkillInventory(SqlDataReader reader)
        {
            PMCategorySkillInventory pmCategorySkillInventory = new PMCategorySkillInventory();

            if (!reader.IsDBNull(reader.GetOrdinal("InventoryId")))
            {
                pmCategorySkillInventory.InventoryId = reader.GetInt32(reader.GetOrdinal("InventoryId"));
            }

            if (!reader.IsDBNull(reader.GetOrdinal("SkillId")))
            {
                pmCategorySkillInventory.SkillId = reader.GetInt32(reader.GetOrdinal("SkillId"));
            }

            if (!reader.IsDBNull(reader.GetOrdinal("Year")))
            {
                pmCategorySkillInventory.Year = reader.GetInt32(reader.GetOrdinal("Year"));
            }

            if (!reader.IsDBNull(reader.GetOrdinal("Amount")))
            {
                pmCategorySkillInventory.Amount = reader.GetInt32(reader.GetOrdinal("Amount"));
            }

            return pmCategorySkillInventory;
        }
        public void DeleteAll(int skillId)
        {
            using (var context = new ApplicationDbContext())
            {
                context.PMCategorySkillInventory.RemoveRange(context.PMCategorySkillInventory.Where(c => c.SkillId == skillId));
                context.SaveChanges();
            }
        }
        public void Create(int skillId, int year, int amount)
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
        public static bool Update(int inventoryId, int skillId, int year, int amount)
        {
            int rowsAffected;
            string sqlStatement = "UPDATE webuser.PMCategorySkillInventory SET Amount = @Amount WHERE InventoryId = @InventoryId AND SkillID = @SkillID AND Year = @Year;";

            using (SqlConnection connection = new SqlConnection(ConfigurationManager.ConnectionStrings["AmcosAdo"].ConnectionString))
            {
                connection.Open();
                using (SqlCommand command = new SqlCommand(sqlStatement, connection))
                {
                    command.Parameters.AddWithValue("@InventoryId", inventoryId);
                    command.Parameters.AddWithValue("@SkillID", skillId);
                    command.Parameters.AddWithValue("@Year", year);
                    command.Parameters.AddWithValue("@Amount", amount);
                    command.CommandType = CommandType.Text;
                    rowsAffected = command.ExecuteNonQuery();
                }
            }

            return (rowsAffected > 0);
        }
        public static bool Delete(int skillId, int year)
        {
            int rowsAffected = 0;
            string sqlStatement = "DELETE webuser.PMCategorySkillInventory WHERE SkillId = @SkillId AND Year = @Year;";

            using (SqlConnection connection = new SqlConnection(ConfigurationManager.ConnectionStrings["AmcosAdo"].ConnectionString))
            {
                connection.Open();
                using (SqlCommand command = new SqlCommand(sqlStatement, connection))
                {
                    command.Parameters.AddWithValue("@SkillId", skillId);
                    command.Parameters.AddWithValue("@Year", year);
                    command.CommandType = CommandType.Text;
                    rowsAffected = command.ExecuteNonQuery();
                }
            }

            return (rowsAffected > 0);
        }
    }
}
