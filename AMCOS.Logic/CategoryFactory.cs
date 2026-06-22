using AMCOS.Data.Entities;
using System;
using System.Collections.ObjectModel;
using System.Configuration;
using System.Data;
using System.Data.SqlClient;

namespace AMCOS.Logic
{
    public static class CategoryFactory
    {
        
        public static int Delete(int categoryId) {
            int recordsAffected = 0;
            string sqlStatement = "DELETE webuser.PMCategory WHERE CategoryId = @CategoryId;";
    
            using (SqlConnection connection = new SqlConnection(ConfigurationManager.ConnectionStrings["AmcosAdo"].ConnectionString)) {
                connection.Open();
                using (SqlCommand command = new SqlCommand(sqlStatement, connection)) {
                    command.Parameters.AddWithValue("@CategoryId", categoryId);
                    command.CommandType = CommandType.Text;
                    recordsAffected = command.ExecuteNonQuery();
                }
            }

            return recordsAffected;
        }
        public static int Insert(int projectId, string categoryName) {
            int categoryId = 0;
            string sqlStatement = "INSERT INTO webuser.PMCategory (ProjectID, CategoryName) VALUES (@ProjectId, @CategoryName); SELECT @@IDENTITY;";

            using (SqlConnection connection = new SqlConnection(ConfigurationManager.ConnectionStrings["AmcosAdo"].ConnectionString)) {
                connection.Open();
                using (SqlCommand command = new SqlCommand(sqlStatement, connection)) {
                    command.Parameters.AddWithValue("@ProjectId", projectId);
                    command.Parameters.AddWithValue("@CategoryName", categoryName);
                    command.CommandType = CommandType.Text;
                    categoryId = Convert.ToInt32(command.ExecuteScalar());
                }
            }

            return categoryId;
        }
        
    }
}