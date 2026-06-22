
CREATE VIEW [web].[PMCategorySkillInventory]
AS
SELECT PMProject.UserId,
       PMProject.ProjectId,
       PMCategory.CategoryName,
       PMCategory.CategoryId,
       PMCategorySkill.Uic,
       PMCategorySkill.PayPlan,
       PMCategorySkill.CategoryGroupCode,
       PMCategorySkill.CategorySubgroupCode,
       PMCategorySkill.CareerProgramNumber,
       PMCategorySkill.LocationId,
       PMCategorySkill.LocationText,
       PMCategorySkill.STRL,
       PMCategorySkill.GradeLevel,
       PMCategorySkill.DependentStatus,
       PMCategorySkill.NumberOfDependents,
       PMCategorySkill.ActiveDutyDays,
       PMCategorySkill.OverheadPercent,
       PMCategorySkillInventory.[Year] + PMProject.YearStart Year,
       PMCategorySkillInventory.Amount
FROM webuser.PMCategory PMCategory
    INNER JOIN webuser.PMCategorySkill PMCategorySkill
        ON PMCategory.CategoryId = PMCategorySkill.CategoryId
    INNER JOIN webuser.PMCategorySkillInventory PMCategorySkillInventory
        ON PMCategorySkill.SkillId = PMCategorySkillInventory.SkillId
    INNER JOIN webuser.PMProject PMProject
        ON PMProject.ProjectId = PMCategory.ProjectId
    INNER JOIN webuser.PMReport PMReport
        ON PMReport.CategoryId = PMCategory.CategoryId
           AND PMReport.PayPlan = PMCategorySkill.PayPlan
WHERE PMCategorySkillInventory.Year <= PMProject.YearDuration - 1;