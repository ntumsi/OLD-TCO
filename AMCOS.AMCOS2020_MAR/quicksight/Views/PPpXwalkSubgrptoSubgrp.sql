

CREATE VIEW [quicksight].[PPpXwalkSubgrptoSubgrp]
AS
SELECT DISTINCT
       *
FROM
(
    SELECT DISTINCT
           a.SubgroupCode AS fromSubGroupCode,
           b.SubgroupCode AS toSubGroupCode,
           a.PayPlanType AS FromPayPlanType,
           b.PayPlanType AS toPayPlanType
    FROM xwalk.OnetSubgroupCrosswalk AS a
        INNER JOIN xwalk.OnetSubgroupCrosswalk AS b
            ON b.ONET_code = a.ONET_code
               AND b.PayPlanType = a.PayPlanType
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
    UNION
    SELECT DISTINCT
           b.SubgroupCode AS fromSubGroupCode,
           b.SubgroupCode AS toSubGroupCode,
           a.PayPlanType AS FromPayPlanType,
           a.PayPlanType AS toPayPlanType
    FROM xwalk.OnetSubgroupCrosswalk AS a
        INNER JOIN xwalk.OnetSubgroupCrosswalk AS b
            ON b.ONET_code = a.ONET_code
               AND b.PayPlanType = a.PayPlanType
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
    UNION
    --CCE to non-CCE
    SELECT DISTINCT
           LEFT(a.ONET_code, 7) AS fromSubGroupCode,
           b.SubgroupCode AS toSubGroupCode,
           'CTR' AS FromPayPlanType,
           b.PayPlanType AS toPayPlanType
    FROM xwalk.OnetSubgroupCrosswalk AS a
        INNER JOIN xwalk.OnetSubgroupCrosswalk AS b
            ON b.ONET_code = a.ONET_code
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
    UNION
    --non-CCE to CCE
    SELECT DISTINCT
           a.SubgroupCode AS fromSubGroupCode,
           LEFT(b.ONET_code, 7) AS toSubGroupCode,
           a.PayPlanType AS FromPayPlanType,
           'CTR' AS toPayPlanType
    FROM xwalk.OnetSubgroupCrosswalk AS a
        INNER JOIN xwalk.OnetSubgroupCrosswalk AS b
            ON b.ONET_code = a.ONET_code
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
) AS a;