
-- =============================================
-- Description:	
-- =============================================
CREATE FUNCTION [web].[PMGetProjectOutputs]
(
    @UserId NVARCHAR(50),
    @ProjectId INT
)
RETURNS TABLE
AS
RETURN
(
    SELECT DISTINCT
        webuser.PMCategory.CategoryId,
        webuser.PMCategory.CategoryName AS Category,
        webuser.PMCategorySkill.PayPlan
    FROM webuser.PMCategory
        INNER JOIN webuser.PMCategorySkill
            ON webuser.PMCategory.UserId = webuser.PMCategorySkill.UserId
               AND webuser.PMCategory.ProjectId = webuser.PMCategorySkill.ProjectId
               AND webuser.PMCategory.CategoryId = webuser.PMCategorySkill.CategoryId
        INNER JOIN webuser.User_Summaries
            ON webuser.PMCategorySkill.UserId = webuser.User_Summaries.UserId
               AND webuser.PMCategorySkill.ProjectId = webuser.User_Summaries.ProjectId
               AND webuser.PMCategorySkill.PayPlan = webuser.User_Summaries.PayPlan
    WHERE (
              webuser.User_Summaries.InReport = 1
              AND webuser.User_Summaries.UserId = @UserId
              AND webuser.User_Summaries.ProjectId = @ProjectId
          )
    GROUP BY webuser.PMCategory.CategoryName,
             webuser.PMCategory.CategoryId,
             webuser.PMCategorySkill.PayPlan,
             webuser.User_Summaries.SummaryName
);