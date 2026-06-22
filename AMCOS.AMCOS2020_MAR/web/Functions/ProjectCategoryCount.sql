-- =============================================
-- Author:		
-- Create date: 
-- Description:	Check for duplicates before copying a project category
-- =============================================
CREATE FUNCTION [web].[ProjectCategoryCount]
(
    @ProjectId INTEGER,
    @FromCategoryId INTEGER,
    @ToCategoryId INTEGER
)
RETURNS INT
AS
BEGIN
    DECLARE @Result INT;

    SELECT @Result = COUNT(*)
    FROM
    (
        SELECT PMCategory.ProjectId,
               PMCategorySkill.CategoryId,
               PMCategorySkill.SkillId,
               PMCategorySkill.PayPlan,
               PMCategorySkill.CategoryGroupCode,
               PMCategorySkill.CategorySubgroupCode,
               PMCategorySkill.GradeLevel,
               PMCategorySkill.ActiveDutyDays,
               PMCategorySkill.OverheadPercent
        FROM webuser.PMCategorySkill PMCategorySkill
            INNER JOIN webuser.PMCategory PMCategory
                ON PMCategory.CategoryId = PMCategorySkill.CategoryId
        WHERE PMCategory.ProjectId = @ProjectId
              AND PMCategorySkill.CategoryId = @FromCategoryId
    ) a
        LEFT JOIN
        (
            SELECT PMCategory.ProjectId,
                   PMCategorySkill.CategoryId,
                   PMCategorySkill.SkillId,
                   PMCategorySkill.PayPlan,
                   PMCategorySkill.CategoryGroupCode,
                   PMCategorySkill.CategorySubgroupCode,
                   PMCategorySkill.GradeLevel,
                   PMCategorySkill.ActiveDutyDays,
                   PMCategorySkill.OverheadPercent
            FROM webuser.PMCategorySkill PMCategorySkill
                INNER JOIN webuser.PMCategory PMCategory
                    ON PMCategory.CategoryId = PMCategorySkill.CategoryId
            WHERE PMCategory.ProjectId = @ProjectId
                  AND PMCategorySkill.CategoryId = @ToCategoryId
        ) b
            ON a.ProjectId = b.ProjectId
               AND a.PayPlan = b.PayPlan
               AND a.CategorySubgroupCode = b.CategorySubgroupCode
               AND a.GradeLevel = b.GradeLevel
               AND ISNULL(a.OverheadPercent, 0) = ISNULL(b.OverheadPercent, 0)
    WHERE b.ProjectId IS NULL;

    RETURN @Result;

END;