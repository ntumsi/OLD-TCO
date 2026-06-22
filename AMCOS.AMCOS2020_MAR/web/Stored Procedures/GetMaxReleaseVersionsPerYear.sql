-- =============================================
-- Author:     Benedict Mays
-- Create Date: 1/27/2021
-- Description: Return max release versions grouped by year
-- =============================================
CREATE PROCEDURE [web].[GetMaxReleaseVersionsPerYear] @start INT = 1900
AS
BEGIN
    SELECT CY,
           MAX(Release) AS Release
    FROM [web].[AMCOSVersionCY]
    WHERE CY >= @start
    GROUP BY CY
    ORDER BY CY DESC;
END;