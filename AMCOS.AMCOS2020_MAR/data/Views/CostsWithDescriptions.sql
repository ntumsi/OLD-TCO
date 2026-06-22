



CREATE VIEW [data].[CostsWithDescriptions]
AS
SELECT Costs.PayPlan,
       Costs.CategoryGroupCode,
       ISNULL(CategoryGroup.CategoryGroupDescription, 'Average') AS CategoryGroupDescription,
       Costs.CategorySubgroupCode,
       ISNULL(CategorySubgroup.CategorySubgroupDescription, 'Average') AS CategorySubgroupDescription,
       Costs.CareerProgramNumber,
       ISNULL(CP.Title, 'None') AS CP_title,
       Costs.Strl,
       Costs.LocationId,
       ISNULL(LOC.DisplayName, 'Average') AS Location_name,
       Costs.DependentStatus,
	   costs.NumberOfDependents,
       Costs.CostElementId,
       Costs.AppropriationGroup,
       Costs.APPN,
       Costs.CostElementCategory,
       Costs.CostElementName,
       Costs.Description,
       Costs.ArmyCesTitle,
       Costs.OsdCapeCesTitle,
       Costs.ShowOrder,
       Costs.GradeType,
       Costs.GradeLevel,
       WeaponSystem.WeaponSystemName,
	   costs.WeaponSystemId,
       Costs.Amount,
       Costs.AmcosVersionId
FROM data.Costs Costs
    LEFT OUTER JOIN data.CategorySubgroup CategorySubgroup
        ON CategorySubgroup.PayPlan = Costs.PayPlan
           AND CategorySubgroup.CategorySubgroupCode = Costs.CategorySubgroupCode
    LEFT OUTER JOIN data.CategoryGroup CategoryGroup
        ON CategoryGroup.CategoryGroupCode = Costs.CategoryGroupCode
           AND Costs.PayPlan = CategoryGroup.PayPlan
    LEFT OUTER JOIN
    (
        SELECT a.WeaponSystemId,
               a.WeaponSystemName
        FROM lookup.WeaponSystem AS a
            INNER JOIN
            (
                SELECT WeaponSystemId,
                       MAX(AmcosVersionIdEnd) AS maxversion
                FROM lookup.WeaponSystem
                GROUP BY WeaponSystemId
            ) AS b
                ON a.WeaponSystemId = b.WeaponSystemId
                   AND a.AmcosVersionIdEnd = b.maxversion
    ) AS WeaponSystem
        ON WeaponSystem.WeaponSystemId = Costs.WeaponSystemId
    LEFT OUTER JOIN
    (
        SELECT a.CareerProgramNumber,
               a.Title
        FROM lookup.ArmyCareerProgram AS a
            INNER JOIN
            (
                SELECT CareerProgramNumber,
                       MAX(AmcosVersionIdEnd) AS maxversion
                FROM lookup.ArmyCareerProgram
                GROUP BY CareerProgramNumber
            ) AS b
                ON a.CareerProgramNumber = b.CareerProgramNumber
                   AND a.AmcosVersionIdEnd = b.maxversion
    ) AS CP
        ON Costs.CareerProgramNumber = CP.CareerProgramNumber
    LEFT OUTER JOIN warehouse.Location AS LOC
        ON LOC.LocationId = Costs.LocationId;