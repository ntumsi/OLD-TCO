-- =============================================
-- Author:		Name
-- Create date: 
-- Description:	
-- =============================================
CREATE FUNCTION [web].[PMInventoryBySkillId]
(
    @ProjectId INT
)
RETURNS TABLE
AS
RETURN
(
    WITH CategorySkillInventory
    AS (SELECT PMCategory.ProjectId,
               PMCategory.CategoryName AS PMCategoryName,
               PMCategory.CategoryId,
               PMCategorySkill.PayPlan,
               PMCategorySkill.SkillId,
               PMCategorySkill.CategoryGroupCode,
               PMCategorySkill.CategorySubgroupCode,
               PMCategorySkill.GradeLevel,
               csi.[Year],
               csi.Amount AS Inventory,
               PMCategorySkill.ActiveDutyDays
        FROM webuser.PMCategory PMCategory
            JOIN webuser.PMCategorySkill PMCategorySkill
                ON PMCategory.CategoryId = PMCategorySkill.CategoryId
            JOIN webuser.PMCategorySkillInventory csi
                ON PMCategorySkill.SkillId = csi.SkillId)
    SELECT CategorySkillInventory.ProjectId,
           CategorySkillInventory.PMCategoryName,
           CategorySkillInventory.CategoryId,
           CategorySkillInventory.PayPlan,
           CategorySkillInventory.SkillId,
           CategorySkillInventory.CategoryGroupCode,
           CategorySkillInventory.CategorySubgroupCode,
           CategorySkillInventory.GradeLevel,
           CategorySkillInventory.Year,
           CategorySkillInventory.Inventory,
           CategorySkillInventory.ActiveDutyDays
    FROM CategorySkillInventory
    WHERE CategorySkillInventory.ProjectId = @ProjectId
);