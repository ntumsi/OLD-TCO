

CREATE VIEW [web].[CivLocationPerDiem]
AS
SELECT tbl.LocationId,
       tbl.SourceSystemCode,
       tbl.LocationType,
       tbl.DisplayName,
       tbl.Coordinates,
       tbl.MaxLodgingRate,
       tbl.MIERate,
       tbl.AmcosVersionId
FROM
(
    SELECT wl.LocationId,
           wl.SourceSystemCode,
           wl.LocationType,
           wl.DisplayName,
           wl.Coordinates,
           COALESCE(dg.MaximumLodgingRate, dd.maximumlodgingrate) AS MaxLodgingRate,
           COALESCE(dg.MaximumMealsAndIncidentalsRate, dd.m_ierate) AS MIERate,
           COALESCE(dg.AmcosVersionId, dd.AmcosVersionId) AS AmcosVersionId
    FROM warehouse.Location wl
        LEFT JOIN crunch.GSAPerDiem dg
            ON wl.SourceSystemCode = dg.ZipCode
               AND wl.Coordinates IS NOT NULL
               AND wl.LocationType = 'zip'
        LEFT JOIN
        (
            SELECT LocationCode,
                   MAX(MaximumLodgingRate) AS MaximumLodgingRate,
                   MAX(m_ierate) AS m_ierate,
                   AmcosVersionId
            FROM dataload.DoSPerDiem
            GROUP BY LocationCode,
                     AmcosVersionId
        ) dd
            ON wl.SourceSystemCode = dd.LocationCode
               AND wl.Coordinates IS NOT NULL
               AND wl.LocationType = 'civilian overseas'
) tbl
WHERE MaxLodgingRate IS NOT NULL
      AND MIERate IS NOT NULL;
GO


