CREATE VIEW [xwalk].[PayPlanType]
AS
SELECT PayPlan,
       CASE
           WHEN PayPlan IN ( 'AE', 'RE', 'NE' ) THEN
               'E'
           WHEN PayPlan IN ( 'AO', 'RO', 'NO' ) THEN
               'O'
           WHEN PayPlan IN ( 'AWO', 'RWO', 'NWO' ) THEN
               'W'
           WHEN PayPlan = 'CCE' THEN
               'CTR'
           ELSE
               'CIV'
       END AS PayPlanType
FROM lookup.PayPlan
WHERE DisplayTitle IS NOT NULL
      AND
      (
          SELECT MAX(AmcosVersionId)FROM lookup.AMCOSVersion
      )
      BETWEEN AmcosVersionIdStart AND AmcosVersionIdEnd;