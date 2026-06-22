using AMCOS.Data;
using AMCOS.Data.Entities;
using AMCOS.Data.ViewModels;
using System;

namespace AMCOS.Logic
{
    public class LogHelper
    {
        public static void LogApplicationError(ApplicationErrorLogViewModel applicationError)
        {
            using (var context = new ApplicationDbContext())
            {
                if (applicationError == null)
                {
                    throw new ArgumentNullException("applicationError");
                }

                var applicationErrorLog = new ApplicationErrorLog()
                {
                    ErrorTime = applicationError.ErrorTime,
                    UserId = applicationError.UserId,
                    ErrorPage = applicationError.ErrorPage,
                    ErrorDetail = applicationError.ErrorDetail
                };

                context.ApplicationErrorLog.Add(applicationErrorLog);
                context.SaveChanges();
            }
        }
        public void LogError(string errorMessage, string userId)
        {
            using (var context = new ApplicationDbContext())
            {
                context.ApplicationErrorLog.Add(new ApplicationErrorLog { ErrorTime = DateTime.Now, UserId = userId, ErrorPage = "Lite/Default.aspx.vb", ErrorDetail = errorMessage });
                context.SaveChanges();
            }
        }
    }
}
