

CREATE VIEW [analysis].[PythonUserReleaseBriefRequiredScenarios]
AS
SELECT a.*,
       b.AmcosVersionId,
       CASE
           WHEN b.PayPlan IS NULL THEN
               'Future'
           ELSE
               'Yes'
       END AS 'Included'
FROM
(
    SELECT PayPlan,
           CategorySubgroupCode,
           LocationId,
           STRL,
           GradeLevel,
           DependentStatus,
           NumberOfDependents,
           SUM(Inventory) AS numrequired
    FROM warehouse.UnitPersonnel
    WHERE (
              UnitYear = 'All'
              OR UnitYear = CAST(
                            (
                                SELECT LEFT(MAX(AmcosVersionId), 4)FROM lookup.AMCOSVersion
                            ) AS NVARCHAR(4))
          )
    GROUP BY PayPlan,
             CategorySubgroupCode,
             LocationId,
             STRL,
             GradeLevel,
             DependentStatus,
             NumberOfDependents
) AS a
    LEFT OUTER JOIN
    (
        SELECT DISTINCT
               AmcosVersionId,
               PayPlan,
               GradeLevel,
               LocationId,
               Strl,
               DependentStatus,
               NumberOfDependents,
               CategoryGroupCode,
               CategorySubgroupCode
        FROM data.Costs
        WHERE AmcosVersionId =
        (
            SELECT MAX(AmcosVersionId)FROM lookup.AMCOSVersion
        )
    ) AS b
        ON a.PayPlan = b.PayPlan
           AND a.GradeLevel = b.GradeLevel
           AND a.LocationId = b.LocationId
           AND a.strl = b.strl
           AND a.DependentStatus = b.DependentStatus
           AND a.NumberOfDependents = b.NumberOfDependents
           AND a.CategorySubgroupCode = b.CategorySubgroupCode;