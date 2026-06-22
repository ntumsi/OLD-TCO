

CREATE VIEW [analysis].[Outliers_CIV]
AS

/* The purpose of this view is to find outliers through use of the avg_stepYos view
   outliers may be caused by differences in step (CIV) or YOS (MIL) which create noise and thus are best
   filtered out by comparing the avg step/yos against that for the aggregate */
SELECT a.MyPerc
FROM
(
    SELECT PERCENTILE_DISC(.90) WITHIN GROUP(ORDER BY a.Amount) OVER (PARTITION BY a.CostElementName,
                                                                                   a.GradeLevel,
                                                                                   a.LocationId,
                                                                                   a.PayPlan
                                                                     ) AS MyPerc,
           a.[Amount],
           b.Inventory,
           e.Avg_StepYOS,
           e.agg_stepyos,
           e.FillIn,
           a.[PayPlan],
           a.[CategoryGroupCode],
           a.[CategorySubgroupCode],
           f.CategorySubgroupCode AS SpecialPay,
           d.CategorySubgroupDescription,
           a.[GradeLevel],
           a.CostElementName,
           c.DisplayName,
           a.CareerProgramNumber,
           a.LocationId,
           a.Strl,
           a.CostElementId,
           a.WeaponSystemId,
           a.GradeType,
           a.DependentStatus,
           a.CrunchTime,
           a.AmcosVersionId,
           a.AppropriationGroup,
           a.APPN,
           a.CostElementCategory,
           a.ShowOrder
    FROM data.Costs AS a
        LEFT OUTER JOIN data.Inventory AS b
            ON b.AmcosVersionId = a.AmcosVersionId
               AND b.CategorySubgroupCode = a.CategorySubgroupCode
               AND b.GradeLevel = a.GradeLevel
               AND b.LocationId = a.LocationId
               AND b.PayPlan = a.PayPlan
               AND b.Strl = a.Strl
        LEFT OUTER JOIN warehouse.Location AS c
            ON a.LocationId = c.LocationId
        LEFT OUTER JOIN data.CategorySubgroup AS d
            ON a.CategorySubgroupCode = d.CategorySubgroupCode
               AND a.PayPlan = d.PayPlan
        LEFT OUTER JOIN analysis.Avg_StepYos AS e
            ON e.CategorySubgroupCode = a.CategorySubgroupCode
               AND e.GradeLevel = a.GradeLevel
               AND e.LocationId = a.LocationId
               AND e.PayPlan = a.PayPlan
               AND e.Strl = a.Strl
        LEFT OUTER JOIN
        (
            SELECT DISTINCT
                   AmcosVersionId,
                   CategorySubgroupCode,
                   GradeLevel,
                   PayPlan,
                   LocationId
            FROM data.PaySchedules
            WHERE PayPlan IN ( 'GS', 'GL', 'GG' )
        ) AS f
            ON f.AmcosVersionId = a.AmcosVersionId
               AND f.CategorySubgroupCode = a.CategorySubgroupCode
               AND f.GradeLevel = a.GradeLevel
               AND f.LocationId = a.LocationId
    WHERE a.PayPlan NOT IN
          (
              SELECT PayPlan FROM lookup.PayPlanTags WHERE Tag = 'Military'
          )
          AND a.AmcosVersionId = 202001
) AS a
WHERE Amount > a.MyPerc;