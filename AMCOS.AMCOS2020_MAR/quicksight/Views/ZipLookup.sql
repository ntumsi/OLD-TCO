


CREATE VIEW [quicksight].[ZipLookup]
AS
WITH Vars AS (
    SELECT MAX(AmcosVersionId) AS AmcosVersionId FROM lookup.LocalityPayArea
)
SELECT a.FIPSCode,
       a.ZIPCode,
       a.LocalityPayArea,
       b.LocalityRate,
       a.AmcosVersionId
FROM
(
    SELECT a.FIPSCode,
           a.ZIPCode,
           Vars.AmcosVersionId AS AmcosVersionId,
           CASE
               WHEN b.LocalityCode IS NULL THEN 'RUS'
               ELSE b.LocalityCode
           END AS LocalityCode,
           CASE
               WHEN b.LocalityCode IS NULL THEN 'Rest of US'
               ELSE c.LocalityPayArea
           END AS LocalityPayArea
    FROM lookup.FIPS_ZIP AS a
    CROSS JOIN Vars
    LEFT JOIN xwalk.LocalityPayAreaToFips AS b
        ON a.FIPSCode = b.StateCode + b.CountyCode
    LEFT JOIN lookup.LocalityPayArea AS c 
        ON b.LocalityCode = c.LocalityCode
        AND c.AmcosVersionId = Vars.AmcosVersionId
    WHERE (
              Vars.AmcosVersionId BETWEEN a.AmcosVersionIdStart AND a.AmcosVersionIdEnd
              OR a.AmcosVersionIdStart IS NULL
          )
          AND (
              Vars.AmcosVersionId = b.AmcosVersionId
              OR b.AmcosVersionId IS NULL
          )
) AS a
 JOIN PaySchedule.LocalityPay AS b
    ON a.LocalityCode = b.LocalityCode
    AND a.AmcosVersionId = b.AmcosVersionId;
