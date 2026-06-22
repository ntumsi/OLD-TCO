

CREATE VIEW [xwalk].[PPXwalkGradeLevel]
AS
SELECT GS_SES_Payplan,
       CAST(GS_SES_Gradelevel AS NVARCHAR(2)) AS GS_SES_Gradelevel,
       ToPayPlan,
       ToGradeLevelPayBand,
       Strl
FROM
(
    SELECT DISTINCT
           b.PayPlan AS GS_SES_Payplan,
           b.GradeLevel AS GS_SES_Gradelevel,
           a.TargetPayPlan AS ToPayPlan,
           a.TargetGradeLevel AS ToGradeLevelPayBand,
           CAST('Not Applicable' AS NVARCHAR(20)) AS Strl
    FROM xwalk.GradeLevel AS a
        INNER JOIN
        (
            SELECT DISTINCT
                   PayPlan,
                   GradeLevel
            FROM data.Costs
            WHERE PayPlan IN ( 'GS', 'SES' )
        ) AS b
            ON a.BasePayPlan = b.PayPlan
               AND b.GradeLevel
               BETWEEN a.BaseGradeLevel_low AND a.BaseGradeLevel_high
    WHERE
    (
        SELECT MAX(AmcosVersionId)FROM lookup.AMCOSVersion
    )
    BETWEEN a.AmcosVersionIdStart AND a.AmcosVersionIdEnd
    UNION
    --CY
    SELECT b.FromPayPlan,
           b.FromGradeLevel,
           a.PayPlan,
           a.PayBand,
           'Not Applicable' AS STRL
    FROM PaySchedule.PaySchedule_CY_Xwalk AS a
        INNER JOIN
        (
            SELECT DISTINCT
                   PayPlan AS FromPayPlan,
                   GradeLevel AS FromGradeLevel
            FROM data.Costs
            WHERE PayPlan IN ( 'GS' )
        ) AS b
            ON b.FromGradeLevel
               BETWEEN a.Min_GS_GL AND a.Max_GS_GL
    WHERE
    (
        SELECT MAX(AmcosVersionId)FROM lookup.AMCOSVersion
    )
    BETWEEN a.AmcosVersionIdStart AND a.AmcosVersionIdEnd
    UNION
    --D series
    SELECT b.FromPayPlan,
           b.FromGradeLevel,
           a.targetPayPlan,
           a.targetgradelevel,
           a.targetstrl
    FROM
    (
        SELECT CASE
                   WHEN a.Min_GS_GL = 'SES'
                        AND a.Max_GS_GL = 'SES' THEN
                       'SES'
                   ELSE
                       'GS'
               END AS PayPlan,
               CASE
                   WHEN a.Min_GS_GL = 'SES' THEN
                       '1'
                   ELSE
                       a.Min_GS_GL
               END AS GS_SES_BaseGradeLevel_low,
               CASE
                   WHEN a.Max_GS_GL = 'SES' THEN
                       '3'
                   ELSE
                       a.Max_GS_GL
               END AS GS_SES_BaseGradeLevel_high,
               PayPlan AS targetPayPlan,
               PayBand AS targetgradelevel,
               Strl AS targetstrl
        FROM PaySchedule.PaySchedule_DSeries_Xwalk AS a
        WHERE
        (
            SELECT MAX(AmcosVersionId)FROM lookup.AMCOSVersion
        )
        BETWEEN AmcosVersionIdStart AND AmcosVersionIdEnd
    ) AS a
        INNER JOIN
        (
            SELECT DISTINCT
                   PayPlan AS FromPayPlan,
                   GradeLevel AS FromGradeLevel
            FROM data.Costs
            WHERE PayPlan IN ( 'GS', 'SES' )
        ) AS b
            ON a.PayPlan = b.FromPayPlan
               AND b.FromGradeLevel
               BETWEEN a.GS_SES_BaseGradeLevel_low AND a.GS_SES_BaseGradeLevel_high
    UNION
    --n series
    SELECT b.FromPayPlan,
           b.FromGradeLevel,
           a.targetPayPlan,
           a.targetgradelevel,
           'Not Applicable' AS STRL
    FROM
    (
        SELECT CASE
                   WHEN a.Min_GS_GL = 'SES'
                        AND a.Max_GS_GL = 'SES' THEN
                       'SES'
                   ELSE
                       'GS'
               END AS PayPlan,
               CASE
                   WHEN a.Min_GS_GL = 'SES' THEN
                       '1'
                   ELSE
                       a.Min_GS_GL
               END AS GS_SES_BaseGradeLevel_low,
               CASE
                   WHEN a.Max_GS_GL = 'SES' THEN
                       '3'
                   ELSE
                       a.Max_GS_GL
               END AS GS_SES_BaseGradeLevel_high,
               PayPlan AS targetPayPlan,
               PayBand AS targetgradelevel
        FROM PaySchedule.PaySchedule_NSeries_Xwalk AS a
        WHERE
        (
            SELECT MAX(AmcosVersionId)FROM lookup.AMCOSVersion
        )
        BETWEEN AmcosVersionIdStart AND AmcosVersionIdEnd
    ) AS a
        INNER JOIN
        (
            SELECT DISTINCT
                   PayPlan AS FromPayPlan,
                   GradeLevel AS FromGradeLevel
            FROM data.Costs
            WHERE PayPlan IN ( 'GS', 'SES' )
        ) AS b
            ON a.PayPlan = b.FromPayPlan
               AND b.FromGradeLevel
               BETWEEN a.GS_SES_BaseGradeLevel_low AND a.GS_SES_BaseGradeLevel_high
    --G and SES series, they just join on themselves
    UNION
    SELECT DISTINCT
           'GS' AS Payplan,
           GradeLevel,
           PayPlan,
           GradeLevel,
           'Not Applicable'
    FROM data.Costs
    WHERE PayPlan IN ( 'GS', 'GL', 'GG', 'GP' )
    UNION
    SELECT DISTINCT
           'SES' AS Payplan,
           GradeLevel,
           PayPlan,
           GradeLevel,
           'Not Applicable'
    FROM data.Costs
    WHERE PayPlan IN ( 'SES' )
) AS a;