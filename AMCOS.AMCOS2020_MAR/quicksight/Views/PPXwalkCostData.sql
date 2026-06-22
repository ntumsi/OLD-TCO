
CREATE VIEW [quicksight].[PPXwalkCostData]
AS
SELECT PayPlan,
       a.CategoryGroupCode,
       a.CategoryGroupDescription,
       CategorySubgroupCode,
       CategorySubgroupDescription,
       CategorySubgroupCode + ' - ' + CategorySubgroupDescription AS displaySubGroup,
       LocationId,
       Location_name,
       DependentStatus,
       NumberOfDependents,
       CAST(GradeLevel AS NVARCHAR(5)) AS GradeLevel,
       CASE
           WHEN Strl = '-1' THEN
               'Not Applicable'
           ELSE
               Strl
       END AS Strl,
       PayType,
       SUM(Amount) AS Amount
FROM
(
    --for active military this needs to happen in two parts
    --1) duplicate the location non-specific costs (-1) against all applicable locationids 
    --this will make sure complete costs for all location scenarios are calculated correctly
    --2) append/union our costs with a location
    --##### 1 location non-specific costs with a location specific ID added

    SELECT a.PayPlan,
           a.CategoryGroupCode,
           a.CategoryGroupDescription,
           a.CategorySubgroupCode,
           a.CategorySubgroupDescription,
           b.LocationId,
           b.Location_name,
           a.DependentStatus,
           a.NumberOfDependents,
           CAST(a.GradeLevel AS NVARCHAR(5)) AS GradeLevel,
           a.Strl,
           --a.costelementname,
           CASE
               WHEN a.CostElementName LIKE '%base pay%' THEN
                   'Base Pay'
               WHEN a.CostElementName = 'Avg Cost of Basic Allowance for Housing' THEN
                   'BAH'
               WHEN a.CostElementName = 'Avg Cost of Living Allowance (COLA)' THEN
                   'COLA'
               ELSE
                   'Other Pay'
           END AS PayType,
           SUM(a.Amount) AS Amount
    FROM data.CostsWithDescriptions AS a
        CROSS JOIN
        (
            SELECT DISTINCT
                   LocationId,
                   Location_name
            FROM data.CostsWithDescriptions
            WHERE AmcosVersionId =
            (
                SELECT MAX(AmcosVersionId)FROM lookup.AMCOSVersion
            )
                  AND locationid <> -1
                  AND PayPlan IN
                      (
                          SELECT PayPlan FROM lookup.PayPlanTags WHERE Tag = 'Military'
                      )
                  AND DependentStatus = 'average' --this leaves us with only U.S. locations for now 

        ) AS b
    WHERE a.AmcosVersionId =
    (
        SELECT MAX(AmcosVersionId)FROM lookup.AMCOSVersion
    )
          AND a.CostElementId IN
              (
                  SELECT b.CostElementId
                  FROM lookup.CostSummary AS a
                      INNER JOIN lookup.CostSummaryElement AS b
                          ON b.SummaryId = a.SummaryId
                  WHERE
                  (
                      SELECT MAX(AmcosVersionId)FROM lookup.AMCOSVersion
                  )
                  BETWEEN a.AmcosVersionIdStart AND a.AmcosVersionIdEnd
                  AND
                  (
                      SELECT MAX(AmcosVersionId)FROM lookup.AMCOSVersion
                  )
                  BETWEEN b.AmcosVersionIdStart AND b.AmcosVersionIdEnd
                  AND a.Name = 'Default'
              )
          AND a.CareerProgramNumber = -1
          AND a.CategorySubgroupCode <> '-1'
          AND (a.PayPlan IN
               (
                   SELECT PayPlan FROM lookup.PayPlanTags WHERE Tag = 'Military'
               )
              )
          AND a.LocationId = -1
          --the below clause makes sure we aren't bringing in location avgs for costs we'll use the location specific values for next
          AND a.CostElementName NOT IN ( 'Avg Cost of Overseas Station Allowance',
                                         'Avg Cost of Basic Allowance for Housing',
                                         'Avg Cost of Living Allowance (COLA)'
                                       )
    --AND b.LocationId=118 AND a.CategorySubgroupCode='11b' AND GradeLevel=4
    GROUP BY a.PayPlan,
             a.CategoryGroupCode,
             a.CategoryGroupDescription,
             a.CategorySubgroupCode,
             a.CategorySubgroupDescription,
             b.locationid,
             b.location_name,
             a.DependentStatus,
             a.NumberOfDependents,
             a.GradeLevel,
             a.CostElementName,
             a.Strl
    UNION
    --union in the location specific costs
    SELECT a.PayPlan,
           a.CategoryGroupCode,
           a.CategoryGroupDescription,
           a.CategorySubgroupCode,
           a.CategorySubgroupDescription,
           a.LocationId,
           a.Location_name,
           a.DependentStatus,
           a.NumberOfDependents,
           CAST(a.GradeLevel AS NVARCHAR(5)) AS GradeLevel,
           a.Strl,
           --a.costelementname,
           CASE
               WHEN a.CostElementName LIKE '%base pay%' THEN
                   'Base Pay'
               WHEN a.CostElementName = 'Avg Cost of Basic Allowance for Housing' THEN
                   'BAH'
               WHEN a.CostElementName = 'Avg Cost of Living Allowance (COLA)' THEN
                   'COLA'
               ELSE
                   'Other Pay'
           END AS PayType,
           SUM(a.Amount) AS Amount
    FROM data.CostsWithDescriptions AS a
    WHERE a.AmcosVersionId =
    (
        SELECT MAX(AmcosVersionId)FROM lookup.AMCOSVersion
    )
          AND a.CostElementId IN
              (
                  SELECT b.CostElementId
                  FROM lookup.CostSummary AS a
                      INNER JOIN lookup.CostSummaryElement AS b
                          ON b.SummaryId = a.SummaryId
                  WHERE
                  (
                      SELECT MAX(AmcosVersionId)FROM lookup.AMCOSVersion
                  )
                  BETWEEN a.AmcosVersionIdStart AND a.AmcosVersionIdEnd
                  AND
                  (
                      SELECT MAX(AmcosVersionId)FROM lookup.AMCOSVersion
                  )
                  BETWEEN b.AmcosVersionIdStart AND b.AmcosVersionIdEnd
                  AND a.Name = 'Default'
              )
          AND a.CareerProgramNumber = -1
          AND a.CategorySubgroupCode <> '-1'
          AND
          (
              a.PayPlan IN
              (
                  SELECT PayPlan FROM lookup.PayPlanTags WHERE Tag = 'Military'
              )
              OR a.PayPlan = 'SES'
          )
          AND a.LocationId <> -1
          --the below clause makes sure we aren't bringing in location avgs for costs we'll use the location specific values for next
          AND CostElementName IN ( 'Avg Cost of Basic Allowance for Housing', 'Avg Cost of Living Allowance (COLA)' )
          AND a.DependentStatus = 'average' --only pick one status to keep this simple so we'll use avg
                                            --AND LocationId=118 AND a.CategorySubgroupCode='11b' AND GradeLevel=4
    GROUP BY a.PayPlan,
             a.CategoryGroupCode,
             a.CategoryGroupDescription,
             a.CategorySubgroupCode,
             a.CategorySubgroupDescription,
             a.LocationId,
             a.Location_name,
             a.DependentStatus,
             a.NumberOfDependents,
             a.GradeLevel,
             a.CostElementName,
             a.Strl
    UNION
    --all other pay plans should use 
    SELECT PayPlan,
           CategoryGroupCode,
           CategoryGroupDescription,
           CategorySubgroupCode,
           CategorySubgroupDescription,
           LocationId,
           Location_name,
           DependentStatus,
           NumberOfDependents,
           GradeLevel,
           Strl,
           CASE
               WHEN CostElementName LIKE '%base pay%' THEN
                   'Base Pay'
               WHEN CostElementName = 'Civ Non-Foreign COLA (Cost of Living Allowance) Pay' THEN
                   'Non-Foreign COLA'
               ELSE
                   'Other Pay'
           END AS PayType,
           SUM(Amount) AS Amount
    FROM data.CostsWithDescriptions
    WHERE AmcosVersionId =
    (
        SELECT MAX(AmcosVersionId)FROM lookup.AMCOSVersion
    )
          AND CostElementId IN
              (
                  SELECT b.CostElementId
                  FROM lookup.CostSummary AS a
                      INNER JOIN lookup.CostSummaryElement AS b
                          ON b.SummaryId = a.SummaryId
                  WHERE
                  (
                      SELECT MAX(AmcosVersionId)FROM lookup.AMCOSVersion
                  )
                  BETWEEN a.AmcosVersionIdStart AND a.AmcosVersionIdEnd
                  AND
                  (
                      SELECT MAX(AmcosVersionId)FROM lookup.AMCOSVersion
                  )
                  BETWEEN b.AmcosVersionIdStart AND b.AmcosVersionIdEnd
                  AND a.Name = 'Default'
              )
          AND CareerProgramNumber = -1
          AND CategorySubgroupCode <> '-1'
          AND
          (
              (
                  PayPlan NOT IN
                  (
                      SELECT PayPlan FROM lookup.PayPlanTags WHERE Tag = 'Military'
                  )
                  AND PayPlan <> 'SES'
                  AND locationid <> -1
              )
              OR (PayPlan = 'SES')
          )
    GROUP BY PayPlan,
             CategoryGroupCode,
             CategoryGroupDescription,
             CategorySubgroupCode,
             CategorySubgroupDescription,
             LocationId,
             Location_name,
             DependentStatus,
             NumberOfDependents,
             GradeLevel,
             CostElementName,
             Strl
) AS a
GROUP BY PayPlan,
         a.CategoryGroupCode,
         a.CategoryGroupDescription,
         CategorySubgroupCode,
         CategorySubgroupDescription,
         locationid,
         location_name,
         DependentStatus,
         NumberOfDependents,
         GradeLevel,
         Strl,
         PayType
UNION

--CCE data
-- -1 is know reported annual data, 999999 is above the reported maximum so we exclude those too since we don't konw what they are

SELECT a.PayPlan,
       ISNULL(b.OccupationCode, a.SOC),
       ISNULL(b.OccupationTitle, a.OccupationTitle),
       a.SOC,
       a.OccupationTitle,
       a.displaysubgroup,
       LocationId,
       DisplayName,
       a.DependentStatus,
       a.NumberOfDependents,
       a.GradeLevel,
       a.Strl,
       'Base Pay' AS PayType,
       a.Amount
FROM
(
    SELECT 'CCE' AS PayPlan,
           a.SOC,
           b.OccupationTitle,
           a.SOC + ' - ' + b.OccupationTitle AS displaysubgroup,
           c.LocationId,
           c.DisplayName,
           '-1' AS DependentStatus,
           -1 AS NumberOfDependents,
           '10th' AS GradeLevel,
           'Not Applicable' AS Strl,
           'base pay' AS PayType,
           a.A_PCT10 AS Amount
    FROM BLS_OES.OccupationalEmploymentStatisticsMetro AS a
        INNER JOIN lookup.SOCStructure AS b
            ON a.SOC = b.OccupationCode
        INNER JOIN warehouse.Location AS c
            ON c.SourceSystemCode = a.MSACode
    WHERE
    (
        SELECT MAX(AmcosVersionId)FROM lookup.AMCOSVersion
    )   = a.AmcosVersionId
    AND
    (
        SELECT MAX(AmcosVersionId)FROM lookup.AMCOSVersion
    )
    BETWEEN b.AmcosVersionIdStart AND b.AmcosVersionIdEnd
    AND a.A_PCT10 NOT IN ( -1, 9999999 )
    AND c.LocationType = 'MSA'
    UNION
    SELECT 'CCE' AS PayPlan,
           a.SOC,
           b.OccupationTitle,
           a.SOC + ' - ' + b.OccupationTitle AS displaysubgroup,
           c.LocationId,
           c.DisplayName,
           '-1' AS DependentStatus,
           -1 AS NumberOfDependents,
           '25th' AS GradeLevel,
           'Not Applicable' AS Strl,
           'base pay' AS PayType,
           a.A_PCT25 AS Amount
    FROM BLS_OES.OccupationalEmploymentStatisticsMetro AS a
        INNER JOIN lookup.SOCStructure AS b
            ON a.SOC = b.OccupationCode
        INNER JOIN warehouse.Location AS c
            ON c.SourceSystemCode = a.MSACode
    WHERE
    (
        SELECT MAX(AmcosVersionId)FROM lookup.AMCOSVersion
    )   = a.AmcosVersionId
    AND
    (
        SELECT MAX(AmcosVersionId)FROM lookup.AMCOSVersion
    )
    BETWEEN b.AmcosVersionIdStart AND b.AmcosVersionIdEnd
    AND a.A_PCT25 NOT IN ( -1, 9999999 )
    AND c.LocationType = 'MSA'
    UNION
    SELECT 'CCE' AS PayPlan,
           a.SOC,
           b.OccupationTitle,
           a.SOC + ' - ' + b.OccupationTitle AS displaysubgroup,
           c.LocationId,
           c.DisplayName,
           '-1' AS DependentStatus,
           -1 AS NumberOfDependents,
           '50th' AS GradeLevel,
           'Not Applicable' AS Strl,
           'base pay' AS PayType,
           a.A_MEDIAN AS Amount
    FROM BLS_OES.OccupationalEmploymentStatisticsMetro AS a
        INNER JOIN lookup.SOCStructure AS b
            ON a.SOC = b.OccupationCode
        INNER JOIN warehouse.Location AS c
            ON c.SourceSystemCode = a.MSACode
    WHERE
    (
        SELECT MAX(AmcosVersionId)FROM lookup.AMCOSVersion
    )   = a.AmcosVersionId
    AND
    (
        SELECT MAX(AmcosVersionId)FROM lookup.AMCOSVersion
    )
    BETWEEN b.AmcosVersionIdStart AND b.AmcosVersionIdEnd
    AND a.A_MEDIAN NOT IN ( -1, 9999999 )
    AND c.LocationType = 'MSA'
    UNION
    SELECT 'CCE' AS PayPlan,
           a.SOC,
           b.OccupationTitle,
           a.SOC + ' - ' + b.OccupationTitle AS displaysubgroup,
           c.LocationId,
           c.DisplayName,
           '-1' AS DependentStatus,
           -1 AS NumberOfDependents,
           '75th' AS GradeLevel,
           'Not Applicable' AS Strl,
           'base pay' AS PayType,
           a.A_PCT75 AS Amount
    FROM BLS_OES.OccupationalEmploymentStatisticsMetro AS a
        INNER JOIN lookup.SOCStructure AS b
            ON a.SOC = b.OccupationCode
        INNER JOIN warehouse.Location AS c
            ON c.SourceSystemCode = a.MSACode
    WHERE
    (
        SELECT MAX(AmcosVersionId)FROM lookup.AMCOSVersion
    )   = a.AmcosVersionId
    AND
    (
        SELECT MAX(AmcosVersionId)FROM lookup.AMCOSVersion
    )
    BETWEEN b.AmcosVersionIdStart AND b.AmcosVersionIdEnd
    AND a.A_PCT75 NOT IN ( -1, 9999999 )
    AND c.LocationType = 'MSA'
    UNION
    SELECT 'CCE' AS PayPlan,
           a.SOC,
           b.OccupationTitle,
           a.SOC + ' - ' + b.OccupationTitle AS displaysubgroup,
           c.LocationId,
           c.DisplayName,
           '-1' AS DependentStatus,
           -1 AS NumberOfDependents,
           '90th' AS GradeLevel,
           'Not Applicable' AS Strl,
           'base pay' AS PayType,
           a.A_PCT90 AS Amount
    FROM BLS_OES.OccupationalEmploymentStatisticsMetro AS a
        INNER JOIN lookup.SOCStructure AS b
            ON a.SOC = b.OccupationCode
        INNER JOIN warehouse.Location AS c
            ON c.SourceSystemCode = a.MSACode
    WHERE
    (
        SELECT MAX(AmcosVersionId)FROM lookup.AMCOSVersion
    )   = a.AmcosVersionId
    AND
    (
        SELECT MAX(AmcosVersionId)FROM lookup.AMCOSVersion
    )
    BETWEEN b.AmcosVersionIdStart AND b.AmcosVersionIdEnd
    AND a.A_PCT90 NOT IN ( -1, 9999999 )
    AND c.LocationType = 'MSA'
) AS a
    LEFT OUTER JOIN lookup.SOCStructure AS b
        ON LEFT(a.SOC, 5) + '00' = b.OccupationCode
WHERE
(
    SELECT MAX(AmcosVersionId)FROM lookup.AMCOSVersion
)
BETWEEN b.AmcosVersionIdStart AND b.AmcosVersionIdEnd;