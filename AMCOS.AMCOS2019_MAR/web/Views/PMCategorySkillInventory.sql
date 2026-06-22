



CREATE VIEW [web].[PMCategorySkillInventory]
AS
SELECT PMProject.UserId,
       PMProject.ProjectId,
       PMReport.SummaryName,
       PMCategory.CategoryName AS CatName,
       PMCategory.CategoryId,
       PMCategorySkill.PayPlan,
       PMCategorySkill.Type,
       PMCategorySkill.CategoryGroupCode,
       PMCategorySkill.CategorySubGroupCode,
       PMCategorySkill.AreaCode,
       PMCategorySkill.GradeType,
       PMCategorySkill.GradeLevel,
       PMCategorySkill.LocalityId,
       PMCategorySkillInventory.[Year],
       PMCategorySkillInventory.Amount
FROM webuser.PMCategory
    INNER JOIN webuser.PMCategorySkill
        ON PMCategory.UserId = PMCategorySkill.UserId
           AND PMCategory.ProjectId = PMCategorySkill.ProjectId
           AND PMCategory.CategoryId = PMCategorySkill.CategoryId
    INNER JOIN webuser.PMCategorySkillInventory
        ON PMCategorySkill.SkillId = PMCategorySkillInventory.SkillId
    INNER JOIN webuser.PMProject
        ON PMProject.ProjectId = PMCategory.ProjectId
           AND PMProject.UserId = PMCategory.UserId
    INNER JOIN webuser.PMReport
        ON PMReport.ProjectId = PMProject.ProjectId
           AND PMReport.UserId = PMProject.UserId
           AND PMReport.CategoryId = PMCategory.CategoryId
           AND PMReport.PayPlan = PMCategorySkill.PayPlan;