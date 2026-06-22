
CREATE VIEW [data].[PaySchedules]
AS
SELECT PayPlan,
       '-1' AS CategoryGroupCode,
       '-1' AS CategorySubgroupCode,
       LocationId AS LocationId,
       Strl AS Strl,
       GradeType,
       PayBand AS GradeLevel,
       1 AS Step, /* pay band minimum */
       -1 AS YOS,
       MinPay AS Rate,
       'Annual' AS RateType,
       AmcosVersionId,
       CAST(PayBand AS NVARCHAR(15)) AS GradeLevelDescription,
       'Min' AS StepDescription,
       '-1' AS WorkRoleCode
FROM PaySchedule.PaySchedule_D_NSeries
UNION ALL
SELECT PayPlan,
       '-1' AS CategoryGroupCode,
       '-1' AS CategorySubgroupCode,
       LocationId AS LocationId,
       Strl AS Strl,
       GradeType,
       PayBand AS GradeLevel,
       10 AS Step, /* pay band maximum */
       -1 AS YOS,
       MaxPay AS Rate,
       'Annual' AS RateType,
       AmcosVersionId,
       CAST(PayBand AS NVARCHAR(15)) AS GradeLevelDescription,
       'Max' AS StepDescription,
       '-1' AS WorkRoleCode
FROM PaySchedule.PaySchedule_D_NSeries
UNION ALL
/* G series pay is just the base pay times the locality payment amount */
SELECT PayPlan,
       CategoryGroupCode,
       CategorySubgroupCode,
       LocationId,
       '-1' AS Strl,
       GradeType,
       GradeLevel,
       Step AS Step,
       -1 AS YOS,
       Rate,
       'Annual' AS RateType,
       AmcosVersionId,
       CAST(GradeLevel AS NVARCHAR(15)) AS GradeLevelDescription,
       CAST(Step AS NVARCHAR(15)) AS StepDescription,
       WorkRoleCode
FROM PaySchedule.PaySchedule_G_Series
UNION
-- bring IN hourly AND overtime pay FOR GL AND GS
SELECT a.PayPlan,
       '-1' AS CategoryGroupCode,
       '-1' AS CategorySubgroupCode,
       b.LocationId,
       '-1' AS Strl,
       a.GradeType,
       a.GradeLevel,
       a.Step AS Step,
       -1 AS YOS,
                                              --make sure to include COLA and Locality in the calc
                                              --Add COLA from PaySchedule.NonforeignAreaCOLA table
       a.Rate * ((b.LocalityRate / 100) + 1), -- * (ISNULL(b.COLA / 100, 0) + 1),
                                              --make a consistent nomen of first letter capital, all other lowercase
       UPPER(LEFT(RateType, 1)) + LOWER(RIGHT(RateType, LEN(RateType) - 1)) AS RateType,
       a.AmcosVersionId,
       CAST(a.GradeLevel AS NVARCHAR(15)) AS GradeLevelDescription,
       CAST(Step AS NVARCHAR(15)) AS StepDescription,
       '-1' AS WorkRoleCode
FROM PaySchedule.PaySchedule_G_Series_raw AS a
    INNER JOIN
    (
        SELECT a.LocationId,
               a.SourceSystemCode,
               a.LocationType,
               a.DisplayName,
               p.LocalityRate,
               p.AmcosVersionId,
               C.Description
        FROM warehouse.Location AS a
            INNER JOIN PaySchedule.LocalityPay AS p
                ON a.SourceSystemCode = p.LocalityCode
            CROSS JOIN lookup.AMCOSVersion AS C
        WHERE C.AmcosVersionId = p.AmcosVersionId
              AND a.LocationType = 'Locality Pay Area'
    ) AS b
        ON a.AmcosVersionId = b.AmcosVersionId
WHERE a.PayPlan IN ( 'GL', 'GS' )
      AND a.RateType <> 'ANNUAL'
UNION ALL
/* GP uses GS base pay (no locality increases, not even rest of us, market pay handles locality based pay adustments) */
SELECT 'GP' AS PayPlan,
       '-1' AS CategoryGroupCode,
       '-1' AS CategorySubgroupCode,
       -1 AS LocationId,
       '-1' AS Strl,
       'GP' AS GradeType,
       GradeLevel,
       Step AS Step,
       -1 AS YOS,
       Rate,
       RateType,
       AmcosVersionId,
       CAST(GradeLevel AS NVARCHAR(15)) AS GradeLevelDescription,
       CAST(Step AS NVARCHAR(15)) AS StepDescription,
       '-1' AS WorkRoleCode
FROM PaySchedule.PaySchedule_G_Series_raw
WHERE PayPlan = 'GS'
      AND RateType = 'Annual'
      AND AmcosVersionId >= 201101 --based on research with Marsha (COR) GP began in 2011 for the DoD so don't allow anything before that in
UNION ALL
SELECT PayPlan,
       '-1' AS CategoryGroupCode,
       '-1' AS CategorySubgroupCode,
       -1 AS LocationId,
       '-1' AS Strl,
       GradeType,
       GradeLevel,
       -1 AS Step,
       YOS AS YOS,
       Rate,
       RateType,
       AmcosVersionId,
       CAST(GradeLevel AS NVARCHAR(15)) AS GradeLevelDescription,
       'Not Applicable' AS StepDescription,
       '-1' AS WorkRoleCode
FROM PaySchedule.PaySchedule_Military
--annualize active military pay
UNION ALL
SELECT PayPlan,
       '-1' AS CategoryGroupCode,
       '-1' AS CategorySubgroupCode,
       -1 AS LocationId,
       '-1' AS Strl,
       GradeType,
       GradeLevel,
       -1 AS Step,
       YOS AS YOS,
       Rate * 12 AS rate,
       'Annual' AS RateType,
       AmcosVersionId,
       CAST(GradeLevel AS NVARCHAR(15)) AS GradeLevelDescription,
       'Not Applicable' AS StepDescription,
       '-1' AS WorkRoleCode
FROM PaySchedule.PaySchedule_Military
WHERE RateType = 'Monthly'
      AND PayPlan IN ( 'AO', 'AWO', 'AE' )
UNION
-- since we do not crunch military pay we need to calculate this on the fly
--do not change this without also making the same change in crunch.costofbasepay
SELECT a.PayPlan,
       '-1' AS CategoryGroupCode,
       '-1' AS CategorySubgroupCode,
       -1 AS LocationId,
       '-1' AS Strl,
       a.GradeType,
       a.GradeLevel,
       -1 AS Step,
       a.YOS AS YOS,
       --(a.Pay * @MonthsInAyear) + (b.Rate * @activedays / @DaysInAMonth) AS rate,
       (a.Rate * 12) + (b.Rate * c.paramValue / 30) AS rate,
       'Annualized' AS RateType,
       a.AmcosVersionId,
       CAST(a.GradeLevel AS NVARCHAR(15)) AS GradeLevelDescription,
       'Not Applicable' AS StepDescription,
       '-1' AS WorkRoleCode
FROM PaySchedule.PaySchedule_Military AS a
    INNER JOIN PaySchedule.PaySchedule_Military AS b
        ON a.GradeType = b.GradeType
           AND a.GradeLevel = b.GradeLevel
           AND a.YOS = b.YOS
           AND b.AmcosVersionId = a.AmcosVersionId
    INNER JOIN
    (
        SELECT paramValue,
               AmcosVersionId
        FROM dataload.SingleValues
        WHERE paramName = 'activedays'
              AND PayPlan = 'AA'
    ) AS c
        ON c.AmcosVersionId = a.AmcosVersionId
WHERE a.PayPlan IN ( 'NO', 'NE', 'NWO', 'RE', 'RO', 'RWO' )
      AND a.RateType = '4 Drills'
      AND b.RateType = 'Monthly'
      AND b.PayPlan IN ( 'AO', 'AWO', 'AE' )





--removed 5/25/2022 so that the 'new' SES Raw payschedule could be used instead
--UNION ALL
--SELECT PayPlan,
--       LEFT(OccupationalSeriesNumber, 2) + '00' AS CategoryGroupCode,
--       OccupationalSeriesNumber AS CategorySubgroupCode,
--       -1 AS LocationId,
--       '-1' AS Strl,
--       GradeType,
--       GradeLevel,
--       Step AS Step,
--       -1 AS YOS,
--       Rate,
--       RateType,
--       AmcosVersionId
--	     ,CASE WHEN GradeLevel=1 THEN 'Min' WHEN gradelevel=2 THEN 'Avg' WHEN gradelevel=3 THEN 'Max' ELSE null END AS GradeLevelDescription
--	   ,'Not Applicable' AS StepDescription
--FROM PaySchedule.PaySchedule_SES

UNION ALL
SELECT PayPlan,
       '-1' AS CategoryGroupCode,
       '-1' AS CategorySubgroupCode,
       LocationId,
       '-1' AS Strl,
       GradeType,
       GradeLevel,
       Step AS Step,
       -1 AS YOS,
       Rate,
       RateType,
       AmcosVersionId,
       CAST(GradeLevel AS NVARCHAR(15)) AS GradeLevelDescription,
       CAST(Step AS NVARCHAR(15)) AS StepDescription,
       '-1' AS WorkRoleCode
FROM PaySchedule.PaySchedule_Wage
WHERE RateType = 'Hourly'
UNION
SELECT a.PayPlan,
       '-1' AS CategoryGroupCode,
       '-1' AS CategorySubgroupCode,
       a.LocationId,
       '-1' AS Strl,
       a.GradeType,
       a.GradeLevel,
       Step AS Step,
       -1 AS YOS,
       --if we don't have data for a given year just assume 2087 which was the value when we started keeping records
       a.Rate * ISNULL(b.paramValue, 2087),
       'Annual' AS RateType,
       a.AmcosVersionId,
       CAST(a.GradeLevel AS NVARCHAR(15)) AS GradeLevelDescription,
       CAST(a.Step AS NVARCHAR(15)) AS StepDescription,
       '-1' AS WorkRoleCode
FROM PaySchedule.PaySchedule_Wage AS a
    LEFT OUTER JOIN
    (
        SELECT *
        FROM dataload.SingleValues
        WHERE paramName = 'annualpaidhours'
              AND PayPlan = 'GP'
    ) AS b
        ON b.AmcosVersionId = a.AmcosVersionId
WHERE a.RateType = 'Hourly'
UNION ALL
--CY pay plan
SELECT PayPlan,
       '-1' AS CategoryGroupCode,
       '-1' AS CategorySubgroupCode,
       LocationId,
       '-1' AS Strl,
       GradeType,
       PayBand,
       1 AS Step, /* pay band minimum */
       -1 AS YOS,
       MinPay AS Rate,
       'Annual' AS RateType,
       AmcosVersionId,
       CAST(PayBand AS NVARCHAR(15)) AS GradeLevelDescription,
       'Min' AS StepDescription,
       '-1' AS WorkRoleCode
FROM PaySchedule.PaySchedule_CY
UNION ALL
SELECT PayPlan,
       '-1' AS CategoryGroupCode,
       '-1' AS CategorySubgroupCode,
       LocationId,
       '-1' AS Strl,
       GradeType,
       PayBand,
       10 AS Step, /* pay band maximum */
       -1 AS YOS,
       MaxPay AS Rate,
       'Annual' AS RateType,
       AmcosVersionId,
       CAST(PayBand AS NVARCHAR(15)) AS GradeLevelDescription,
       'Max' AS StepDescription,
       '-1' AS WorkRoleCode
FROM PaySchedule.PaySchedule_CY
UNION ALL
--NF pay plan
SELECT PayPlan,
       '-1' AS CategoryGroupCode,
       '-1' AS CategorySubgroupCode,
       LocationId,
       '-1' AS Strl,
       GradeType,
       PayBand,
       1 AS Step, /* pay band minimum */
       -1 AS YOS,
       MinPay AS Rate,
       'Annual' AS RateType,
       AmcosVersionId,
       CAST(PayBand AS NVARCHAR(15)) AS GradeLevelDescription,
       'Min' AS StepDescription,
       '-1' AS WorkRoleCode
FROM crunch.NfPayProcessed
UNION ALL
SELECT PayPlan,
       '-1' AS CategoryGroupCode,
       '-1' AS CategorySubgroupCode,
       LocationId,
       '-1' AS Strl,
       GradeType,
       PayBand,
       10 AS Step, /* pay band maximum */
       -1 AS YOS,
       MaxPay AS Rate,
       'Annual' AS RateType,
       AmcosVersionId,
       CAST(PayBand AS NVARCHAR(15)) AS GradeLevelDescription,
       'Max' AS StepDescription,
       '-1' AS WorkRoleCode
FROM crunch.NfPayProcessed
--########

UNION ALL
SELECT b.PayPlan,
       '-1' AS CategoryGroupCode,
       '-1' AS CategorySubgroupCode,
       -1 AS LocationId,
       '-1' AS Strl,
       b.PayPlan,
       0,         --grade level not used
       1 AS Step, /* pay band maximum */
       -1 AS YOS,
       a.MaxPay AS Rate,
       'Annual' AS RateType,
       a.AmcosVersionId,
       CAST(0 AS NVARCHAR(15)) AS GradeLevelDescription,
       'Max' AS StepDescription,
       '-1' AS WorkRoleCode
FROM PaySchedule.OpmSesRaw AS a
    --these pay plans use the same pasyschedule as SES
    CROSS JOIN
    (SELECT 'IP' AS PayPlan UNION SELECT 'IE') AS b
UNION ALL
--########
--EF and EE
-- GS15 Step 10 is the maximum
SELECT B.PayPlan,
       '-1' AS CategoryGroupCode,
       '-1' AS CategorySubgroupCode,
       LocationId AS LocationId,
       '-1' AS Strl,
       B.PayPlan,
       0, --grade level not used
       10 AS Step,
       -1 AS YOS,
       Rate AS Rate,
       'Annual' AS RateType,
       a.AmcosVersionId,
       CAST(0 AS NVARCHAR(15)) AS GradeLevelDescription,
       'Max' AS StepDescription,
       '-1' AS WorkRoleCode
FROM PaySchedule.PaySchedule_G_Series AS a
    CROSS JOIN
    (SELECT 'EF' AS PayPlan UNION SELECT 'EE') AS B
    INNER JOIN
    (
        SELECT CONCAT(YEAR(OpmStartDate), '01') AS AmcosVersionIdStart,
               PayPlan
        FROM lookup.PayPlan
    ) AS c
        ON B.PayPlan = c.PayPlan
           AND a.AmcosVersionId >= c.AmcosVersionIdStart
WHERE a.PayPlan = 'GS'
      AND CategoryGroupCode = '-1'
      AND CategorySubgroupCode = '-1'
      AND LocationId <> -1
      AND a.GradeLevel = 15
      AND Step = 10
UNION ALL
--#### EX
SELECT PayPlan,
       '-1' AS CategoryGroupCode,
       '-1' AS CategorySubgroupCode,
       -1 AS LocationId,
       '-1' AS Strl,
       PayPlan,
       GradeLevel, --grade level not used
       -1 AS Step,
       -1 AS YOS,
       Rate AS Rate,
       RateType,
       AmcosVersionId,
       GradeLevelDescription AS GradeLevelDescription,
       'Not Applicable' AS StepDescription,
       '-1' AS WorkRoleCode
FROM crunch.OpmExProcessed
--#### CA
UNION ALL
SELECT PayPlan,
       '-1' AS CategoryGroupCode,
       '-1' AS CategorySubgroupCode,
       LocationId,
       '-1' AS Strl,
       PayPlan,
       Gradelevel, --grade level not used
       -1 AS Step,
       -1 AS YOS,
       Rate AS Rate,
       RateType,
       AmcosVersionId,
       GradeLevelDescription AS GradeLevelDescription,
       'Not Applicable' AS StepDescription,
       '-1' AS WorkRoleCode
FROM crunch.OpmCaProcessed
--#### IG
UNION ALL
SELECT PayPlan,
       '-1' AS CategoryGroupCode,
       '-1' AS CategorySubgroupCode,
       -1 AS LocationId,
       '-1' AS Strl,
       PayPlan,
       GradeLevel, --grade level not used
       -1 AS Step,
       -1 AS YOS,
       Rate AS Rate,
       RateType,
       AmcosVersionId,
       CAST(0 AS NVARCHAR(15)) AS GradeLevelDescription,
       'Not Applicable' AS StepDescription,
       '-1' AS WorkRoleCode
FROM crunch.OpmIGProcessed
UNION ALL
--### ST SL IE IP all use the EX Level II as their max, as of 5/25/2022 there is no min set in policy although one maybe could infer SES Min is their min but that is far from being official
SELECT b.PayPlan,
       '-1' AS CategoryGroupCode,
       '-1' AS CategorySubgroupCode,
       -1 AS LocationId,
       '-1' AS Strl,
       b.PayPlan,
       0, --grade level not used
       -1 AS Step,
       -1 AS YOS,
       Rate AS Rate,
       a.RateType,
       a.AmcosVersionId,
       CAST(0 AS NVARCHAR(15)) AS GradeLevelDescription,
       'Max' AS StepDescription,
       '-1' AS WorkRoleCode
FROM crunch.OpmExProcessed AS a
    CROSS JOIN
    (
        SELECT 'ST' AS PayPlan
        UNION
        SELECT 'SL'
        UNION
        SELECT 'IE'
        UNION
        SELECT 'IP'
    ) AS b
    INNER JOIN
    (
        SELECT CONCAT(YEAR(OpmStartDate), '01') AS AmcosVersionIdStart,
               PayPlan
        FROM lookup.PayPlan
    ) AS c
        ON b.PayPlan = c.PayPlan
           AND a.AmcosVersionId >= c.AmcosVersionIdStart
WHERE [GradeLevelDescription] = 'Level II'
UNION ALL
--### SES and IP uses SES - MIN
SELECT b.PayPlan,
       '-1' AS CategoryGroupCode,
       '-1' AS CategorySubgroupCode,
       -1 AS LocationId,
       '-1' AS Strl,
       b.PayPlan,
       0, --grade level not used
       -1 AS Step,
       -1 AS YOS,
       a.MinPay AS Rate,
       a.RateType,
       a.AmcosVersionId,
       CAST(0 AS NVARCHAR(15)) AS GradeLevelDescription,
       'Min' AS StepDescription,
       '-1' AS WorkRoleCode
FROM PaySchedule.OpmSesRaw AS a
    CROSS JOIN
    (SELECT 'IP' AS PayPlan UNION SELECT 'SES') AS b
    INNER JOIN
    (
        SELECT CONCAT(YEAR(OpmStartDate), '01') AS AmcosVersionIdStart,
               PayPlan
        FROM lookup.PayPlan
    ) AS c
        ON b.PayPlan = c.PayPlan
           AND a.AmcosVersionId >= c.AmcosVersionIdStart
UNION ALL
--### SES and IP uses SES - MAX
SELECT b.PayPlan,
       '-1' AS CategoryGroupCode,
       '-1' AS CategorySubgroupCode,
       -1 AS LocationId,
       '-1' AS Strl,
       b.PayPlan,
       0, --grade level not used
       -1 AS Step,
       -1 AS YOS,
       a.MaxPay AS Rate,
       a.RateType,
       a.AmcosVersionId,
       CAST(0 AS NVARCHAR(15)) AS GradeLevelDescription,
       'Max' AS StepDescription,
       '-1' AS WorkRoleCode
FROM PaySchedule.OpmSesRaw AS a
    CROSS JOIN
    (SELECT 'IP' AS PayPlan UNION SELECT 'SES') AS b
    INNER JOIN
    (
        SELECT CONCAT(YEAR(OpmStartDate), '01') AS AmcosVersionIdStart,
               PayPlan
        FROM lookup.PayPlan
    ) AS c
        ON b.PayPlan = c.PayPlan
           AND a.AmcosVersionId >= c.AmcosVersionIdStart;;