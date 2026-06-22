

CREATE VIEW [web].[AMCOSVersionCY]
AS
SELECT LEFT(AmcosVersionId, 4) AS CY,
       MAX(RIGHT(AmcosVersionId, 2)) AS Release
FROM lookup.AMCOSVersion
WHERE LEN(AmcosVersionId) = 6
      AND AmcosVersionId >= 202001
GROUP BY LEFT(AmcosVersionId, 4);