
-- =============================================
-- Description:	
-- =============================================
CREATE FUNCTION [web].[PMGetProjectOutputs]
(
    @ProjectId INT
)
RETURNS TABLE
AS
RETURN
(
    SELECT CategoryId,
           CategoryName AS Category,
           PayPlan
    FROM web.PMCategorySkill
    WHERE ProjectId = @ProjectId
    GROUP BY CategoryName,
             CategoryId,
             PayPlan
);