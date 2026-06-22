
-- =============================================
-- Author:		Name
-- Create date: 
-- Description:	
-- =============================================
CREATE FUNCTION [web].[GetCategorySkillWithLocalityPay]
(
    @UserId NVARCHAR(50),
    @ProjectId INT,
    @CategoryId INT,
    @SkillId INT
)
RETURNS TABLE
AS
RETURN
(
    SELECT UserId,
           ProjectId,
           CategoryId,
           SkillId,
           PayPlan,
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
           [Type],
           tblSkills.AreaCode,
           tblSkills.LocalityId,
           GradeType,
           GradeLevel,
           tblLoc.Amount AS LocalityAmount,
           activeDays,
           overheadPct,
           FunctionalAreaText + ' (' + tblSkills.FunctionalAreaCode + ')' AS FunctionalAreaText,
           tblSkills.FunctionalAreaCode,
           CostCenterText + ' (' + tblSkills.CostCenterCode + ')' AS CostCenterText,
           tblSkills.CostCenterCode
    FROM webuser.PMCategorySkill tblSkills
        INNER JOIN lookup.LocalityRates tblLoc
            ON COALESCE(tblLoc.Id, '') = COALESCE(tblSkills.LocalityId, '')
        LEFT JOIN lookup.GFEBS_FunctionalArea
            ON GFEBS_FunctionalArea.FunctionalAreaCode = tblSkills.FunctionalAreaCode
        LEFT JOIN lookup.GFEBS_CostCenter
            ON GFEBS_CostCenter.CostCenterCode = tblSkills.CostCenterCode
    WHERE (
              UserId = @UserId
              AND ProjectId = @ProjectId
              AND CategoryId = @CategoryId
              AND SkillId = @SkillId
          )
);