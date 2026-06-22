CREATE VIEW quicksight.[MilitaryInstallationNameZip]
AS
SELECT DISTINCT
       UPPER(   CASE
                    WHEN BaseName = 'OTHER LOCATIONS' THEN
                        RTRIM(StationName)
                    WHEN BaseCode = STACO
                         OR BaseName = InstallationName THEN
                        RTRIM(BaseName)
                    ELSE
                        RTRIM(BaseName) + ' (' + RTRIM(InstallationName) + ')'
                END + ' [' + Service + '] (' + State + ') '
            ) AS installation,
       LEFT(ZIPCode, 5) AS zipcode
FROM lookup.MilitaryInstallation
WHERE
(
    SELECT MAX(AmcosVersionId)FROM lookup.AMCOSVersion
)
BETWEEN AmcosVersionIdStart AND AmcosVersionIdEnd;