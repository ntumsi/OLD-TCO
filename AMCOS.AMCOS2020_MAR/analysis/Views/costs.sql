CREATE VIEW [analysis].[Costs]
AS
SELECT a.PayPlan,
       a.CategoryGroupCode,
       a.CategoryGroupDescription,
       a.CategorySubgroupCode,
       a.CategorySubgroupDescription,
       a.CareerProgramNumber,
       a.CP_title,
       a.Strl,
       a.LocationId,
       a.Location_name,
       a.DependentStatus,
       a.NumberOfDependents,
       a.CostElementId,
       a.AppropriationGroup,
       a.APPN,
       a.CostElementCategory,
       a.CostElementName,
       a.GradeLevel,
       a.WeaponSystemName,
       a.WeaponSystemId,
       a.Amount,
       a.AmcosVersionId,
       b.SourceSystemCode,
       b.LocationType,
       c.Name
FROM data.CostsWithDescriptions AS a
    LEFT OUTER JOIN warehouse.Location AS b
        ON a.LocationId = b.LocationId
    INNER JOIN
    (
        SELECT a.Name,
               b.CostElementId
        FROM lookup.CostSummary AS a
            INNER JOIN lookup.CostSummaryElement AS b
                ON a.SummaryId = b.SummaryId
                   AND
                   (
                       SELECT MAX(AmcosVersionId) AS Expr1 FROM lookup.AMCOSVersion
                   )
                   BETWEEN a.AmcosVersionIdStart AND a.AmcosVersionIdEnd
                   AND
                   (
                       SELECT MAX(AmcosVersionId) AS Expr1 FROM lookup.AMCOSVersion
                   )
                   BETWEEN b.AmcosVersionIdStart AND b.AmcosVersionIdEnd
    ) AS c
        ON a.CostElementId = c.CostElementId
           AND c.Name IN ( 'Default', 'Detailed' );