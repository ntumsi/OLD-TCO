using Amazon.QuickSight;
using Amazon.QuickSight.Model;
using System;

namespace AMCOS.Logic
{
    public class QuickSight
    {
        public const string ArnIdentifier = "arn:aws-us-gov";
        public string AwsAccountId { get; set; }
        public string AwsRegionCode { get; set; }
        public string Arn => string.Format("{0}:quicksight:{1}:{2}", ArnIdentifier, AwsRegionCode, AwsAccountId);
        public QuickSight(string awsAccountId, string awsRegionCode)
        {
            AwsAccountId = awsAccountId;
            AwsRegionCode = awsRegionCode;
        }
        public string EmbedDashboard(string dashboardId)
        {
            try
            {
                var client = new AmazonQuickSightClient(Amazon.RegionEndpoint.USGovCloudWest1);
                string dashboardArn = string.Format("{0}:dashboard/{1}", Arn, dashboardId);                

                AnonymousUserDashboardEmbeddingConfiguration anonymousUserDashboardEmbeddingConfiguration = new AnonymousUserDashboardEmbeddingConfiguration
                {
                    InitialDashboardId = dashboardId
                };

                AnonymousUserEmbeddingExperienceConfiguration anonymousUserEmbeddingExperienceConfiguration            
                    = new AnonymousUserEmbeddingExperienceConfiguration                    
                    {
                        Dashboard = anonymousUserDashboardEmbeddingConfiguration
                    };

                return client.GenerateEmbedUrlForAnonymousUserAsync(new GenerateEmbedUrlForAnonymousUserRequest
                {
                    AwsAccountId = AwsAccountId,
                    Namespace = "default",
                    AuthorizedResourceArns = { dashboardArn },
                    ExperienceConfiguration = anonymousUserEmbeddingExperienceConfiguration,
                    SessionLifetimeInMinutes = 180,
                }).Result.EmbedUrl;
            } catch 
            {
                return "Error";
            }
        }
        public string EmbedVisual(string dashboardId, string sheetId, string visualId)
        {
            try
            {
                var client = new AmazonQuickSightClient(Amazon.RegionEndpoint.USGovCloudWest1);
                string dashboardArn = string.Format("{0}:dashboard/{1}", Arn, dashboardId);

                DashboardVisualId dashboardVisual = new DashboardVisualId
                {
                    DashboardId = dashboardId,
                    SheetId = sheetId,
                    VisualId = visualId
                };

                AnonymousUserDashboardVisualEmbeddingConfiguration anonymousUserDashboardVisualEmbeddingConfiguration
                    = new AnonymousUserDashboardVisualEmbeddingConfiguration
                    {
                        InitialDashboardVisualId = dashboardVisual
                    };

                AnonymousUserEmbeddingExperienceConfiguration anonymousUserEmbeddingExperienceConfiguration
                = new AnonymousUserEmbeddingExperienceConfiguration
                {
                    DashboardVisual = anonymousUserDashboardVisualEmbeddingConfiguration
                };

                return client.GenerateEmbedUrlForAnonymousUserAsync(new GenerateEmbedUrlForAnonymousUserRequest
                {
                    AwsAccountId = AwsAccountId,
                    Namespace = "default",
                    AuthorizedResourceArns = { dashboardArn },
                    SessionLifetimeInMinutes = 15,
                    ExperienceConfiguration = anonymousUserEmbeddingExperienceConfiguration,
                }).Result.EmbedUrl;
            } catch (Exception ex)
            {
                return "Error";
            }
        }
    }
}
