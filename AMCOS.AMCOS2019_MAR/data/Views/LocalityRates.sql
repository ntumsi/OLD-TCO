
CREATE VIEW [data].[LocalityRates]
AS
SELECT Id AS LocalityId,
       Amount AS LocalityPay,
       Description AS LocalityDescription,
       1 AS SortOrder
FROM lookup.LocalityRates
WHERE IsLocalityPayArea = 1
UNION ALL
SELECT '501' AS LocalityId,
       -2.0000 AS LocalityPay,
       '----------------------------' AS LocalityDescription,
       2 AS SortOrder
UNION ALL
SELECT b.Id AS LocalityId,
       a.Amount AS LocalityPay,
       b.StateCode + b.CountyCode + b.CityCode + ' : ' + b.[Description] + ', ' + ISNULL(b.[StateName], '') AS LocalityDescription,
       3 AS SortOrder
FROM lookup.LocalityRates a
    INNER JOIN lookup.LocalityRates b
        ON a.Id = b.LocalityId
WHERE b.IsLocalityPayArea = 0;