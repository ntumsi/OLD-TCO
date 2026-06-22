using AMCOS.Logic.Models;
using System;
using System.Collections.Generic;
using System.Configuration;
using System.Linq;
using System.Net.Mail;
using System.Web;

namespace AMCOS.Logic.Helpers
{
    public static class EmailHelper
    {

        public static void SendEmail(this Email email)
        {
            SendEmail(email.From, email.To, email.Subject, email.Body, email.FilesToAttach, email.CcEmailAddresses, email.BccEmailAddresses);
        }
        /// <summary>
        /// Send an email with optional parameters
        /// </summary>
        /// <param name="fromAddress"></param>
        /// <param name="toAddresses"></param>
        /// <param name="subject"></param>
        /// <param name="body"></param>
        /// <param name="filesToAttach"></param>
        /// <param name="ccEmailAddresses"></param>
        /// <param name="bccEmailAddresses"></param>
        public static void SendEmail(string fromAddress, string[] toAddresses, string subject, string body, string[] filesToAttach = null, string[] ccEmailAddresses = null, string[] bccEmailAddresses = null)
        {
            var emailFrom = new MailAddress(fromAddress);
            var mailMessage = new MailMessage()
            {
                From = emailFrom,
                IsBodyHtml = true,
                Subject = subject,
                Body = body

            };
            toAddresses?.ToList().ForEach(a => mailMessage.To.Add(new MailAddress(a)));
            filesToAttach?.ToList().ForEach(f => mailMessage.Attachments.Add(new Attachment(f)));
            ccEmailAddresses?.ToList().ForEach(c => mailMessage.CC.Add(new MailAddress(c)));
            bccEmailAddresses?.ToList().ForEach(b => mailMessage.Bcc.Add(new MailAddress(b)));

            if (ConfigurationManager.AppSettings["Environment"] != "UnitTest")
            {
                //Send the email
                SmtpClient client = new SmtpClient(ConfigurationManager.AppSettings["SmtpHost"], Int32.Parse(ConfigurationManager.AppSettings["SmtpPort"]));
                client.Credentials = new System.Net.NetworkCredential(ConfigurationManager.AppSettings["SmtpCredentialsUserName"], ConfigurationManager.AppSettings["SmtpCredentialsPassword"]);
                client.Send(mailMessage);
            }
        }
                
    }
}
