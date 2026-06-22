
CREATE VIEW [data].[CostsCCE]
AS
SELECT OccupationalEmploymentStatisticsMetro.SOC,
       OccupationalEmploymentStatisticsMetro.MSACode,
       OccupationalEmploymentStatisticsMetro.A_PCT10,
       OccupationalEmploymentStatisticsMetro.A_PCT25,
       OccupationalEmploymentStatisticsMetro.A_MEDIAN,
       OccupationalEmploymentStatisticsMetro.A_PCT75,
       OccupationalEmploymentStatisticsMetro.A_PCT90,
       OccupationalEmploymentStatisticsMetro.AmcosVersionId,
       Location.LocationId
FROM BLS_OES.OccupationalEmploymentStatisticsMetro OccupationalEmploymentStatisticsMetro
    INNER JOIN warehouse.Location Location
        ON Location.SourceSystemCode = OccupationalEmploymentStatisticsMetro.MSACode
WHERE Location.LocationType = 'MSA';