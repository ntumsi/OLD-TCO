
/*
Author:		Dan Hogan
Create date: 01/09/2020
Description:	Converts raw WASS data into the correct inventory format and conducts necessary data checks/conversions
Destination: crunch.InventoryWASS
*/
CREATE PROCEDURE [crunch].[CrunchInventoryWASS]
    @AmcosVersionId INT = -1,
    @debug BIT = 0
AS
BEGIN

    SET NOCOUNT ON;

    CREATE TABLE #WASSRaw
    (
        PayPlan NVARCHAR(3) NOT NULL,
        FundType NVARCHAR(3) NOT NULL,
        OccupationalGroupNumber NVARCHAR(4) NOT NULL,
        OccupationalSeriesNumber NVARCHAR(4) NOT NULL,
        IsValidOccupationalSeriesNumber BIT NOT NULL,
        Grade NVARCHAR(3) NOT NULL,
        Step NVARCHAR(2) NOT NULL,
        StateCode NVARCHAR(2) NOT NULL,
        CountyCode NVARCHAR(3) NOT NULL,
        CityCode NVARCHAR(4) NOT NULL,
        LocationId INT NOT NULL,
        LocationName NVARCHAR(150) NULL,
        AveragePay NUMERIC(18, 2) NOT NULL,
        Inventory SMALLINT NOT NULL,
        AmcosVersionId INT NOT NULL
    );
    /* we only care about those pay plans where we need actual pay data because we don't have a payschedule for them
    otherwise DMDC is going to be the far better source for the data since in Dec 2019 Marsha found that WASS was missing large amounts of national guard civ personnel */
    INSERT INTO #WASSRaw
    (
        PayPlan,
        FundType,
        OccupationalGroupNumber,
        OccupationalSeriesNumber,
        IsValidOccupationalSeriesNumber,
        Grade,
        Step,
        StateCode,
        CountyCode,
        CityCode,
        LocationId,
        LocationName,
        AveragePay,
        Inventory,
        AmcosVersionId
    )
    SELECT PayPlan = CASE PayPlan
                         WHEN 'ES' THEN
                             'SES'
                         ELSE
                             PayPlan
                     END,
           '-1' AS FundType,
           LEFT(RIGHT('0000' + OccupationalSeriesNumber, 4), 2) + '00',
           RIGHT('0000' + OccupationalSeriesNumber, 4),
           '0' AS FundType,
           GradeLevel,
           Step,
           StateCode = CASE StateCode
                           WHEN 'RQ' THEN
                               '72'
                           ELSE
                               StateCode
                       END,
           CountyCode,
           CityCode,
           '-1' AS LocationId,
           NULL AS LocationName,
           SUM(SAL_WAG * Count) / SUM(Count) AS AveragePay,
           SUM(Count) AS Inventory,
           AmcosVersionId
    FROM load_inventory.WASS_Raw
    WHERE AmcosVersionId = @AmcosVersionId
    GROUP BY PayPlan,
             OccupationalSeriesNumber,
             GradeLevel,
             Step,
             StateCode,
             CountyCode,
             CityCode,
             AmcosVersionId;




    /* White Collar Occupational Series */
    UPDATE #WASSRaw
    SET IsValidOccupationalSeriesNumber = 1
    WHERE PayPlan IN ( 'SES', 'NF' )
          AND OccupationalSeriesNumber IN
              (
                  SELECT OccupationalSeriesNumber
                  FROM lookup.GS_OccupationalSeries
                  WHERE @AmcosVersionId
                  BETWEEN AmcosVersionIdStart AND AmcosVersionIdEnd
              );


    /* Craft, Trade, or Labor Occupational Series */
    UPDATE #WASSRaw
    SET IsValidOccupationalSeriesNumber = 1
    WHERE PayPlan NOT IN ( 'SES', 'NF' )
          AND OccupationalSeriesNumber IN
              (
                  SELECT OccupationalSeriesNumber
                  FROM lookup.Wage_OccupationalSeries
                  WHERE @AmcosVersionId
                  BETWEEN AmcosVersionIdStart AND AmcosVersionIdEnd
              );

    /* Overseas
    map civilians to Department of State overseas areas, by DLOC first */
    UPDATE #WASSRaw
    SET LocationId = d.LocationId,
        LocationName = d.DisplayName
    FROM #WASSRaw AS a
        INNER JOIN xwalk.DLOCtoDoS AS b
            ON b.DLOC = a.StateCode + a.CityCode + a.CountyCode
        INNER JOIN lookup.DosLocations AS c
            ON c.LocationCode = b.DOSLocation
        INNER JOIN warehouse.Location AS d
            ON d.SourceSystemCode = c.LocationCode
    WHERE a.LocationId IS NULL -- only update locationids we don't already know
          AND @AmcosVersionId
          BETWEEN b.AmcosVersionIdStart AND b.AmcosVersionIdEnd
          AND @AmcosVersionId
          BETWEEN c.AmcosVersionIdStart AND c.AmcosVersionIdEnd
          AND d.LocationType = 'Civilian Overseas'; --don't want the DoS location id inadvertantly matching another location's ID

    /* White Collar (Locality Area) non-RUS first */
    UPDATE #WASSRaw
    SET LocationId = e.LocationId,
        LocationName = e.DisplayName
    FROM #WASSRaw AS a
        INNER JOIN xwalk.LocalityPayAreaToFips AS c
            ON c.StateCode = a.StateCode
               AND c.CountyCode = a.CountyCode
               AND c.AmcosVersionId = a.AmcosVersionId
        INNER JOIN warehouse.Location AS e
            ON e.SourceSystemCode = c.LocalityCode
    WHERE @AmcosVersionId = c.AmcosVersionId
          AND e.LocationType = 'Locality Pay Area'
          AND a.PayPlan IN ( 'GS', 'SES' );

    /* now assign RUS */
    UPDATE #WASSRaw
    SET LocationId = c.LocationId,
        LocationName = c.DisplayName
    FROM #WASSRaw AS a
        INNER JOIN lookup.FIPS_ZIP AS b
            ON a.StateCode + a.CountyCode = b.FIPSCode
        CROSS JOIN
        (
            SELECT *
            FROM warehouse.Location
            WHERE LocationType = 'Locality Pay Area'
                  AND SourceSystemCode = 'RUS'
        ) AS c
    WHERE @AmcosVersionId
          BETWEEN b.AmcosVersionIdStart AND b.AmcosVersionIdEnd
          AND a.PayPlan = 'SES'
          AND a.LocationId IS NULL;

    /* Federal Wage Schedule AF */
    UPDATE #WASSRaw
    SET LocationId = c.LocationId,
        LocationName = c.DisplayName
    FROM #WASSRaw AS a
        INNER JOIN xwalk.WageAreaToFips AS b
            ON a.StateCode = b.StateCode
               AND a.CountyCode = b.CountyCode
               AND a.AmcosVersionId = b.AmcosVersionId
        INNER JOIN warehouse.Location AS c
            ON b.ScheduleArea = c.SourceSystemCode
    WHERE a.AmcosVersionId = @AmcosVersionId
          AND c.LocationType IN ( 'Federal Wage System AF', 'Federal Wage System AF Overseas' )
          AND PayPlan IN
              (
                  SELECT RIGHT(PayPlan, 2)FROM lookup.PayPlanTags WHERE Tag = 'Wage AF'
              )
          AND b.FundType = 'AF';

    /* Federal Wage Schedule NAF */
    UPDATE #WASSRaw
    SET LocationId = c.LocationId,
        LocationName = c.DisplayName
    FROM #WASSRaw AS a
        INNER JOIN xwalk.WageAreaToFips AS b
            ON a.StateCode = b.StateCode
               AND a.CountyCode = b.CountyCode
               AND a.AmcosVersionId = b.AmcosVersionId
        INNER JOIN warehouse.Location AS c
            ON b.ScheduleArea = c.SourceSystemCode
    WHERE a.AmcosVersionId = @AmcosVersionId
          AND c.LocationType IN ( 'Federal Wage System NAF' )
          AND PayPlan IN
              (
                  SELECT RIGHT(PayPlan, 2)FROM lookup.PayPlanTags WHERE Tag = 'Wage NAF'
              )
          AND b.FundType = 'NAF';

    /* Federal Wage Schedule NAF */
    UPDATE #WASSRaw
    SET LocationId = c.LocationId,
        LocationName = c.DisplayName
    FROM #WASSRaw AS a
        INNER JOIN xwalk.WageAreaToFips AS b
            ON a.StateCode = b.StateCode
               AND a.AmcosVersionId = b.AmcosVersionId
        INNER JOIN warehouse.Location AS c
            ON b.ScheduleArea = c.SourceSystemCode
    WHERE a.AmcosVersionId = @AmcosVersionId
          AND c.LocationType IN ( 'Federal Wage System NAF Overseas' )
          AND PayPlan IN
              (
                  SELECT RIGHT(PayPlan, 2)FROM lookup.PayPlanTags WHERE Tag = 'Wage NAF'
              )
          AND b.FundType = 'NAF';

    /* so anything that doesn't have a locationid gets a -1 and is unknown */
    UPDATE #WASSRaw
    SET LocationId = -1
    WHERE LocationId IS NULL;


    IF EXISTS (SELECT * FROM #WASSRaw WHERE LocationId = -1)
    BEGIN
        SELECT 'these entries are missing a location which means they are unknown';
        SELECT *
        FROM #WASSRaw
        WHERE LocationId = -1
        ORDER BY PayPlan;
    END;

    IF EXISTS
    (
        SELECT *
        FROM #WASSRaw
        WHERE IsValidOccupationalSeriesNumber = 0
    )
    BEGIN
        SELECT 'these entries have an invalid subgroup code';
        SELECT *
        FROM #WASSRaw
        WHERE IsValidOccupationalSeriesNumber = 0
        ORDER BY PayPlan;

    END;
	
    IF @debug = 0
    BEGIN

        --#### Delete and Insert
        DELETE FROM crunch.InventoryWASS
        WHERE AmcosVersionId = @AmcosVersionId;

        --sum up to the location and subgroup level
        INSERT INTO crunch.InventoryWASS
        (
            PayPlan,
            OccupationalGroupNumber,
            OccupationalSeriesNumber,
            GradeType,
            GradeLevel,
            Step,
            LocationId,
            Inventory,
            AveragePay,
            AmcosVersionId
        )
        SELECT PayPlan,
               OccupationalGroupNumber,
               OccupationalSeriesNumber,
               PayPlan,
               Grade,
               Step,
               LocationId,
               SUM(Inventory),
               SUM(AveragePay * Inventory) / SUM(Inventory),
               AmcosVersionId
        FROM #WASSRaw
        WHERE LocationId <> -1
        GROUP BY PayPlan,
                 OccupationalGroupNumber,
                 OccupationalSeriesNumber,
                 Grade,
                 Step,
                 LocationId,
                 AmcosVersionId;
    END;

END;