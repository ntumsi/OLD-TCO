
-- =============================================
-- Author:		
-- Create date: 
-- Description:	Populate crunch.PayScheduleMinMax table
-- =============================================
CREATE PROCEDURE [crunch].[CalculatePayPlanMinMax]
    @AmcosVersionId INT = -1,
    @Debug AS BIT = 1
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @annualhours NUMERIC(16, 2) = crunch.GetSingleValue('GP', 'annualPaidHours', @AmcosVersionId);

    DROP TABLE IF EXISTS #PayMinMax;
    CREATE TABLE #PayMinMax
    (
        PayPlan NVARCHAR(3) NOT NULL,
        GradeType NVARCHAR(3) NOT NULL,
        CategorySubgroupCode NVARCHAR(5) NOT NULL,
        LocationId INT NOT NULL,
        STRL NVARCHAR(20) NOT NULL,
        GradeLevel TINYINT NOT NULL,
        MinRate NUMERIC(16, 2) NOT NULL,
        MaxRate NUMERIC(16, 2) NOT NULL,
        AmcosVersionId INT NOT NULL
    );

    /* Insert minimum and maximum pay for category subgroup for military pay plans */
    INSERT INTO #PayMinMax
    (
        PayPlan,
        GradeType,
        CategorySubgroupCode,
        LocationId,
        STRL,
        GradeLevel,
        MaxRate,
        MinRate,
        AmcosVersionId
    )
    SELECT a.PayPlan,
           a.GradeType,
           a.CategorySubgroupCode,
           a.LocationId,
           a.Strl,
           a.GradeLevel,
           MAX(   CASE
                      WHEN a.RateType = 'Monthly' THEN
                          a.Rate * 12 --active mil
                      WHEN a.RateType = '4 Drills' THEN
                          a.Rate * 12 --NG/R 1 weekend a month
                      ELSE
                          a.Rate
                  END
              ) AS MaxRate,
           MIN(   CASE
                      WHEN a.RateType = 'Monthly' THEN
                          a.Rate * 12 --active mil
                      WHEN a.RateType = '4 Drills' THEN
                          a.Rate * 12 --NG/R 1 weekend a month
                      ELSE
                          a.Rate
                  END
              ) AS MinRate,
           a.AmcosVersionId
    FROM data.PaySchedules AS a
        INNER JOIN lookup.PayPlanTags AS b
            ON b.PayPlan = a.PayPlan
               AND b.AmcosVersionId = a.AmcosVersionId
    WHERE a.AmcosVersionId = @AmcosVersionId
          AND b.Tag = 'Military'
    GROUP BY a.PayPlan,
             a.GradeType,
             a.CategorySubgroupCode,
             a.LocationId,
             a.Strl,
             a.GradeLevel,
             a.AmcosVersionId;

			 
	IF @Debug = 1
	BEGIN
		
		Select '93> Below listed any excessively large pay rates above $500,000'
		SELECT * FROM #PayMinMax WHERE MaxRate > 500000
	END

    /* --bring in the min/max by subgroup for WAGE CONUS
	--2/12/2022 Dan Hogan - I found an error with this in that NF amounts are in annual while all other wage are in hourly so we need to fix that so the math is correct */
    INSERT INTO #PayMinMax
    (
        PayPlan,
        GradeType,
        CategorySubgroupCode,
        LocationId,
        STRL,
        GradeLevel,
        MaxRate,
        MinRate,
        AmcosVersionId
    )
    SELECT a.PayPlan,
           a.GradeType,
           a.CategorySubgroupCode,
           a.LocationId,
           a.Strl,
           a.GradeLevel,
           MAX(   CASE
                      WHEN a.PayPlan = 'NF' OR a.RateType = 'Annual' THEN
                          1
                      ELSE
                          @annualhours
                  END * a.Rate --wage

              ) AS MaxRate,
           MIN(   CASE
                      WHEN a.PayPlan = 'NF' OR a.RateType = 'Annual' THEN
                          1
                      ELSE
                          @annualhours
                  END * a.Rate
              ) AS MinRate,
           a.AmcosVersionId
    FROM data.PaySchedules a
        INNER JOIN warehouse.Location b
            ON b.LocationId = a.LocationId
        INNER JOIN lookup.PayPlanTags AS c
            ON c.PayPlan = a.PayPlan
               AND c.AmcosVersionId = a.AmcosVersionId
    WHERE a.AmcosVersionId = @AmcosVersionId
          AND c.Tag = 'Wage'
          AND a.LocationId <> -1
          AND b.DisplayName <> 'Foreign Areas'
    GROUP BY a.PayPlan,
             a.GradeType,
             a.CategorySubgroupCode,
             a.LocationId,
             a.Strl,
             a.GradeLevel,
             a.AmcosVersionId;

	IF @Debug = 1
	BEGIN
		
		Select '154> Below listed any excessively large pay rates above $500,000'
		SELECT * FROM #PayMinMax WHERE MaxRate > 500000
	END

    --bring in the min/max by subgroup for WAGE OCONUS
    INSERT INTO #PayMinMax
    (
        PayPlan,
        GradeType,
        CategorySubgroupCode,
        LocationId,
        STRL,
        GradeLevel,
        MaxRate,
        MinRate,
        AmcosVersionId
    )
    SELECT a.PayPlan,
           a.GradeType,
           a.CategorySubgroupCode,
           a.LocationId,
           a.Strl,
           a.GradeLevel,
           MAX(@annualhours * a.Rate) AS MaxRate,
           MIN(@annualhours * a.Rate) AS MinRate,
           a.AmcosVersionId
    FROM data.PaySchedules AS a
        INNER JOIN warehouse.Location AS b
            ON b.LocationId = a.LocationId
        INNER JOIN lookup.PayPlanTags AS c
            ON c.PayPlan = a.PayPlan
               AND c.AmcosVersionId = a.AmcosVersionId
    WHERE a.AmcosVersionId = @AmcosVersionId
          AND c.Tag = 'Wage'
          AND a.LocationId <> -1
          AND b.LocationType IN ( 'Federal Wage System AF', 'Federal Wage System NAF' )
          AND b.DisplayName = 'Foreign Areas'
    GROUP BY a.PayPlan,
             a.GradeType,
             a.CategorySubgroupCode,
             a.LocationId,
             a.Strl,
             a.GradeLevel,
             a.AmcosVersionId;

	IF @Debug = 1
	BEGIN
		
		Select '202> Below listed any excessively large pay rates above $500,000'
		SELECT * FROM #PayMinMax WHERE MaxRate > 500000
	END

    /* Bring in the min/max by subgroup for WAGE ALL (-1) */
    INSERT INTO #PayMinMax
    (
        a.PayPlan,
        a.GradeType,
        a.CategorySubgroupCode,
        a.LocationId,
        a.STRL,
        a.GradeLevel,
        a.MaxRate,
        a.MinRate,
        a.AmcosVersionId
    )
    SELECT a.PayPlan,
           a.GradeType,
           a.CategorySubgroupCode,
           -1 AS LocationId,
           a.Strl,
           a.GradeLevel,
           MAX(@annualhours * a.Rate) AS MaxRate,
           MIN(@annualhours * a.Rate) AS MinRate,
           a.AmcosVersionId
    FROM data.PaySchedules AS a
        INNER JOIN lookup.PayPlanTags AS b
            ON b.PayPlan = a.PayPlan
               AND b.AmcosVersionId = a.AmcosVersionId
    WHERE a.AmcosVersionId = @AmcosVersionId
          AND b.Tag = 'Wage'
		  AND a.RateType <> 'Annual'
    GROUP BY a.PayPlan,
             a.GradeType,
             a.CategorySubgroupCode,
             a.Strl,
             a.GradeLevel,
             a.AmcosVersionId;
			 

	IF @Debug = 1
	BEGIN
		Select '243> Below listed any excessively large pay rates above $500,000'
		SELECT * FROM #PayMinMax WHERE MaxRate > 500000
	END
    /* TODO:  Fix this
	bring in the min/max by subgroup for CIV CONUS */
    INSERT INTO #PayMinMax
    (
        PayPlan,
        GradeType,
        CategorySubgroupCode,
        LocationId,
        STRL,
        GradeLevel,
        MaxRate,
        MinRate,
        AmcosVersionId
    )
    SELECT a.PayPlan,
           a.GradeType,
           a.CategorySubgroupCode,
           a.LocationId,
           a.Strl,
           a.GradeLevel,
           MAX(a.Rate) AS MaxRate,
           MIN(a.Rate) AS MinRate,
           a.AmcosVersionId
    FROM data.PaySchedules AS a
        INNER JOIN lookup.PayPlanTags AS b
            ON b.PayPlan = a.PayPlan
               AND b.AmcosVersionId = a.AmcosVersionId
    WHERE a.AmcosVersionId = @AmcosVersionId
          AND b.Tag IN ( 'GFEBS', 'Civilian' )
          AND a.LocationId <> -1 --ALL will be handled in a moment
          AND a.LocationId IN --no  overseas areas
              (
                  SELECT LocationId
                  FROM warehouse.Location
                  WHERE DisplayName NOT IN ( 'Civilian Overseas' )
              )
    GROUP BY a.PayPlan,
             a.GradeType,
             a.CategorySubgroupCode,
             a.LocationId,
             a.Strl,
             a.GradeLevel,
             a.AmcosVersionId;

	IF @Debug = 1
	BEGIN
		Select '294> Below listed any excessively large pay rates above $500,000'
		SELECT * FROM #PayMinMax WHERE MaxRate > 500000
	END

    --bring in the min/max by subgroup for CIV OCONUS
    INSERT INTO #PayMinMax
    (
        PayPlan,
        GradeType,
        CategorySubgroupCode,
        LocationId,
        STRL,
        GradeLevel,
        MaxRate,
        MinRate,
        AmcosVersionId
    )
    SELECT a.PayPlan,
           a.GradeType,
           a.CategorySubgroupCode,
           b.LocationId,
           a.Strl,
           a.GradeLevel,
           MAX(a.Rate) AS MaxRate,
           MIN(a.Rate) AS MinRate,
           a.AmcosVersionId
    FROM data.PaySchedules AS a
        CROSS JOIN warehouse.Location AS b
    WHERE a.AmcosVersionId = @AmcosVersionId
          AND a.PayPlan IN
              (
                  SELECT PayPlan FROM lookup.PayPlanTags WHERE Tag IN ( 'GFEBS', 'Civilian' )
              )
          AND a.LocationId = -1 --CIV base pay is -1 location
          AND b.LocationType = 'Civilian Overseas'
    GROUP BY a.PayPlan,
             a.GradeType,
             a.CategorySubgroupCode,
             b.LocationId,
             a.Strl,
             a.GradeLevel,
             a.AmcosVersionId;

	IF @Debug = 1
	BEGIN
		Select '339> Below listed any excessively large pay rates above $500,000'
		SELECT * FROM #PayMinMax WHERE MaxRate > 500000
	END

    --bring in the min/max by subgroup for CIV ALL (-1)
    INSERT INTO #PayMinMax
    (
        PayPlan,
        GradeType,
        CategorySubgroupCode,
        LocationId,
        STRL,
        GradeLevel,
        MaxRate,
        MinRate,
        AmcosVersionId
    )
    SELECT a.PayPlan,
           a.GradeType,
           a.CategorySubgroupCode,
           -1,
           a.Strl,
           a.GradeLevel,
           MAX(a.Rate) AS MaxRate,
           MIN(a.Rate) AS MinRate,
           a.AmcosVersionId
    FROM data.PaySchedules AS a
        INNER JOIN lookup.PayPlanTags AS b
            ON b.PayPlan = a.PayPlan
               AND b.AmcosVersionId = a.AmcosVersionId
    WHERE a.AmcosVersionId = @AmcosVersionId
          AND b.Tag = 'GFEBS' AND b.Tag = 'Civilian' 
    GROUP BY a.PayPlan,
             a.GradeType,
             a.CategorySubgroupCode,
             a.Strl,
             a.GradeLevel,
             a.AmcosVersionId;

	IF @Debug = 1
	BEGIN
		Select '380> Below listed any excessively large pay rates above $500,000'
		SELECT * FROM #PayMinMax WHERE MaxRate > 500000
	END

    --WASS based pay has no payschedule so has to come directly from the wass source
    INSERT INTO #PayMinMax
    (
        PayPlan,
        GradeType,
        CategorySubgroupCode,
        LocationId,
        STRL,
        GradeLevel,
        MaxRate,
        MinRate,
        AmcosVersionId
    )
    SELECT PayPlan,
           GradeType,
           OccupationalSeriesNumber,
           LocationId,
           '-1' AS STRL,
           GradeLevel,
		   CASE
			   WHEN MAX(AveragePay) > 1000 THEN MAX(AveragePay)  --When average pay is likely annual then don't multiply by annual hours
			   ELSE MAX(AveragePay) * @annualhours
		   END,
		   CASE 
			   WHEN MIN(AveragePay) > 1000 Then Min(AVeragePay) --When average pay is likely annual then don't multiply by annual hours
			   ELSE MIN(AveragePay) * @annualhours
			   END,
           AmcosVersionId
    FROM crunch.InventoryWASS
    WHERE AmcosVersionId = @AmcosVersionId
         
    GROUP BY PayPlan,
             GradeType,
             OccupationalSeriesNumber,
             LocationId,
             GradeLevel,
             AmcosVersionId;

	IF @Debug = 1
	BEGIN
		Select '421> Below listed any excessively large pay rates above $500,000'
		SELECT * FROM #PayMinMax WHERE MaxRate > 500000
	END

    /* AD pay plans have no payschedule so they are just whatever we already generated
       we only do this at the subgroup and location level though so the next step can generate the individual min/max */
    INSERT INTO #PayMinMax
    (
        PayPlan,
        GradeType,
        CategorySubgroupCode,
        LocationId,
        STRL,
        GradeLevel,
        MaxRate,
        MinRate,
        AmcosVersionId
    )
    SELECT PayPlan,
           GradeType,
           CategorySubgroupCode,
           LocationId,
           '-1',
           GradeLevel,
           Amount AS maxpay,
           Amount AS minpay,
           AmcosVersionId
    FROM data.Costs
    WHERE AmcosVersionId = @AmcosVersionId
          AND PayPlan = 'AD'
          AND LocationId <> -1
          AND CategorySubgroupCode <> '-1'
          AND CareerProgramNumber = '-1'
          AND CostElementName LIKE '%base%pay%';

	IF @Debug = 1
	BEGIN
		IF EXISTS(SELECT * FROM #PayMinMax WHERE MinRate IS NULL OR MaxRate IS NULL) BEGIN
			SELECT 'NULL MIN OR Max Rate found line 459'
		END 
		Select '462> Below listed any excessively large pay rates above $500,000'
		SELECT * FROM #PayMinMax WHERE MaxRate > 500000
	END

    --we need something slightly more complicated to add 2 weeks active pay to NG/R
    DECLARE @MonthsInAyear AS INT = 12;
    DECLARE @DaysInAMonth AS INT = 30;
    DECLARE @activedays AS INT = crunch.GetSingleValue('AA', 'activedays', @AmcosVersionId);

	IF @Debug = 1 BEGIN
		SELECT * FROM #PayMinMax AS a
        INNER JOIN
        (
            SELECT MIN(MinRate) AS MinRate,
                   MAX(MaxRate) AS MaxRate,
                   GradeType,
                   GradeLevel
            FROM #PayMinMax
            WHERE PayPlan IN ( 'AE', 'AO', 'AWO' )
            GROUP BY GradeType,
                     GradeLevel
        ) AS b
            ON a.GradeType = b.GradeType
               AND a.GradeLevel = b.GradeLevel
		WHERE a.PayPlan IN ( 'NO', 'NE', 'NWO', 'RE', 'RO', 'RWO' );
	END

    UPDATE #PayMinMax
    SET MinRate = a.MinRate + (b.MinRate / @MonthsInAyear / @DaysInAMonth * @activedays),
        MaxRate = a.MaxRate + (b.MaxRate / @MonthsInAyear / @DaysInAMonth * @activedays)
    FROM #PayMinMax AS a
        INNER JOIN
        (
            SELECT MIN(MinRate) AS MinRate,
                   MAX(MaxRate) AS MaxRate,
                   GradeType,
                   GradeLevel
            FROM #PayMinMax
            WHERE PayPlan IN ( 'AE', 'AO', 'AWO' )
            GROUP BY GradeType,
                     GradeLevel
        ) AS b
            ON a.GradeType = b.GradeType
               AND a.GradeLevel = b.GradeLevel
    WHERE a.PayPlan IN ( 'NO', 'NE', 'NWO', 'RE', 'RO', 'RWO' );

	IF @Debug = 1
	BEGIN
		Select '506> Below listed any excessively large pay rates above $500,000'
		SELECT * FROM #PayMinMax WHERE MaxRate > 500000
	END

    /* Anything else that is misisng a min/max is going to get assigned the min/max cost from the cost table as we are assuming it doesn't have a payschedule
    --if it doesn't have a value at this point */
    UPDATE #PayMinMax
    SET MinRate = b.Amount,
        MaxRate = b.Amount
    FROM #PayMinMax AS a
        INNER JOIN data.Costs AS b
            ON b.AmcosVersionId = a.AmcosVersionId
               AND b.CategorySubgroupCode = a.CategorySubgroupCode
               AND b.GradeLevel = a.GradeLevel
               AND b.LocationId = a.LocationId
               AND b.PayPlan = a.PayPlan
               AND b.Strl = a.STRL
    WHERE a.MinRate IS NULL
          AND a.MaxRate IS NULL
          AND b.CostElementName LIKE '%base%pay%';

	IF @Debug = 1
	BEGIN
		IF EXISTS(SELECT * FROM #PayMinMax WHERE MinRate IS NULL OR MaxRate IS NULL) BEGIN
			SELECT 'NULL MIN OR Max Rate found line 532'
		END 
	END

    DROP TABLE IF EXISTS #finaltable;
    CREATE TABLE #finaltable
    (
        PayPlan NVARCHAR(3) NOT NULL,
        CategoryGroupCode NVARCHAR(4) NOT NULL,
        CategorySubgroupCode NVARCHAR(5) NOT NULL,
        CareerProgramNumber NCHAR(2) NOT NULL,
        LocationId INT NOT NULL,
        STRL NVARCHAR(20) NOT NULL,
        GradeType NVARCHAR(3) NOT NULL,
        GradeLevel TINYINT NOT NULL,
        MinRate NUMERIC(16, 2) NULL,
        MaxRate NUMERIC(16, 2) NULL,
        AmcosVersionId INT NOT NULL,
        AggregationType NVARCHAR(50) NULL
    );
    INSERT INTO #finaltable
    (
        PayPlan,
        CategoryGroupCode,
        CategorySubgroupCode,
        CareerProgramNumber,
        LocationId,
        STRL,
        GradeType,
        GradeLevel,
        AmcosVersionId
    )
    --bring in a master list of all possible combinations from our cost table
    SELECT DISTINCT
           PayPlan,
           CategoryGroupCode,
           CategorySubgroupCode,
           CareerProgramNumber,
           LocationId,
           Strl,
           GradeType,
           GradeLevel,
           AmcosVersionId
    FROM data.Costs
    WHERE AmcosVersionId = @AmcosVersionId;

	IF @Debug = 1
	BEGIN
		IF EXISTS(SELECT * FROM #finaltable WHERE MinRate IS NULL OR MaxRate IS NULL) BEGIN
			SELECT 'NULL MIN OR Max Rate found line 581'
		END 
	END

    /* SES is a set min/max in ALL cases */
    UPDATE #finaltable
    SET MinRate =
        (
            SELECT MinPay
            FROM PaySchedule.OpmSesRaw
            WHERE RateType = 'Annual'
                  AND AmcosVersionId = @AmcosVersionId
        ),
        MaxRate =
        (
            SELECT MaxPay
            FROM PaySchedule.OpmSesRaw
            WHERE RateType = 'Annual'
                  AND AmcosVersionId = @AmcosVersionId
        )
    FROM #finaltable
    WHERE PayPlan = 'SES';
	IF @Debug = 1
	BEGIN
		IF EXISTS(SELECT * FROM #finaltable WHERE MinRate IS NULL OR MaxRate IS NULL) BEGIN
			SELECT 'NULL MIN OR Max Rate found line 606'
		END 
	END

    UPDATE #finaltable
    SET MinRate =
        (
            SELECT MinPay
            FROM PaySchedule.OpmSesRaw
            WHERE RateType = 'Annual'
                  AND AmcosVersionId = @AmcosVersionId
        ),
        MaxRate =
        (
            SELECT MaxPay
            FROM PaySchedule.OpmSesRaw
            WHERE RateType = 'Annual'
                  AND AmcosVersionId = @AmcosVersionId
        )
    FROM #finaltable
    WHERE PayPlan = 'SES';

	IF @Debug = 1
	BEGIN
		IF EXISTS(SELECT * FROM #finaltable WHERE MinRate IS NULL OR MaxRate IS NULL) BEGIN
			SELECT 'NULL MIN OR Max Rate found line 631'
		END 
	END
    --these pay plans use min/max like ses
    UPDATE #finaltable
    SET MinRate = b.minrate,
        MaxRate = b.maxrate
    FROM #finaltable AS a
        INNER JOIN
        (
            SELECT PayPlan,
                   GradeLevel,
                   AmcosVersionId,
                   MAX(Rate) AS maxrate,
                   MIN(Rate) AS minrate
            FROM data.PaySchedules
            WHERE RateType = 'Annual'
                  AND AmcosVersionId = @AmcosVersionId
            GROUP BY PayPlan,
                     GradeLevel,
                     AmcosVersionId
        ) AS b
            ON a.PayPlan = b.PayPlan
               AND a.GradeLevel = b.GradeLevel
               AND a.PayPlan IN ( 'EX', 'IE', 'IG', 'IP', 'SL', 'ST' );

			   IF @Debug = 1
	BEGIN
		IF EXISTS(SELECT * FROM #finaltable WHERE MinRate IS NULL OR MaxRate IS NULL) BEGIN
			SELECT 'NULL MIN OR Max Rate found line 660'
		END 
	END

    --Military is the same pay regardless of location
    UPDATE #finaltable
    SET MinRate = b.MinRate,
        MaxRate = b.MaxRate
    FROM #finaltable AS a
        INNER JOIN #PayMinMax AS b
            ON a.PayPlan = b.PayPlan
               AND a.GradeLevel = b.GradeLevel
        INNER JOIN lookup.PayPlanTags AS c
            ON c.PayPlan = a.PayPlan
               AND c.AmcosVersionId = a.AmcosVersionId
    WHERE c.Tag = 'Military';

    --GP is the base pay regardless, they do not get locality pay
    UPDATE #finaltable
    SET MinRate = b.MinRate,
        MaxRate = b.MaxRate
    FROM #finaltable AS a
        INNER JOIN #PayMinMax AS b
            ON a.PayPlan = b.PayPlan
               AND a.GradeLevel = b.GradeLevel
    WHERE a.PayPlan = 'GP';

	IF @Debug = 1
	BEGIN
		IF EXISTS(SELECT * FROM #finaltable WHERE MinRate IS NULL OR MaxRate IS NULL) BEGIN
			SELECT 'NULL MIN OR Max Rate found line 690'
		END 
	END

    --special pay scenarios
    UPDATE #finaltable
    SET MinRate = b.MinRate,
        MaxRate = b.MaxRate
    FROM #finaltable AS a
        INNER JOIN #PayMinMax AS b
            ON a.PayPlan = b.PayPlan
               AND a.GradeLevel = b.GradeLevel
               AND a.LocationId = b.LocationId
               AND a.CategorySubgroupCode = b.CategorySubgroupCode
    WHERE a.PayPlan IN
          (
              SELECT PayPlan FROM lookup.PayPlanTags WHERE Tag = 'SpecialPay'
          )
          AND a.CategorySubgroupCode <> '-1'
          AND a.MaxRate IS NULL
          AND a.LocationId <> -1; --only location specific scenarios allowed

    --MAX non special pay G series plans which would use simple location based
    UPDATE #finaltable
    SET --MinRate = b.MinRate,
        MaxRate = b.MaxRate
    FROM #finaltable AS a
        INNER JOIN #PayMinMax AS b
            ON a.PayPlan = b.PayPlan
               AND a.GradeLevel = b.GradeLevel
               AND a.LocationId = b.LocationId
    --subgroup doesn't matter for these
    WHERE a.PayPlan <> 'GP' --GP was already taken care of
          AND a.PayPlan LIKE 'G%' --any remaining G series pay plan
          AND
          (
              a.MaxRate IS NULL
              OR a.MaxRate < b.MaxRate
          ) --regular pay trumps special pay when it is higher
          AND b.CategorySubgroupCode = '-1' --nonspecial pay comes from the subgroup non-specific payschedules
          AND a.CategorySubgroupCode <> '-1' --don't set group level, we'll do that in the aggregation section later 
          AND a.LocationId <> -1 -- don't set location non-specific now, we'll do that later
          AND a.LocationId NOT IN
              (
                  SELECT LocationId
                  FROM warehouse.Location
                  WHERE LocationType = 'Civilian Overseas'
              ); --overseas is set later

	IF @Debug = 1
	BEGIN
		IF EXISTS(SELECT * FROM #finaltable WHERE MinRate IS NULL OR MaxRate IS NULL) BEGIN
			SELECT 'NULL MIN OR Max Rate found line 742'
		END 
	END
    --MIN non special pay G series plans which would use simple location based
    UPDATE #finaltable
    SET MinRate = b.MinRate --,
                            --MaxRate = b.MaxRate
    FROM #finaltable AS a
        INNER JOIN #PayMinMax AS b
            ON a.PayPlan = b.PayPlan
               AND a.GradeLevel = b.GradeLevel
               AND a.LocationId = b.LocationId
    --subgroup doesn't matter for these
    WHERE a.PayPlan <> 'GP' --GP was already taken care of
          AND a.PayPlan LIKE 'G%' --any remaining G series pay plan
          AND
          (
              a.MinRate IS NULL
              OR a.MinRate < b.MinRate
          ) --regular pay trumps special pay when it is higher
          AND b.CategorySubgroupCode = '-1' --nonspecial pay comes from the subgroup non-specific payschedules
          AND a.CategorySubgroupCode <> '-1' --don't set group level, we'll do that in the aggregation section later 
          AND a.LocationId <> -1 -- don't set location non-specific now, we'll do that later
          AND a.LocationId NOT IN
              (
                  SELECT LocationId
                  FROM warehouse.Location
                  WHERE LocationType = 'Civilian Overseas'
              ); --overseas is set later

    --overseas of G series where pay location is -1 and cost location floats
    --we can set all the min/max pays regardless of subgroup since they are all the same
    UPDATE #finaltable
    SET MinRate = b.MinRate,
        MaxRate = b.MaxRate
    FROM #finaltable AS a
        INNER JOIN #PayMinMax AS b
            ON a.PayPlan = b.PayPlan
               AND a.GradeLevel = b.GradeLevel
    --AND a.LocationId = b.LocationId
    --subgroup doesn't matter for these
    WHERE a.PayPlan <> 'GP' --GP was already taken care of
          AND a.PayPlan LIKE 'G%' --any remaining G series pay plan
          AND a.MaxRate IS NULL
          AND b.CategorySubgroupCode = '-1' --payschedule subgroups are fixed
          AND b.LocationId = -1 -- base pay applies to overseas
          AND a.LocationId IN
              (
                  SELECT LocationId
                  FROM warehouse.Location
                  WHERE LocationType = 'Civilian Overseas'
              );

    --Acq Demo which is location based
    UPDATE #finaltable
    SET MinRate = b.MinRate,
        MaxRate = b.MaxRate
    FROM #finaltable AS a
        INNER JOIN #PayMinMax AS b
            ON a.PayPlan = b.PayPlan
               AND a.GradeLevel = b.GradeLevel
               AND a.LocationId = b.LocationId
               AND a.STRL = b.STRL --included for completeness but the current values are -1
                                   --subgroup doesn't matter for these
    WHERE a.PayPlan IN
          (
              SELECT PayPlan FROM lookup.PayPlanTags WHERE Tag = 'Acq Demo'
          );
	IF @Debug = 1
	BEGIN
		IF EXISTS(SELECT * FROM #finaltable WHERE MinRate IS NULL OR MaxRate IS NULL) BEGIN
			SELECT 'NULL MIN OR Max Rate found line 813'
		END 
	END
    --Lab Demo which is location based and includes STRL
    UPDATE #finaltable
    SET MinRate = b.MinRate,
        MaxRate = b.MaxRate
    FROM #finaltable AS a
        INNER JOIN #PayMinMax AS b
            ON a.PayPlan = b.PayPlan
               AND a.GradeLevel = b.GradeLevel
               AND a.LocationId = b.LocationId
               AND a.STRL = b.STRL
    --subgroup doesn't matter for these
    WHERE a.PayPlan IN
          (
              SELECT PayPlan FROM lookup.PayPlanTags WHERE Tag = 'Lab Demo'
          );

    --Wage DMDC is location based and doesn't care about subgroups
    UPDATE #finaltable
    SET MinRate = b.MinRate,
        MaxRate = b.MaxRate
    FROM #finaltable AS a
        INNER JOIN #PayMinMax AS b
            ON a.PayPlan = b.PayPlan
               AND a.GradeLevel = b.GradeLevel
               AND a.LocationId = b.LocationId
               AND a.STRL = b.STRL
    --subgroup doesn't matter for these
    WHERE a.PayPlan IN
          (
              SELECT PayPlan
              FROM lookup.PayPlanTags
              WHERE Tag IN ( 'Wage AF', 'Wage NAF' ) --only wage plans
          )
          AND a.PayPlan IN
              (
                  SELECT PayPlan FROM lookup.PayPlanTags WHERE Tag = 'DMDC'
              ); --only those from dmdc

    --Wage WASS is location based and does care about subgroups since we use actuals as we don't have payschedules
    UPDATE #finaltable
    SET MinRate = b.MinRate,
        MaxRate = b.MaxRate
    FROM #finaltable AS a
        INNER JOIN #PayMinMax AS b
            ON a.PayPlan = b.PayPlan
               AND a.GradeLevel = b.GradeLevel
               AND a.LocationId = b.LocationId
               AND a.STRL = b.STRL
               AND a.CategorySubgroupCode = b.CategorySubgroupCode
    WHERE a.PayPlan IN
          (
              SELECT PayPlan
              FROM lookup.PayPlanTags
              WHERE Tag IN ( 'Wage AF', 'Wage NAF' ) --only wage plans
          )
          AND a.PayPlan IN
              (
                  SELECT PayPlan FROM lookup.PayPlanTags WHERE Tag = 'WASS'
              ); --only those from dmdc

    --finally set GFEBS county locations to the GS base pay equivalent for their respective pay schedules
    UPDATE #finaltable
    SET MinRate = b.MinRate,
        MaxRate = b.MaxRate
    FROM #finaltable AS a
        INNER JOIN #PayMinMax AS b
            ON b.AmcosVersionId = a.AmcosVersionId
               AND b.GradeLevel = a.GradeLevel
               AND b.PayPlan = a.PayPlan
               AND a.STRL = b.STRL
    WHERE b.LocationId = -1
          AND a.LocationId IN
              (
                  SELECT LocationId
                  FROM warehouse.Location AS a
                  WHERE a.LocationType = 'GFEBS Country'
              )
          AND a.CategorySubgroupCode <> '-1'
          AND b.CategorySubgroupCode = '-1'
          AND a.MaxRate IS NULL;

	IF @Debug = 1
	BEGIN
		IF EXISTS(SELECT * FROM #finaltable WHERE MinRate IS NULL OR MaxRate IS NULL) BEGIN
			SELECT 'NULL MIN OR Max Rate found line 900'
		END 
	END

    --ZZ pay plan is the min/max based on actual costs since there is no pay schedule for it
    UPDATE #finaltable
    SET MinRate = b.Amount,
        MaxRate = b.Amount
    FROM #finaltable AS a
        INNER JOIN
        (
            SELECT *
            FROM data.Costs
            WHERE --AmcosVersionId=@AmcosVersionId and
                PayPlan = 'ZZ'
                AND CostElementName LIKE '%base%pay%'
        ) AS b
            ON a.PayPlan = b.PayPlan
               AND a.GradeLevel = b.GradeLevel
               AND a.LocationId = b.LocationId;

    --#### Now we've completed the initial setting of all subgroup level min/max at a minimum
    --we now need to move on to min/max at the aggregate level for instances we haven't already set

    --SELECT MAX(MaxRate) AS maxrate,
    --       MIN(MinRate) AS minrate,
    --       PayPlan,
    --       GradeLevel,
    --       LocationId,
    --       STRL,
    --       --,CategorySubgroupCode
    --       CategoryGroupCode
    ----,CareerProgramNumber
    --FROM #finaltable
    --WHERE CategorySubgroupCode <> '-1' --only min/max of subgroups
    --      AND PayPlan = 'NH'
    --      AND CategoryGroupCode = '0200'
    --      AND GradeLevel = 2
    --      AND LocationId = 1021
    --GROUP BY PayPlan,
    --         GradeLevel,
    --         LocationId,
    --         STRL,
    --         --,CategorySubgroupCode
    --         CategoryGroupCode;

    --### Subgroup ###
    -- subgroup without location
    UPDATE #finaltable
    SET MinRate = b.minrate,
        MaxRate = b.maxrate
    FROM #finaltable AS a
        INNER JOIN
        (
            SELECT MAX(MaxRate) AS maxrate,
                   MIN(MinRate) AS minrate,
                   PayPlan,
                   GradeLevel,
                   STRL,
                   CategorySubgroupCode
            FROM #PayMinMax
            WHERE CategorySubgroupCode <> '-1' --only min/max of subgroups
            GROUP BY PayPlan,
                     GradeLevel,
                     --LocationId,
                     STRL,
                     CategorySubgroupCode
        ) AS b
            ON a.PayPlan = b.PayPlan
               AND a.GradeLevel = b.GradeLevel
               AND a.STRL = b.STRL
               AND a.CategorySubgroupCode = b.CategorySubgroupCode
    WHERE a.MinRate IS NULL
          AND a.MaxRate IS NULL
          AND a.LocationId = -1;


    --### GROUP ###
    -- group with location
    UPDATE #finaltable
    SET MinRate = b.minrate,
        MaxRate = b.maxrate
    FROM #finaltable AS a
        INNER JOIN
        (
            SELECT MAX(MaxRate) AS maxrate,
                   MIN(MinRate) AS minrate,
                   PayPlan,
                   GradeLevel,
                   LocationId,
                   STRL,
                   CategoryGroupCode
            FROM #finaltable
            WHERE CategorySubgroupCode <> '-1' --only min/max of subgroups
            GROUP BY PayPlan,
                     GradeLevel,
                     LocationId,
                     STRL,
                     CategoryGroupCode
        ) AS b
            ON a.PayPlan = b.PayPlan
               AND a.GradeLevel = b.GradeLevel
               AND a.LocationId = b.LocationId
               AND a.STRL = b.STRL
               AND a.CategoryGroupCode = b.CategoryGroupCode
    WHERE a.MinRate IS NULL
          AND a.MaxRate IS NULL
          AND a.CategorySubgroupCode = '-1' --only set group level data
          AND a.CategoryGroupCode <> '-1'; --only set group level data

	IF @Debug = 1
	BEGIN
		IF EXISTS(SELECT * FROM #finaltable WHERE MinRate IS NULL OR MaxRate IS NULL) BEGIN
			SELECT 'NULL MIN OR Max Rate found line 1013'
		END 
	END

    --group without location
    UPDATE #finaltable
    SET MinRate = b.minrate,
        MaxRate = b.maxrate
    FROM #finaltable AS a
        INNER JOIN
        (
            SELECT MAX(MaxRate) AS maxrate,
                   MIN(MinRate) AS minrate,
                   PayPlan,
                   GradeLevel,
                   STRL,
                   CategoryGroupCode
            FROM #finaltable
            GROUP BY PayPlan,
                     GradeLevel,
                     STRL,
                     CategoryGroupCode
        ) AS b
            ON a.PayPlan = b.PayPlan
               AND a.GradeLevel = b.GradeLevel
               AND a.STRL = b.STRL
               AND a.CategoryGroupCode = b.CategoryGroupCode
    WHERE a.MinRate IS NULL
          AND a.MaxRate IS NULL
          AND a.CategoryGroupCode <> '-1' --the group needs to exist for this set
          AND a.CategorySubgroupCode = '-1' --group average
          AND a.LocationId = -1;

    --#### PAY PLAN ####
    --pp with location
    UPDATE #finaltable
    SET MinRate = b.minrate,
        MaxRate = b.maxrate
    FROM #finaltable AS a
        INNER JOIN
        (
            SELECT MAX(MaxRate) AS maxrate,
                   MIN(MinRate) AS minrate,
                   PayPlan,
                   GradeLevel,
                   LocationId,
                   STRL
            FROM #finaltable
            GROUP BY PayPlan,
                     GradeLevel,
                     LocationId,
                     STRL
        ) AS b
            ON a.PayPlan = b.PayPlan
               AND a.GradeLevel = b.GradeLevel
               AND a.LocationId = b.LocationId
               AND a.STRL = b.STRL
    WHERE a.MinRate IS NULL
          AND a.MaxRate IS NULL
          AND a.CategoryGroupCode = '-1' --payplan level costs only set on this one
          AND a.LocationId <> -1; --only set location specific costs for this

    --pp wihout location
    UPDATE #finaltable
    SET MinRate = b.minrate,
        MaxRate = b.maxrate
    FROM #finaltable AS a
        INNER JOIN
        (
            SELECT MAX(MaxRate) AS maxrate,
                   MIN(MinRate) AS minrate,
                   PayPlan,
                   GradeLevel,
                   STRL
            FROM #finaltable
            GROUP BY PayPlan,
                     GradeLevel,
                     STRL
        ) AS b
            ON a.PayPlan = b.PayPlan
               AND a.GradeLevel = b.GradeLevel
               AND a.STRL = b.STRL
    WHERE a.MinRate IS NULL
          AND a.MaxRate IS NULL
          AND a.LocationId = -1;

    --#### CAREER PROGRAMS ####
    -- cp with location
    UPDATE #finaltable
    SET MinRate = b.minrate,
        MaxRate = b.maxrate
    FROM #finaltable AS a
        INNER JOIN
        (
            SELECT MAX(MaxRate) AS maxrate,
                   MIN(MinRate) AS minrate,
                   PayPlan,
                   GradeLevel,
                   LocationId,
                   STRL,
                   CareerProgramNumber
            FROM #finaltable
            GROUP BY PayPlan,
                     GradeLevel,
                     LocationId,
                     STRL,
                     CareerProgramNumber
        ) AS b
            ON a.PayPlan = b.PayPlan
               AND a.GradeLevel = b.GradeLevel
               AND a.LocationId = b.LocationId
               AND a.STRL = b.STRL
               AND a.CareerProgramNumber = b.CareerProgramNumber
    WHERE a.MinRate IS NULL
          AND a.MaxRate IS NULL
          AND a.CareerProgramNumber <> -1
          AND a.LocationId <> -1;

		IF @Debug = 1
	BEGIN
		IF EXISTS(SELECT * FROM #finaltable WHERE MinRate IS NULL OR MaxRate IS NULL) BEGIN
			SELECT 'NULL MIN OR Max Rate found line 1134'
		END 
	END

    -- cp without location
    UPDATE #finaltable
    SET MinRate = b.minrate,
        MaxRate = b.maxrate
    FROM #finaltable AS a
        INNER JOIN
        (
            SELECT MAX(MaxRate) AS maxrate,
                   MIN(MinRate) AS minrate,
                   PayPlan,
                   GradeLevel,
                   STRL,
                   CareerProgramNumber
            FROM #finaltable
            GROUP BY PayPlan,
                     GradeLevel,
                     STRL,
                     CareerProgramNumber
        ) AS b
            ON a.PayPlan = b.PayPlan
               AND a.GradeLevel = b.GradeLevel
               AND a.STRL = b.STRL
               AND a.CareerProgramNumber = b.CareerProgramNumber
    WHERE a.MinRate IS NULL
          AND a.MaxRate IS NULL
          AND a.CareerProgramNumber <> -1
          AND a.LocationId = -1;


    -- now just a handful of nulls probably remain
    --what remains are location fill in the blanks where there are no underlying inventory
    --this is so users can cost a location where no inventory current exists
    --since there is nothing below the payplan level at that location we need to pull in the payschedule for it
    UPDATE #finaltable
    SET MinRate = b.MinRate,
        MaxRate = b.MaxRate
    FROM #finaltable AS a
        INNER JOIN #PayMinMax AS b
            ON a.PayPlan = b.PayPlan
               AND a.GradeLevel = b.GradeLevel
               AND a.LocationId = b.LocationId
    WHERE a.MinRate IS NULL
          AND a.MaxRate IS NULL;

    IF @Debug = 1
    BEGIN
        SELECT 'beginning table';
        SELECT *
        FROM #PayMinMax
        WHERE PayPlan = 'NA'
              AND LocationId = 2418
              AND CategorySubgroupCode = '-1';

        SELECT 'final table';
        SELECT *
        FROM #finaltable
        WHERE PayPlan = 'NA'
              AND LocationId = 2418
              AND CategorySubgroupCode = '-1';
    END;

    SELECT 'If there are any base pay amounts outside the min/max they will appear here';
    SELECT a.amount,
           b.MinRate,
           b.MaxRate,
           c.DisplayName,
           a.CategorySubgroupCode,
           a.GradeLevel,
           *
    FROM
    (
        SELECT PayPlan,
               CategoryGroupCode,
               CategorySubgroupCode,
               CareerProgramNumber,
               LocationId,
               Strl,
               WeaponSystemId,
               GradeType,
               GradeLevel,
               DependentStatus,
               NumberOfDependents,
               AmcosVersionId,
               SUM(Amount) AS amount
        FROM data.Costs
        WHERE (
                  CostElementName LIKE '%base pay (%'
                  OR CostElementName LIKE '%civ locality%'
              ) --handles both base pay and GFEBS locality pay
              AND AmcosVersionId = @AmcosVersionId
        GROUP BY PayPlan,
                 CategoryGroupCode,
                 CategorySubgroupCode,
                 CareerProgramNumber,
                 LocationId,
                 Strl,
                 WeaponSystemId,
                 GradeType,
                 GradeLevel,
                 DependentStatus,
                 NumberOfDependents,
                 AmcosVersionId
    ) AS a
        LEFT OUTER JOIN #finaltable AS b
            ON b.AmcosVersionId = a.AmcosVersionId
               AND b.LocationId = a.LocationId
               AND b.CareerProgramNumber = a.CareerProgramNumber
               AND b.CategoryGroupCode = a.CategoryGroupCode
               AND b.CategorySubgroupCode = a.CategorySubgroupCode
               AND b.GradeLevel = a.GradeLevel
               AND b.PayPlan = a.PayPlan
               AND b.STRL = a.Strl
        LEFT OUTER JOIN warehouse.Location AS c
            ON c.LocationId = a.LocationId
    WHERE (
              a.amount > b.MaxRate
              OR a.amount < b.MinRate
          )
          AND a.AmcosVersionId = @AmcosVersionId;


    SELECT 'Missing values';
    IF EXISTS
    (
        SELECT PayPlan,
               CategoryGroupCode,
               CategorySubgroupCode,
               CareerProgramNumber,
               LocationId,
               STRL,
               GradeLevel,
               MinRate,
               MaxRate,
               AmcosVersionId,
               AggregationType
        FROM #finaltable
        WHERE MinRate IS NULL
              OR MaxRate IS NULL
    )
    BEGIN
        SELECT 'These records are missing a min/max pay amount which is not allowed';
        SELECT PayPlan,
               COUNT(CategoryGroupCode) AS num
        FROM #finaltable
        WHERE MinRate IS NULL
              OR MaxRate IS NULL
        GROUP BY PayPlan
        ORDER BY PayPlan;

        SELECT PayPlan,
               CategoryGroupCode,
               CategorySubgroupCode,
               CareerProgramNumber,
               LocationId,
               STRL,
               GradeLevel,
               MinRate,
               MaxRate,
               AmcosVersionId,
               AggregationType
        FROM #finaltable
        WHERE MinRate IS NULL
              OR MaxRate IS NULL
        ORDER BY PayPlan,
                 CategoryGroupCode,
                 CategorySubgroupCode;
		DELETE FROM #finaltable WHERE MinRate IS NULL OR MaxRate IS NULL;
       -- RAISERROR('Missing a min/max pay amount', 18, -1);
        --RETURN;
    END;

    IF @Debug = 0
    BEGIN
        DELETE FROM crunch.PayScheduleMinMax
        WHERE AmcosVersionId = @AmcosVersionId;

        INSERT INTO crunch.PayScheduleMinMax
        (
            PayPlan,
            CategoryGroupCode,
            CategorySubgroupCode,
            CareerProgramNumber,
            LocationId,
            STRL,
            GradeType,
            GradeLevel,
            MinRate,
            MaxRate,
            AmcosVersionId,
            Appropriation
        )
        SELECT a.PayPlan,
               a.CategoryGroupCode,
               a.CategorySubgroupCode,
               a.CareerProgramNumber,
               a.LocationId,
               a.STRL,
               a.GradeType,
               a.GradeLevel,
               a.MinRate,
               a.MaxRate,
               a.AmcosVersionId,
               b.APPN
        FROM #finaltable AS a
            --inflation needs the APPN so we bring it in and conform to JIC APPN names
            LEFT OUTER JOIN
            (
                SELECT DISTINCT
                       PayPlan,
                       APPN
                FROM lookup.CostElement
                WHERE @AmcosVersionId
                      BETWEEN AmcosVersionIdStart AND AmcosVersionIdEnd
                      AND
                      (
                          CostElementName LIKE '%base pay%'
                          OR CostElementName LIKE '%civ hourly%'
                      )
            ) AS b
                ON a.PayPlan = b.PayPlan;


    END;

END;