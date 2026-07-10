using System;
using System.IO;
using System.Linq;
using System.Net.Mail;

namespace AMCOS.Logic.Helpers
{
    /// <summary>
    /// Minimal, config-driven SMTP sender for the ported ASP.NET Core app. The legacy
    /// <c>EmailHelper</c> depends on <c>System.Web</c> / <c>ConfigurationManager</c> and is excluded
    /// from the net8.0 build, so account-workflow emails (approval / denial / sponsor) were silently
    /// dropped in production. This restores that behaviour: callers pass the SMTP host/port and
    /// addresses from <c>appsettings.json</c>, and when the host is blank the send is a graceful no-op
    /// (so unconfigured environments behave exactly as before rather than throwing).
    /// </summary>
    public static class CoreEmailHelper
    {
        /// <summary>
        /// Sends an HTML email. No-ops (returns false) when <paramref name="host"/> or every
        /// recipient is blank. Never throws for a missing configuration; genuine SMTP failures
        /// propagate so the caller can surface them.
        /// </summary>
        public static bool Send(string host, int port, string from, string[] to, string subject,
            string htmlBody, string[] attachments = null)
        {
            if (string.IsNullOrWhiteSpace(host)) return false;

            var recipients = (to ?? Array.Empty<string>())
                .Where(a => !string.IsNullOrWhiteSpace(a))
                .ToArray();
            if (recipients.Length == 0) return false;

            // A blank From is invalid for MailAddress; fall back to the first recipient.
            var fromAddress = string.IsNullOrWhiteSpace(from) ? recipients[0] : from;

            using (var message = new MailMessage
            {
                From = new MailAddress(fromAddress),
                Subject = subject ?? string.Empty,
                Body = htmlBody ?? string.Empty,
                IsBodyHtml = true
            })
            {
                foreach (var r in recipients) message.To.Add(new MailAddress(r));

                if (attachments != null)
                {
                    foreach (var file in attachments.Where(f => !string.IsNullOrWhiteSpace(f) && File.Exists(f)))
                        message.Attachments.Add(new Attachment(file));
                }

                using (var client = new SmtpClient(host, port))
                {
                    client.Send(message);
                }
            }

            return true;
        }
    }
}
