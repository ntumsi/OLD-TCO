
CREATE VIEW [web].[PMCategorySkill]
AS
SELECT PMProject.UserId,
       PMProject.ProjectId,
       PMProject.ProjectName,
       PMCategory.CategoryName,
       PMCategory.CategoryId,
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
       PMCategorySkill.OverheadPercent
FROM webuser.PMCategory PMCategory
    INNER JOIN webuser.PMCategorySkill PMCategorySkill
        ON PMCategory.CategoryId = PMCategorySkill.CategoryId
    INNER JOIN webuser.PMProject PMProject
        ON PMProject.ProjectId = PMCategory.ProjectId;