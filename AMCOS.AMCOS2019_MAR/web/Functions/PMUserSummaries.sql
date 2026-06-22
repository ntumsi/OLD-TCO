-- =============================================
-- Author:		Name
-- Create date: 
-- Description:	
-- =============================================
CREATE FUNCTION web.PMUserSummaries
(
    @UserId NVARCHAR(50),
    @ProjectId INT
)
RETURNS TABLE
AS
RETURN
(
    SELECT SummaryName,
           PayPlan,
           SummaryId
    FROM webuser.User_Summaries
    WHERE UserId = @UserId
          AND ProjectId = @ProjectId
);