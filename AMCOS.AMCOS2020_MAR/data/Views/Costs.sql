



CREATE VIEW [data].[Costs]
AS
SELECT ISNULL(ROW_NUMBER() OVER (ORDER BY (SELECT 1)), -1) AS RowId,
       AllCosts.PayPlan,
       AllCosts.CategoryGroupCode,
       AllCosts.CategorySubgroupCode,
       AllCosts.CareerProgramNumber,
       AllCosts.LocationId,
       AllCosts.Strl,
       AllCosts.CostElementId,
       AllCosts.WeaponSystemId,
       AllCosts.GradeType,
       AllCosts.GradeLevel,
       AllCosts.DependentStatus,
       AllCosts.NumberOfDependents,
       AllCosts.Amount,
       AllCosts.CrunchTime,
       AllCosts.AmcosVersionId,
       CostElement.AppropriationGroup,
       CostElement.APPN,
       CostElement.CostElementCategory,
       CostElement.CostElementName,
       CostElement.Description,
       CostElement.ArmyCesTitle,
       CostElement.OsdCapeCesTitle,
       CostElement.Amort,
       CostElement.Model,
       CostElement.Locality,
       CostElement.ApplyInflation,
       CostElement.IsLocationSpecific,
       CostElement.ShowOrder
FROM
(
    SELECT PayPlan,
           CMF AS CategoryGroupCode,
           MOS AS CategorySubgroupCode,
           '-1' AS CareerProgramNumber,
           LocationId,
           '-1' AS Strl,
           CostElementId,
           WeaponSystemId,
           GradeType,
           GradeLevel,
           DependentStatus,
           '-1' AS NumberOfDependents,
           Amount,
           CrunchTime,
           AmcosVersionId
    FROM crunch.Costs_AE
    UNION ALL
    SELECT PayPlan,
           CMF AS CategoryGroupCode,
           AOC AS CategorySubgroupCode,
           '-1' AS CareerProgramNumber,
           LocationId,
           '-1' AS Strl,
           CostElementId,
           WeaponSystemId,
           GradeType,
           GradeLevel,
           DependentStatus,
           '-1' AS NumberOfDependents,
           Amount,
           CrunchTime,
           AmcosVersionId
    FROM crunch.Costs_AO
    UNION ALL
    SELECT PayPlan,
           Branch AS CategoryGroupCode,
           WOMOS AS CategorySubgroupCode,
           '-1' AS CareerProgramNumber,
           LocationId,
           '-1' AS Strl,
           CostElementId,
           WeaponSystemId,
           GradeType,
           GradeLevel,
           DependentStatus,
           '-1' AS NumberOfDependents,
           Amount,
           CrunchTime,
           AmcosVersionId
    FROM crunch.Costs_AWO
    UNION ALL
    SELECT PayPlan,
           CMF AS CategoryGroupCode,
           MOS AS CategorySubgroupCode,
           '-1' AS CareerProgramNumber,
           '-1' AS LocationId,
           '-1' AS Strl,
           CostElementId,
           WeaponSystemId,
           GradeType,
           GradeLevel,
           '-1' AS DependentStatus,
           '-1' AS NumberOfDependents,
           Amount,
           CrunchTime,
           AmcosVersionId
    FROM crunch.Costs_NE
    UNION ALL
    SELECT PayPlan,
           CMF AS CategoryGroupCode,
           AOC AS CategorySubgroupCode,
           '-1' AS CareerProgramNumber,
           '-1' AS LocationId,
           '-1' AS Strl,
           CostElementId,
           WeaponSystemId,
           GradeType,
           GradeLevel,
           '-1' AS DependentStatus,
           '-1' AS NumberOfDependents,
           Amount,
           CrunchTime,
           AmcosVersionId
    FROM crunch.Costs_NO
    UNION ALL
    SELECT PayPlan,
           Branch AS CategoryGroupCode,
           WOMOS AS CategorySubgroupCode,
           '-1' AS CareerProgramNumber,
           '-1' AS LocationId,
           '-1' AS Strl,
           CostElementId,
           WeaponSystemId,
           GradeType,
           GradeLevel,
           '-1' AS DependentStatus,
           '-1' AS NumberOfDependents,
           Amount,
           CrunchTime,
           AmcosVersionId
    FROM crunch.Costs_NWO
    UNION ALL
    SELECT PayPlan,
           CMF AS CategoryGroupCode,
           MOS AS CategorySubgroupCode,
           '-1' AS CareerProgramNumber,
           '-1' AS LocationId,
           '-1' AS Strl,
           CostElementId,
           WeaponSystemId,
           GradeType,
           GradeLevel,
           '-1' AS DependentStatus,
           '-1' AS NumberOfDependents,
           Amount,
           CrunchTime,
           AmcosVersionId
    FROM crunch.Costs_RE
    UNION ALL
    SELECT PayPlan,
           CMF AS CategoryGroupCode,
           AOC AS CategorySubgroupCode,
           '-1' AS CareerProgramNumber,
           '-1' AS LocationId,
           '-1' AS Strl,
           CostElementId,
           WeaponSystemId,
           GradeType,
           GradeLevel,
           '-1' AS DependentStatus,
           '-1' AS NumberOfDependents,
           Amount,
           CrunchTime,
           AmcosVersionId
    FROM crunch.Costs_RO
    UNION ALL
    SELECT PayPlan,
           Branch AS CategoryGroupCode,
           WOMOS AS CategorySubgroupCode,
           '-1' AS CareerProgramNumber,
           '-1' AS LocationId,
           '-1' AS Strl,
           CostElementId,
           WeaponSystemId,
           GradeType,
           GradeLevel,
           '-1' AS DependentStatus,
           '-1' AS NumberOfDependents,
           Amount,
           CrunchTime,
           AmcosVersionId
    FROM crunch.Costs_RWO
    UNION ALL
    SELECT PayPlan,
           OccupationalGroupNumber AS CategoryGroupCode,
           OccupationalSeriesNumber AS CategorySubgroupCode,
           CareerProgramNumber,
           LocationId,
           '-1' AS Strl,
           CostElementId,
           '-1' AS WeaponSystemId,
           GradeType,
           GradeLevel,
           '-1' AS DependentStatus,
           NumberOfDependents AS NumberOfDependents,
           Amount,
           CrunchTime,
           AmcosVersionId
    FROM crunch.Costs_G
    UNION ALL
    SELECT PayPlan,
           OccupationalGroupNumber AS CategoryGroupCode,
           OccupationalSeriesNumber AS CategorySubgroupCode,
           '-1',
           LocationId,
           '-1' AS Strl,
           CostElementId,
           '-1' AS WeaponSystemId,
           GradeType,
           PayBand,
           '-1' AS DependentStatus,
           '-1' AS NumberOfDependents,
           Amount,
           CrunchTime,
           AmcosVersionId
    FROM crunch.Costs_CY
    UNION ALL
    SELECT PayPlan,
           OccupationalGroupNumber AS CategoryGroupCode,
           OccupationalSeriesNumber AS CategorySubgroupCode,
           '-1',
           LocationId,
           '-1' AS Strl,
           CostElementId,
           '-1' AS WeaponSystemId,
           GradeType,
           PayBand,
           '-1' AS DependentStatus,
           '-1' AS NumberOfDependents,
           Amount,
           CrunchTime,
           AmcosVersionId
    FROM crunch.Costs_NF
    UNION ALL
    SELECT PayPlan,
           OccupationalGroupNumber AS CategoryGroupCode,
           OccupationalSeriesNumber AS CategorySubgroupCode,
           '-1' AS CareerProgramNumber,
           LocationId AS LocationId,
           '-1' AS Strl,
           CostElementId,
           '-1' AS WeaponSystemId,
           GradeType,
           GradeLevel,
           '-1' AS DependentStatus,
           NumberOfDependents,
           Amount,
           CrunchTime,
           AmcosVersionId
    FROM crunch.Costs_SES
    UNION ALL
    SELECT PayPlan,
           OccupationalGroupNumber AS CategoryGroupCode,
           OccupationalSeriesNumber AS CategorySubgroupCode,
           '-1' AS CareerProgramNumber,
           LocationId,
           '-1' AS Strl,
           CostElementId,
           '-1' AS WeaponSystemId,
           GradeType,
           GradeLevel,
           '-1' AS DependentStatus,
           NumberOfDependents,
           Amount,
           CrunchTime,
           AmcosVersionId
    FROM crunch.Costs_Wage
    UNION ALL
    SELECT PayPlan,
           OccupationalGroupNumber AS CategoryGroupCode,
           OccupationalSeriesNumber AS CategorySubgroupCode,
           CareerProgramNumber,
           LocationId,
           STRL,
           CostElementId,
           '-1' AS WeaponSystemId,
           PayPlan AS GradeType,
           GradeLevel,
           '-1' AS DependentStatus,
           '-1' AS NumberOfDependents,
           Amount,
           CrunchTime,
           AmcosVersionId
    FROM crunch.Costs_GFEBS
) AS AllCosts
    INNER JOIN
    -- the following makes sure were are getting only the nomenclature and elements related to the most recent version of the cost element
    (
        SELECT a.*
        FROM lookup.CostElement AS a
            INNER JOIN
            (
                SELECT CostElementId,
                       MAX(AmcosVersionIdEnd) AS amcosversionidmax
                FROM lookup.CostElement
                GROUP BY CostElementId
            ) AS b
                ON a.CostElementId = b.CostElementId
                   AND a.AmcosVersionIdEnd = b.amcosversionidmax
    ) AS CostElement
        ON CostElement.CostElementId = AllCosts.CostElementId;
GO



GO


