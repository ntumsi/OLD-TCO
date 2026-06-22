

-- =============================================
-- Author:		Name
-- Create date: 
-- Description:	
-- =============================================
CREATE FUNCTION [web].[GetCategorySkillsWithLocalityPay]
(
    @UserId NVARCHAR(50),
    @ProjectId INT,
    @CategoryId INT
)
RETURNS TABLE
AS
RETURN
(
    SELECT PMCategorySkill.UserId,
           PMCategorySkill.ProjectId,
           PMCategorySkill.CategoryId,
           PMCategorySkill.SkillId,
           PMCategorySkill.PayPlan,
           CASE CategoryGroupCode
               WHEN '__ALL__' THEN
                   'ALL'
               ELSE
                   CategoryGroupCode
           END AS CategoryGroupCode,
           CASE CategorySubGroupCode
               WHEN '__ALL__' THEN
                   'ALL'
               ELSE
                   CategorySubGroupCode
           END AS CategorySubGroupCode,
           PMCategorySkill.[Type],
           PMCategorySkill.AreaCode,
           PMCategorySkill.LocalityId,
           PMCategorySkill.GradeType,
           PMCategorySkill.GradeLevel,
           tblLoc.Amount AS LocalityAmount,
           PMCategorySkill.activeDays,
           PMCategorySkill.overheadPct,
           PMCategorySkill.StateCountry,
           FunctionalAreaText + ' (' + PMCategorySkill.FunctionalAreaCode + ')' AS FunctionalAreaText,
           PMCategorySkill.FunctionalAreaCode,
           CostCenterText + ' (' + PMCategorySkill.CostCenterCode + ')' AS CostCenterText,
           PMCategorySkill.CostCenterCode
    FROM webuser.PMCategorySkill PMCategorySkill
        INNER JOIN lookup.LocalityRates tblLoc
            ON COALESCE(tblLoc.Id, '') = COALESCE(PMCategorySkill.LocalityId, '')
        LEFT JOIN lookup.GFEBS_FunctionalArea GFEBS_FunctionalArea
            ON GFEBS_FunctionalArea.FunctionalAreaCode = PMCategorySkill.FunctionalAreaCode
        LEFT JOIN lookup.GFEBS_CostCenter GFEBS_CostCenter
            ON GFEBS_CostCenter.CostCenterCode = PMCategorySkill.CostCenterCode
    WHERE (
              PMCategorySkill.UserId = @UserId
              AND PMCategorySkill.ProjectId = @ProjectId
              AND PMCategorySkill.CategoryId = @CategoryId
          )
);