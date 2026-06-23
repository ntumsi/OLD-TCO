using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using Amazon;
using Amazon.Athena;
using Amazon.Athena.Model;
using Amazon.Runtime;
using System.Threading;

namespace AMCOS.Logic.Helpers
{
    /// <summary>
    /// Athena Helper requires resource permissions which should be configured at the role level if executing on an AWS service. 
    /// However, if debugging locally create an AWS Access Key.
    /// Run the following: rundll32 sysdm.cpl,EditEnvironmentVariables to edit your user specific environment variables.
    /// Add new variables: AWS_ACCESS_KEY_ID, and AWS_SECRET_ACCESS_KEY and add your values.
    /// Restart IDE
    /// </summary>
    public static class AthenaHelper
    {

        public static GetQueryResultsResponse ExecuteQuery(string query, string databaseName)
        {
            IAmazonAthena athenaClient = new AmazonAthenaClient(RegionEndpoint.GetBySystemName("us-gov-west-1"));
            // Start the query
            StartQueryExecutionResponse startResponse = athenaClient.StartQueryExecution(
                    new StartQueryExecutionRequest
                    {
                        QueryString = query,
                        QueryExecutionContext = new QueryExecutionContext
                        {
                            Database = databaseName
                        },
                        WorkGroup = "amcos"
                    });

            string queryExecutionId = startResponse.QueryExecutionId;

            // Wait for query completion
            QueryExecutionState state;
            do
            {
                Thread.Sleep(750);
                var status = athenaClient.GetQueryExecution(
                    new GetQueryExecutionRequest { QueryExecutionId = queryExecutionId });
                state = status.QueryExecution.Status.State;
            } while (state == QueryExecutionState.RUNNING || state == QueryExecutionState.QUEUED);

            if (state != QueryExecutionState.SUCCEEDED)
            {
                throw new InvalidOperationException("Athena query failed with state: " + state);
            }

            // Get results
            return athenaClient.GetQueryResults(new GetQueryResultsRequest { QueryExecutionId = queryExecutionId });
        }
    }
}
