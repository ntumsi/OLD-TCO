
-- =============================================
-- Author:      Name
-- Create Date: 
-- Description: 
-- =============================================

CREATE PROCEDURE [web].[DeleteProject]
(@ProjectId INT)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @Category TABLE
    (
        CategoryId INT NOT NULL
    );
    INSERT INTO @Category
    (
        CategoryId
    )
    SELECT CategoryId
    FROM webuser.PMCategory
    WHERE ProjectId = @ProjectId;

    DECLARE @Skill TABLE
    (
        SkillId INT NOT NULL
    );
    INSERT INTO @Skill
    (
        SkillId
    )
    SELECT PMCategorySkill.SkillId
    FROM webuser.PMCategorySkill PMCategorySkill
        INNER JOIN @Category Category
            ON Category.CategoryId = PMCategorySkill.CategoryId;

    DECLARE @Inventory TABLE
    (
        InventoryId INT NOT NULL
    );
    INSERT INTO @Inventory
    (
        InventoryId
    )
    SELECT PMCategorySkillInventory.InventoryId
    FROM webuser.PMCategorySkillInventory PMCategorySkillInventory
        INNER JOIN @Skill Skill
            ON Skill.SkillId = PMCategorySkillInventory.SkillId;

    DELETE PMCategorySkillInventory
    FROM webuser.PMCategorySkillInventory PMCategorySkillInventory
        INNER JOIN @Skill Skill
            ON Skill.SkillId = PMCategorySkillInventory.SkillId;

    DELETE PMCategorySkill
    FROM webuser.PMCategorySkill PMCategorySkill
        INNER JOIN @Category Category
            ON Category.CategoryId = PMCategorySkill.CategoryId;

    DELETE PMReport
    FROM webuser.PMReport PMReport
        INNER JOIN @Category Category
            ON Category.CategoryId = PMReport.CategoryId;

    DELETE FROM webuser.PMCategory
    WHERE ProjectId = @ProjectId;

    DELETE FROM webuser.PMProject
    WHERE ProjectId = @ProjectId;
END;