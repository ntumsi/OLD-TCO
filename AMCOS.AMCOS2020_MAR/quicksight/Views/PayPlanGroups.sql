

CREATE VIEW [quicksight].[PayPlanGroups]
AS
SELECT PayPlan AS PayPlan,
       CASE
           WHEN GroupTitle LIKE '%wage%' THEN
               'Civilian (Wage)'
           WHEN PayPlan IN ( 'AE', 'AO', 'AWO' ) THEN
               'Military (Active)'
           WHEN PayPlan IN ( 'RE', 'NE', 'NO', 'RO', 'RWO', 'NWO' ) THEN
               'Military (NG/R)'
           WHEN PayPlan = 'CCE' THEN
               'Civilian (Contractor)'
           ELSE
               'Civilian (Non-Wage)'
       END AS PayPlanGroup
FROM lookup.PayPlan
WHERE DisplayTitle IS NOT NULL;