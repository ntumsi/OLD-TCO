using System;
using System.Collections.Generic;
using System.Data;
using Npgsql;
using NpgsqlTypes;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace AMCOS.Logic
{
    public static class ProjectFactory
    {
        public static Project GetProject(int ProjectID) {
            Project project = null;
            string sqlStatement = "SELECT * FROM webuser.PMProject WHERE ProjectID = @ProjectID;";

            using (NpgsqlConnection connection = new NpgsqlConnection(AppConfiguration.GetConnectionString()))
            {
                connection.Open();
                using (NpgsqlCommand command = new NpgsqlCommand(sqlStatement, connection))
                {
                    command.Parameters.AddWithValue("@ProjectID", ProjectID);
                    command.CommandType = CommandType.Text;
                    using (NpgsqlDataReader reader = command.ExecuteReader())
                    {
                        while (reader.Read())
                        {
                            project = MapProject(reader);
                        }
                    }
                }
            }

            return project;
        }
        public static int Copy(int ProjectId, string Name, string Description) {
            int rowsAffected = 0;
            string sqlStatement = "web.PMCopyProject";

            using (NpgsqlConnection connection = new NpgsqlConnection(AppConfiguration.GetConnectionString()))
            {
                connection.Open();
                using (NpgsqlCommand command = new NpgsqlCommand(sqlStatement, connection))
                {
                    command.Parameters.AddWithValue("@ProjectId", ProjectId);
                    command.Parameters.AddWithValue("@ProjectName", Name);
                    command.Parameters.AddWithValue("@Description", Description);
                    command.CommandType = CommandType.StoredProcedure;
                    rowsAffected = command.ExecuteNonQuery();
                }
            }

            return rowsAffected;
        }
        public static void Delete(Project oProject) {
            if (Delete(oProject.ProjectId, oProject.UserId) >= 1)
            {
                oProject = null;
            }
        }
        public static int Delete(int ProjectID, string UserId) {
            int rowsAffected;
            string sqlStatement = "DELETE webuser.PMProject WHERE (ProjectID = @ProjectID AND UserId = @UserId);";

            using (NpgsqlConnection connection = new NpgsqlConnection(AppConfiguration.GetConnectionString()))
            {
                connection.Open();
                using (NpgsqlCommand command = new NpgsqlCommand(sqlStatement, connection))
                {
                    command.Parameters.AddWithValue("@ProjectID", ProjectID);
                    command.Parameters.AddWithValue("@UserId", UserId);
                    command.CommandType = CommandType.Text;
                    rowsAffected = command.ExecuteNonQuery();
                }
            }

            return rowsAffected;
        }
        public static bool Update(Project oProject) {
            int rowsAffected;
            rowsAffected = Update(oProject.UserId, oProject.ProjectId, oProject.ProjectName, oProject.YearStart, oProject.YearDuration, oProject.ProjectCreator, oProject.ReserveDaysInActive, oProject.ReserveDaysActive, oProject.LastUpdate, oProject.CreateDate, oProject.Description, oProject.DiscountRate);
            return (rowsAffected >= 1);
        }
        public static int Update(string UserId, int ProjectID, string Name, int YearStart, int YearDuration, string ProjectCreator, int ReserveDaysInActive, int ReserveDaysActive, DateTime UpdateDate, DateTime CreateDate, string Description, double[] DiscountRate) {
            int rowsAffected;
            string sqlStatement = "UPDATE webuser.PMProject " +
            "SET [ProjectName] = @ProjectName, YearStart = @YearStart, YearDuration = @YearDuration, ProjectCreator = @ProjectCreator, ProjectType = @ProjectType, ReserveDaysInActive = @ReserveDaysInActive, ReserveDaysActive = @ReserveDaysActive, DiscountRate = @DiscountRate, CreateDate = @CreateDate, LastUpdate = @LastUpdate, Description = @Description " +
            "WHERE (UserId = @UserId AND ProjectID = @ProjectID);";

            using (NpgsqlConnection connection = new NpgsqlConnection(AppConfiguration.GetConnectionString()))
            {
                connection.Open();
                using (NpgsqlCommand command = new NpgsqlCommand(sqlStatement, connection))
                {
                    command.Parameters.AddWithValue("@UserId", UserId);
                    command.Parameters.AddWithValue("@ProjectID", ProjectID);
                    command.Parameters.AddWithValue("@ProjectName", Name);
                    command.Parameters.AddWithValue("@YearStart", YearStart);
                    command.Parameters.AddWithValue("@YearDuration", YearDuration);
                    command.Parameters.AddWithValue("@ProjectCreator", ProjectCreator);
                    command.Parameters.AddWithValue("@ReserveDaysInActive", ReserveDaysInActive);
                    command.Parameters.AddWithValue("@ReserveDaysActive", ReserveDaysActive);
                    command.Parameters.AddWithValue("@UpdateDate", UpdateDate);
                    command.Parameters.AddWithValue("@CreateDate", CreateDate);
                    command.Parameters.AddWithValue("@LastUpdate", DateTime.Now);
                    command.Parameters.AddWithValue("@Description", Description);
                    for (int i = 0; i <= 30; i++) {
                        command.Parameters.AddWithValue("@DiscountRate" + i, DiscountRate[i]);
                    }
                    command.CommandType = CommandType.Text;
                    rowsAffected = command.ExecuteNonQuery();
                }
            }

            return rowsAffected;
        }
        public static DataSet GetProjectOutputs(int ProjectID) {
            DataSet projectOutputs = new DataSet();
            string sqlStatement = "SELECT * FROM web.PMGetProjectOutputs(@ProjectId) ORDER BY PayPlan;";

            using (NpgsqlConnection connection = new NpgsqlConnection(AppConfiguration.GetConnectionString()))
                {
                connection.Open();
                NpgsqlDataAdapter adapter = new NpgsqlDataAdapter();
                using (NpgsqlCommand command = new NpgsqlCommand(sqlStatement, connection))
                {
                    command.Parameters.AddWithValue("@ProjectID", ProjectID);
                    command.CommandType = CommandType.Text;
                    adapter.SelectCommand = command;
                    adapter.Fill(projectOutputs);
                }
            }

            return projectOutputs;
        }
        private static Project MapProject(NpgsqlDataReader reader) {
            Project project = new Project();

            if (!reader.IsDBNull(reader.GetOrdinal("UserId")))
            {
                project.UserId = reader.GetString(reader.GetOrdinal("UserId"));
            }

            if (!reader.IsDBNull(reader.GetOrdinal("CreateDate")))
            {
                project.CreateDate = reader.GetDateTime(reader.GetOrdinal("CreateDate"));
            }

            if (!reader.IsDBNull(reader.GetOrdinal("Description")))
            {
                project.Description = reader.GetString(reader.GetOrdinal("Description"));
            }

            if (!reader.IsDBNull(reader.GetOrdinal("LastUpdate")))
            {
                project.LastUpdate = reader.GetDateTime(reader.GetOrdinal("LastUpdate"));
            }

            if (!reader.IsDBNull(reader.GetOrdinal("ProjectName")))
            {
                project.ProjectName = reader.GetString(reader.GetOrdinal("ProjectName"));
            }

            if (!reader.IsDBNull(reader.GetOrdinal("ProjectCreator")))
            {
                project.ProjectCreator = reader.GetString(reader.GetOrdinal("ProjectCreator"));
            }

            if (!reader.IsDBNull(reader.GetOrdinal("ProjectId")))
            {
                project.ProjectId = reader.GetInt32(reader.GetOrdinal("ProjectId"));
            }

            if (!reader.IsDBNull(reader.GetOrdinal("ReserveDaysActive")))
            {
                project.ReserveDaysActive = reader.GetInt32(reader.GetOrdinal("ReserveDaysActive"));
            }

            if (!reader.IsDBNull(reader.GetOrdinal("ReserveDaysInActive")))
            {
                project.ReserveDaysInActive = reader.GetInt32(reader.GetOrdinal("ReserveDaysInActive"));
            }

            if (!reader.IsDBNull(reader.GetOrdinal("YearDuration")))
            {
                project.YearDuration = reader.GetInt32(reader.GetOrdinal("YearDuration"));
            }

            if (!reader.IsDBNull(reader.GetOrdinal("YearStart")))
            {
                project.YearStart = reader.GetInt32(reader.GetOrdinal("YearStart"));
            }

            if (String.IsNullOrEmpty(project.ProjectCreator)) {
                project.ProjectCreator = project.UserId;
            }
            return project;
        }
    }
}