-- =============================================
-- Author:		Name
-- Create date: 
-- Description:	
-- =============================================
CREATE FUNCTION [web].[PMInventoryBySkillId]
(
    @UserId NVARCHAR(50),
    @ProjectId INT
)
RETURNS TABLE
AS
RETURN
(
    WITH CategorySkillInventory
    AS (SELECT c.ProjectId,
               c.UserId,
               c.CategoryName AS PMCategoryName,
               c.CategoryId,
               cs.PayPlan,
               cs.SkillId,
               cs.CategoryGroupCode,
               cs.CategorySubGroupCode,
               cs.Type,
               cs.AreaCode,
               cs.GradeType,
               cs.GradeLevel,
               cs.LocalityId,
               cs.SpecialRateTableNumber,
               cs.StateCountry,
               cs.FunctionalAreaCode,
               cs.CostCenterCode,
               csi.[Year],
               csi.Amount AS Inventory,
               cs.activeDays
        FROM webuser.PMCategory c
            JOIN webuser.PMCategorySkill cs
                ON c.UserId = cs.UserId
                   AND c.ProjectId = cs.ProjectId
                   AND c.CategoryId = cs.CategoryId
            JOIN webuser.PMCategorySkillInventory csi
                ON cs.SkillId = csi.SkillId)
    SELECT CategorySkillInventory.ProjectId,
           CategorySkillInventory.UserId,
           CategorySkillInventory.PMCategoryName,
           CategorySkillInventory.CategoryId,
           CategorySkillInventory.PayPlan,
           CategorySkillInventory.SkillId,
           CategorySkillInventory.CategoryGroupCode,
           CategorySkillInventory.CategorySubGroupCode,
           CategorySkillInventory.Type,
           CategorySkillInventory.AreaCode,
           CategorySkillInventory.GradeType,
           CategorySkillInventory.GradeLevel,
           CategorySkillInventory.LocalityId,
           CategorySkillInventory.SpecialRateTableNumber,
           CategorySkillInventory.StateCountry,
           CategorySkillInventory.FunctionalAreaCode,
           CategorySkillInventory.CostCenterCode,
           CategorySkillInventory.Year,
           CategorySkillInventory.Inventory,
           CategorySkillInventory.activeDays
    FROM CategorySkillInventory
    WHERE CategorySkillInventory.ProjectId = @ProjectId
          AND CategorySkillInventory.UserId = @UserId
);