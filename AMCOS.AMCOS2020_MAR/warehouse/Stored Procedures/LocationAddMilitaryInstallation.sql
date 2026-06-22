-- =============================================
-- Author:		Name
-- Create date: 
-- Description:	
-- =============================================
CREATE PROCEDURE warehouse.LocationAddMilitaryInstallation @AmcosVersionId INT
AS
BEGIN
    SET NOCOUNT ON;

    DROP TABLE IF EXISTS #MilitaryInstallations;
    CREATE TABLE #MilitaryInstallations
    (
        DisplayBase VARCHAR(500) NOT NULL,
        ZipCode VARCHAR(5) NOT NULL
    );
    INSERT INTO #MilitaryInstallations
    (
        DisplayBase,
        ZipCode
    )
    SELECT UPPER(   CASE
                        WHEN BaseName = 'OTHER LOCATIONS' THEN
                            RTRIM(StationName)
                        WHEN BaseCode = STACO
                             OR BaseName = InstallationName THEN
                            RTRIM(BaseName)
                        ELSE
                            RTRIM(BaseName) + ' (' + RTRIM(InstallationName) + ')'
                    END + ' [' + Service + '] (' + State + ') '
                ) AS installation,
           LEFT(ZIPCode, 5)
    FROM lookup.MilitaryInstallation
    WHERE @AmcosVersionId
    BETWEEN AmcosVersionIdStart AND AmcosVersionIdEnd;

    WITH cte_MilitaryInstallations
    AS (SELECT a.ZIPCode,
               b.DisplayBase,
               ROW_NUMBER() OVER (PARTITION BY b.DisplayBase ORDER BY a.ZIPCode ASC) AS row_number
        FROM xwalk.ZIPToMHA AS a
            INNER JOIN #MilitaryInstallations AS b
                ON a.ZIPCode = b.ZipCode
        WHERE @AmcosVersionId
        BETWEEN a.AmcosVersionIdStart AND a.AmcosVersionIdEnd)
    INSERT INTO warehouse.Location
    (
        SourceSystemCode,
        LocationType,
        DisplayName,
        Geometry,
        Coordinates
    )
    SELECT cte_MilitaryInstallations.ZIPCode,
           'Military Installation',
           cte_MilitaryInstallations.DisplayBase,
           NULL,
           NULL
    FROM cte_MilitaryInstallations
    WHERE cte_MilitaryInstallations.row_number = 1
    ORDER BY cte_MilitaryInstallations.DisplayBase;

END;