CREATE PROCEDURE [crunch].[LoadGSAPerDiem] @AmcosVersionId INT
AS
SET NOCOUNT ON;

DELETE FROM [crunch].[GSAPerDiem]
WHERE AmcosVersionId = @AmcosVersionId;

INSERT INTO [crunch].[GSAPerDiem]
(
    ZipCode,
    FiscalYear,
    MaximumLodgingRate,
    MaximumMealsAndIncidentalsRate,
    DateEffective,
    AmcosVersionId
)
SELECT Zip,
       FiscalYear,
       (
           SELECT MAX(vals)
           FROM
           (
               VALUES
                   (MAX([Oct])),
                   (MAX(Nov)),
                   (MAX([Dec])),
                   (MAX(Jan)),
                   (MAX(Feb)),
                   (MAX(Mar)),
                   (MAX(Apr)),
                   (MAX(May)),
                   (MAX(Jun)),
                   (MAX(Jul)),
                   (MAX(Aug)),
                   (MAX(Sep))
           ) t2 (vals)
       ),
       MAX(Meals),
       GETDATE(),
       @AmcosVersionId
FROM [dataload].[GSAPerDiem_Raw]
WHERE AmcosVersionId = @AmcosVersionId
GROUP BY Zip,
         FiscalYear;
--the following insert takes care of the DoD per diem OCONUS areas that the US 'owns' which don't come from the GSA
INSERT INTO [crunch].[GSAPerDiem]
(
    ZipCode,
    FiscalYear,
    MaximumLodgingRate,
    MaximumMealsAndIncidentalsRate,
    DateEffective,
    AmcosVersionId
)
SELECT DISTINCT --a.StateCounty,a.Location,
       b.ZIPCode,
       LEFT(a.AmcosVersionId, 4) AS FiscalYear,
       MAX(a.Lodging),
       MAX(a.MaximumPerDiem - a.Lodging),
       GETDATE(),
       @AmcosVersionId
FROM dataload.DoDOCONUSPerDiem_Raw AS a
    INNER JOIN lookup.FIPS_ZIP AS b
        ON LOWER(a.Location) = LOWER(b.City)
           AND LOWER(a.StateCounty) = LOWER(b.StateName)
WHERE a.AmcosVersionId = @AmcosVersionId
      AND @AmcosVersionId
      BETWEEN b.AmcosVersionIdStart AND b.AmcosVersionIdEnd
      --because the DoD data comes with other countries we filter out just our OCONUS states and terrirotires
      AND a.StateCounty IN ( 'Alaska', 'HAWAII', 'AMERICAN SAMOA', 'PUERTO RICO' )
GROUP BY --a.StateCounty,a.Location,
    b.ZIPCode,
    LEFT(a.AmcosVersionId, 4);

--the following insert is for guam since its naming convention is special
INSERT INTO [crunch].[GSAPerDiem]
(
    ZipCode,
    FiscalYear,
    MaximumLodgingRate,
    MaximumMealsAndIncidentalsRate,
    DateEffective,
    AmcosVersionId
)
SELECT DISTINCT --a.StateCounty,a.Location,
       b.ZIPCode,
       LEFT(a.AmcosVersionId, 4) AS FiscalYear,
       MAX(a.Lodging),
       MAX(a.MaximumPerDiem - a.Lodging),
       GETDATE(),
       @AmcosVersionId
FROM dataload.DoDOCONUSPerDiem_Raw AS a
    INNER JOIN lookup.FIPS_ZIP AS b
        ON --LOWER(a.Location) =LOWER(b.City) AND 
        LOWER(a.StateCounty) = LOWER(b.StateName)
WHERE a.AmcosVersionId = @AmcosVersionId
      AND @AmcosVersionId
      BETWEEN b.AmcosVersionIdStart AND b.AmcosVersionIdEnd
      --because the DoD data comes with other countries we filter out just our OCONUS states and terrirotires
      AND a.StateCounty IN ( 'GUAM' )
GROUP BY --a.StateCounty,a.Location,
    b.ZIPCode,
    LEFT(a.AmcosVersionId, 4);
GO
