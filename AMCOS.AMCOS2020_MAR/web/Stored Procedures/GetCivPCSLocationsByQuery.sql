CREATE PROCEDURE [web].[GetCivPCSLocationsByQuery]
(
    @AmcosVersionId INT,
    @Query NVARCHAR(100) = 'A',
    @ZipCode VARCHAR(5) = NULL
)
AS
DECLARE @Count INT = 0;
DECLARE @Result TABLE
(
    LocationId INT,
    SourceSystemCode NVARCHAR(100),
    LocationType NVARCHAR(100),
    DisplayName NVARCHAR(100)
);
IF @ZipCode <> ''
   AND @ZipCode IS NOT NULL
BEGIN
    INSERT INTO @Result
    (
        LocationId,
        SourceSystemCode,
        LocationType,
        DisplayName
    )
    SELECT wl.LocationId,
           wl.SourceSystemCode,
           wl.LocationType,
           wl.DisplayName
    FROM warehouse.Location wl
        JOIN crunch.GSAPerDiem dg
            ON wl.SourceSystemCode = dg.ZipCode
               AND wl.Coordinates IS NOT NULL
               AND dg.AmcosVersionId = @AmcosVersionId
               AND wl.LocationType = 'zip'
    WHERE wl.SourceSystemCode = @ZipCode;
END;
SELECT @Count = @@ROWCOUNT;
IF @Query <> ''
   AND @Query IS NOT NULL
BEGIN
    INSERT INTO @Result
    (
        LocationId,
        SourceSystemCode,
        LocationType,
        DisplayName
    )
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
               COALESCE(dg.MaximumLodgingRate, dd.maximumlodgingrate) AS PerDiemAvailable
        FROM warehouse.Location wl
            LEFT JOIN crunch.GSAPerDiem dg
                ON wl.SourceSystemCode = dg.ZipCode
                   AND wl.Coordinates IS NOT NULL
                   AND dg.AmcosVersionId = @AmcosVersionId
                   AND wl.LocationType = 'zip'
            LEFT JOIN
            (
                SELECT LocationCode,
                       MAX(MaximumLodgingRate) AS maximumlodgingrate,
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
    WHERE PerDiemAvailable IS NOT NULL
          AND DisplayName = @Query;
END;
SELECT @Count = @Count + @@ROWCOUNT;
IF @Count < 500
BEGIN
    INSERT INTO @Result
    (
        LocationId,
        SourceSystemCode,
        LocationType,
        DisplayName
    )
    SELECT TOP (500 - @Count)
           LocationId,
           SourceSystemCode,
           LocationType,
           DisplayName
    FROM
    (
        SELECT wl.LocationId,
               wl.SourceSystemCode,
               wl.LocationType,
               wl.DisplayName,
               COALESCE(dg.MaximumLodgingRate, dd.maximumlodgingrate) AS PerDiemAvailable
        FROM warehouse.Location wl
            LEFT JOIN crunch.GSAPerDiem dg
                ON wl.SourceSystemCode = dg.ZipCode
                   AND wl.Coordinates IS NOT NULL
                   AND dg.AmcosVersionId = @AmcosVersionId
                   AND wl.LocationType = 'zip'
            LEFT JOIN
            (
                SELECT LocationCode,
                       MAX(MaximumLodgingRate) AS maximumlodgingrate,
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
    WHERE PerDiemAvailable IS NOT NULL
          AND DisplayName LIKE @Query + '%';
END;
SELECT @Count = @Count + @@ROWCOUNT;
IF @Count < 500
BEGIN
    SELECT @Query = REPLACE(@Query, ' ', '%');
    INSERT INTO @Result
    (
        LocationId,
        SourceSystemCode,
        LocationType,
        DisplayName
    )
    SELECT TOP (500 - @Count)
           LocationId,
           SourceSystemCode,
           LocationType,
           DisplayName
    FROM
    (
        SELECT wl.LocationId,
               wl.SourceSystemCode,
               wl.LocationType,
               wl.DisplayName,
               COALESCE(dg.MaximumLodgingRate, dd.maximumlodgingrate) AS PerDiemAvailable
        FROM warehouse.Location wl
            LEFT JOIN crunch.GSAPerDiem dg
                ON wl.SourceSystemCode = dg.ZipCode
                   AND wl.Coordinates IS NOT NULL
                   AND dg.AmcosVersionId = @AmcosVersionId
                   AND wl.LocationType = 'zip'
            LEFT JOIN
            (
                SELECT LocationCode,
                       MAX(MaximumLodgingRate) AS maximumlodgingrate,
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
    WHERE PerDiemAvailable IS NOT NULL
          AND DisplayName LIKE '%' + @Query + '%';
END;
SELECT @Count = @Count + @@ROWCOUNT;
IF @Count < 500
   AND @ZipCode IS NOT NULL
BEGIN
    INSERT INTO @Result
    (
        LocationId,
        SourceSystemCode,
        LocationType,
        DisplayName
    )
    SELECT TOP (500 - @Count)
           wl.LocationId,
           wl.SourceSystemCode,
           wl.LocationType,
           wl.DisplayName
    FROM warehouse.Location wl
        JOIN crunch.GSAPerDiem dg
            ON wl.SourceSystemCode = dg.ZipCode
               AND wl.Coordinates IS NOT NULL
               AND dg.AmcosVersionId = @AmcosVersionId
               AND wl.LocationType = 'zip'
    WHERE wl.SourceSystemCode LIKE '%' + @ZipCode + '%';
END;
SELECT DISTINCT
       *
FROM @Result;
GO
