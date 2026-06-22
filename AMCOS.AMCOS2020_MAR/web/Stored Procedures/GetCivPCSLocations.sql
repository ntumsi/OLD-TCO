
CREATE PROCEDURE [web].[GetCivPCSLocations] @AmcosVersionId INT
AS
SELECT LocationId,
       SourceSystemCode,
       LocationType,
       DisplayName
FROM
(
    SELECT wl.LocationId,
           wl.SourceSystemCode,
           wl.LocationType,
           wl.DisplayName,
           COALESCE(dg.MaximumLodgingRate, dd.MaximumLodgingRate) AS PerDiemAvailable
    FROM warehouse.Location wl
        LEFT JOIN crunch.GSAPerDiem dg
            ON wl.SourceSystemCode = dg.ZipCode
               AND wl.Coordinates IS NOT NULL
               AND dg.AmcosVersionId = @AmcosVersionId
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
               AND dd.AmcosVersionId = @AmcosVersionId
               AND wl.LocationType = 'civilian overseas'
) tbl
WHERE PerDiemAvailable IS NOT NULL;