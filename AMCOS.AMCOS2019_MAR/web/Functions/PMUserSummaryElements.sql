
-- =======================================================================================
-- Description:  Select all records from UserSummaryElements for a given project and user.
-- =======================================================================================
CREATE FUNCTION [web].[PMUserSummaryElements]
(
    @UserId NVARCHAR(50),
    @ProjectId INT
)
RETURNS TABLE
AS
RETURN
(
    SELECT CostElementId,
           SummaryId
    FROM webuser.User_SummaryElements
    WHERE UserId = @UserId
          AND ProjectId = @ProjectId
);