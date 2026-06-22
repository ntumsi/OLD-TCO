-- Stored Procedure

-- =============================================
-- Author:		Dan Hogan
-- Create date: 11/4/2019
-- Description:	Crunch Proc for GFEBs based pay plans
-- Edits:
--		- 3/10/2020 - added filter to remove records which are unreasonably outside of the bounds of the appropriate pay schedule
--      - 7/2022 - added code to account for 10 new GFEBS based pay plans
-- =============================================
CREATE PROCEDURE [crunch].[CrunchGFEBS]
    @AmcosVersionId INT = -1,
    @CrunchTime AS SMALLDATETIME = NULL,
    @debug BIT = 0
AS
BEGIN
    SET NOCOUNT ON;

    /*  Could just use zero but this allows for setting it to some huge negative number for testing to find where we have nulls being replaced by zeros */
    DECLARE @ZeroValue INT = 0;
    /*  GFEBS uses 2080 take amountpaid*26/hourly rate = 2080 */
    DECLARE @AnnualHours NUMERIC(18, 2) = 2080;
    DECLARE @IsValidAmcosVersion BIT = crunch.ValidateAmcosVersion(@AmcosVersionId);

    IF (@IsValidAmcosVersion = 0)
        RETURN 0;

    IF (@CrunchTime IS NULL)
        SET @CrunchTime = CONVERT(SMALLDATETIME, GETDATE());

    DROP TABLE IF EXISTS #WorkInProgress;
    CREATE TABLE #WorkInProgress
    (
        PayPlan NVARCHAR(3) NOT NULL,
        OccupationalGroupNumber NVARCHAR(4) NOT NULL,
        OccupationalSeriesNumber NVARCHAR(4) NOT NULL,
        Country NVARCHAR(50) NOT NULL,
        UICUCForManpower NVARCHAR(50) NULL,
        STRL NVARCHAR(20) NOT NULL
            DEFAULT ('-1'),
        STRLName NVARCHAR(200) NOT NULL
            DEFAULT ('-1'),
        GradeLevel TINYINT NOT NULL,
        PayPeriodEndDate DATE NOT NULL,
        PersonnelNumber NVARCHAR(10) NOT NULL,
        CostElementCode NVARCHAR(50) NOT NULL,
        AmountPaid NUMERIC(18, 4) NULL,
        PaidHours NUMERIC(18, 4) NULL,
        ActualHourlyRate NUMERIC(18, 4) NULL,
        OriginalHourlyRate NUMERIC(18, 4) NULL,
        LocalityCode NVARCHAR(6) NULL,
        LocalityRate NUMERIC(18, 2) NULL,
        PayScheduleMin NUMERIC(18, 4) NULL,
        PayScheduleMax NUMERIC(18, 4) NULL,
        LocationId INT NULL,
        AmcosVersionId INT NOT NULL,
        ExcludeRecord BIT NOT NULL
            DEFAULT 0,
        Step INT NOT NULL
    );
    INSERT INTO #WorkInProgress
    (
        PayPlan,
        OccupationalGroupNumber,
        OccupationalSeriesNumber,
        Country,
        UICUCForManpower,
        LocalityCode,
        GradeLevel,
        PayPeriodEndDate,
        PersonnelNumber,
        CostElementCode,
        AmountPaid,
        PaidHours,
        ActualHourlyRate,
        OriginalHourlyRate,
        AmcosVersionId,
        Step
    )
    SELECT PayPlan,
           OccupationalGroupNumber,
           OccupationalSeriesNumber,
           Country,
           UICUCForManpower,
           LocalityCode,
           GradeLevel,
           PayPeriodEndDate,
           PersonnelNumber,
           CostElementCode,
           SUM(AmountPaid) AS amountpaid,
           SUM(PaidHours) AS PaidHours,
           MAX(ActualHourlyRate) AS maxrate,
           MAX(ActualHourlyRate) AS maxrate,
           AmcosVersionId,
           ISNULL(CAST(Step AS INT), -1)
    FROM load_GFEBS.Cleaned
    WHERE AmcosVersionId = @AmcosVersionId
    GROUP BY PayPlan,
             OccupationalGroupNumber,
             OccupationalSeriesNumber,
             Country,
             UICUCForManpower,
             LocalityCode,
             ActivityTypeCode,
             GradeLevel,
             Step,
             PayPeriodEndDate,
             PersonnelNumber,
             CostElementCode,
             AmcosVersionId;


    --bring in STRL for D series plans
    UPDATE #WorkInProgress
    SET STRL = b.STRL,
        STRLName = b.STRLName
    FROM #WorkInProgress AS a
        INNER JOIN xwalk.UICToSTRL AS b
            ON LEFT(a.UICUCForManpower, 4) = b.UIC
               AND a.AmcosVersionId
               BETWEEN b.AmcosVersionIdStart AND b.AmcosVersionIdEnd
    WHERE a.PayPlan LIKE 'D%';



    --delete data for unknown STRLs
    DELETE FROM #WorkInProgress
    WHERE STRLName = 'Unknown'
          AND PayPlan LIKE 'D%';

    --bring in locality pay amount
    UPDATE #WorkInProgress
    SET LocalityRate = b.LocalityRate
    FROM #WorkInProgress AS a
        INNER JOIN PaySchedule.LocalityPay AS b
            ON a.LocalityCode = b.LocalityCode
               AND a.AmcosVersionId = b.AmcosVersionId
    WHERE a.LocalityCode <> '-1';


    --bring in locality pay area location data
    UPDATE #WorkInProgress
    SET LocationId = b.LocationId
    FROM #WorkInProgress AS a
        INNER JOIN warehouse.Location AS b
            ON a.LocalityCode = b.SourceSystemCode
    WHERE b.LocationType = 'Locality Pay Area'
          AND a.LocalityCode <> '-1';

    --bring in Country location data
    UPDATE #WorkInProgress
    SET LocationId = b.LocationId
    FROM #WorkInProgress AS a
        INNER JOIN warehouse.Location AS b
            ON a.Country = b.SourceSystemCode
    WHERE b.LocationType = 'GFEBS Country'
          AND a.LocationId IS NULL
          AND a.Country <> '-1';

    IF EXISTS
    (
        SELECT DISTINCT
               UICUCForManpower
        FROM #WorkInProgress
        WHERE PayPlan LIKE 'D%'
              AND
              (
                  STRL IS NULL
                  OR STRL = '-1'
              )
    )
    BEGIN
        SELECT 'These records are missing an STRL.  To fix add to xwalk.UICToSTRL.  Use unknown if not known.';
        SELECT DISTINCT
               a.UICUCForManpower,
               b.*
        FROM #WorkInProgress AS a
            LEFT OUTER JOIN lookup.UIC AS b
                ON a.UICUCForManpower = b.UIC
        WHERE a.PayPlan LIKE 'D%'
              AND
              (
                  a.STRL IS NULL
                  OR a.STRL = '-1'
              );

        RAISERROR('Missing UIC TO STRL', 18, 1);
        RETURN 0;
    END;

    -- bring in payschedule data for D/N series
    UPDATE #WorkInProgress
    SET PayScheduleMin = b.[1],
        PayScheduleMax = b.[10]
    FROM #WorkInProgress AS a
        INNER JOIN
        -- get the min/max amount from the payschedule data; 1 is the lowerst (think Step 1 for GS, while 10 is the highest Step
        -- Step isn't really a concept in D/N series data but since they are based on GS schedule it makes sense to use that reference
        (
            SELECT PayPlan,
                   LocationId,
                   Strl,
                   GradeLevel,
                   [1],
                   [10]
            FROM data.PaySchedules
                PIVOT
                (
                    MAX(Rate)
                    FOR Step IN ([1], [10])
                ) AS pvt
            WHERE AmcosVersionId = @AmcosVersionId
                  AND pvt.CategorySubgroupCode = '-1' -- we don't want any payschedule data for specific subgroups, those are special pay and don't
                  AND
                  (
                      PayPlan LIKE 'D%'
                      OR PayPlan IN ( 'NK', 'NJ', 'NH' )
                  )
        ) AS b
            ON a.PayPlan = b.PayPlan
               AND a.LocationId = b.LocationId
               AND a.STRL = b.STRL
               AND a.GradeLevel = b.GradeLevel
    WHERE a.CostElementCode = '6100.11B1'; --for this we ONLY care about base pay since payschedules are base pay only

    -- bring in payschedule data for GP
    UPDATE #WorkInProgress
    SET PayScheduleMin = b.[1],
        PayScheduleMax = b.[10]
    FROM #WorkInProgress AS a
        INNER JOIN
        -- get the min/max amount from the payschedule data; 1 is the lowest (think Step 1 for GS, while 10 is the highest Step
        -- Step isn't really a concept in D/N series data but since they are based on GS schedule it makes sense to use that reference
        (
            SELECT PayPlan,
                   LocationId,
                   Strl,
                   GradeLevel,
                   [1],
                   [10]
            FROM data.PaySchedules
                PIVOT
                (
                    MAX(Rate)
                    FOR Step IN ([1], [10])
                ) AS pvt
            WHERE AmcosVersionId = @AmcosVersionId
                  AND pvt.CategorySubgroupCode = '-1' -- we don't want any payschedule data for specific subgroups, those are special pay and don't
                  AND (PayPlan = 'GP')
        ) AS b
            ON a.PayPlan = b.PayPlan
               AND a.STRL = b.STRL
               AND a.GradeLevel = b.GradeLevel
    WHERE a.CostElementCode = '6100.11B1'; --for this we ONLY care about base pay since payschedules are base pay only



    --bring in the pay schedule for some other pay plans which don't vary by locationid
    UPDATE #WorkInProgress
    --some pay plans have only a max in which case we set the min to be 0, the others are a set amount which means max=min
    SET PayScheduleMin = CASE
                             WHEN a.PayPlan IN ( 'IE', 'IP', 'ST', 'SL' ) THEN
                                 0
                             ELSE
                                 b.Rate
                         END,
        PayScheduleMax = b.Rate
    FROM #WorkInProgress AS a
        INNER JOIN
        (
            SELECT *
            FROM data.PaySchedules p
            WHERE p.AmcosVersionId = @AmcosVersionId
                  AND p.PayPlan IN ( 'EX', 'IG', 'IE', 'IP', 'SL', 'ST' )
                  AND p.RateType = 'Annual'
        ) AS b
            ON a.PayPlan = b.PayPlan
               AND a.STRL = b.Strl
               AND a.GradeLevel = b.GradeLevel
    WHERE a.CostElementCode = '6100.11B1'; --for this we ONLY care about base pay since payschedules are base pay only





    --these payschedules vary by locationid
    UPDATE #WorkInProgress
    --some pay plans have only a max in which case we set the min to be 0, the others are a set amount which means max=min
    SET PayScheduleMin = CASE
                             WHEN a.PayPlan IN ( 'EE', 'EF' ) THEN
                                 0
                             ELSE
                                 b.Rate
                         END,
        PayScheduleMax = b.Rate
    FROM #WorkInProgress AS a
        INNER JOIN
        (
            SELECT *
            FROM data.PaySchedules
            WHERE AmcosVersionId = @AmcosVersionId
                  AND PayPlan IN ( 'CA', 'EE', 'EF' )
                  AND RateType = 'Annual'
        ) AS b
            ON a.PayPlan = b.PayPlan
               AND a.LocationId = b.LocationId
               AND a.STRL = b.Strl
               AND a.GradeLevel = b.GradeLevel
    WHERE a.CostElementCode = '6100.11B1'; --for this we ONLY care about base pay since payschedules are base pay only


    -- pay just over the max is set to the max
    UPDATE #WorkInProgress
    SET ActualHourlyRate = PayScheduleMax / @AnnualHours
    --round function used in the above way so we end up slightly below the max, otherwise we end up fighting precision because
    --we can't get enough decimal places to make it precise enough that when annualized it isn't back over the max
    WHERE CostElementCode = '6100.11B1'
          AND (ActualHourlyRate * @AnnualHours) > PayScheduleMax
          AND ((ActualHourlyRate * @AnnualHours) / PayScheduleMax) <= 1.025;


    -- pay just under the min is set to the min
    UPDATE #WorkInProgress
    SET ActualHourlyRate = PayScheduleMax / @AnnualHours
    -- round in the roundup form used here works since we want to be just above the min
    WHERE CostElementCode = '6100.11B1'
          AND ActualHourlyRate * @AnnualHours < PayScheduleMin
          AND (ActualHourlyRate * @AnnualHours) / PayScheduleMin >= 0.975;

    -- when the annualized max hourly rate is outside the bounds of known pay schedules then we eliminate that record
    -- we'd prefer to keep them but we can't let them skew the numbers and so we reject them

	UPDATE #WorkInProgress
	SET ExcludeRecord = 1
	WHERE CostElementCode = '6100.11B1'
	  AND PayPlan NOT IN ('AD','ZZ','EX','EF','EE')
	  AND
	  (
		  /* Normalize annual pay to whole dollars first */
		  CONVERT(INT,
			  ROUND(
				  CAST(ActualHourlyRate AS decimal(10,4)) * @AnnualHours,
				  0
			  )
		  )
		  NOT BETWEEN
			  FLOOR(PayScheduleMin)
			  AND CEILING(PayScheduleMax)
	  )

    --UPDATE #WorkInProgress
    --SET ExcludeRecord = 1
    --WHERE CostElementCode = '6100.11B1'
    --      AND ISNULL(CONVERT(INT, ROUND((ActualHourlyRate * @AnnualHours), 0, -1)), 0) NOT
    --      BETWEEN ISNULL(FLOOR(PayScheduleMin), 0) AND ISNULL(CEILING(PayScheduleMax), 0)
    --      --AND Country = '-1' -- 20220826 overseas do have a base pay amount now that should be = GS Base 
    --      AND PayPlan NOT IN ( 'AD', 'ZZ', 'EX', 'EF', 'EE' ); --we don't have a payschedule for AD/ZZ pay plans so we ignore those values
    --                                                           --EX is in the above list because of a pay freeze that disconnected it from the latest EX schedule
    --                                                           --EE and EF has seen pay well above what the regulation says is allowed but in this case we trust GFEBS as there can be hard to find granted exceptions so we let it in

    -- 20220826 the above was removing base pay records but not removing the entire personnel record too, the below fixed that
    UPDATE #WorkInProgress
    SET ExcludeRecord = 1
    FROM #WorkInProgress
    WHERE PersonnelNumber IN
          (
              SELECT DISTINCT
                     PersonnelNumber
              FROM #WorkInProgress
              WHERE ExcludeRecord = 1
          );



    IF @debug = 1
    BEGIN
        SELECT 'these records pay outside of the payschedule bounds';

        SELECT CASE
                   WHEN ActualHourlyRate * @AnnualHours > PayScheduleMax THEN
            ((ActualHourlyRate * @AnnualHours) / PayScheduleMax)
                   WHEN ActualHourlyRate * @AnnualHours < PayScheduleMin THEN
            ((ActualHourlyRate * @AnnualHours) / PayScheduleMin)
               END AS percdif,
               PayScheduleMax,
               ActualHourlyRate * @AnnualHours AS annualized_hrly_rate,
               PayScheduleMin,
               *
        FROM #WorkInProgress
        WHERE ExcludeRecord = 1
              AND CostElementCode LIKE '%11b%'
        --payplan='DJ' and gradelevel=5
        ORDER BY CASE
                     WHEN ActualHourlyRate * @AnnualHours > PayScheduleMax THEN
            ((ActualHourlyRate * @AnnualHours) / PayScheduleMax)
                     WHEN ActualHourlyRate * @AnnualHours < PayScheduleMin THEN
            ((ActualHourlyRate * @AnnualHours) / PayScheduleMin)
                 END;

    END;

    --in 2020 we found a 602 series DB who did get '6100.11T0' and one who did not, D/N do not get market pay so we remove that record
    UPDATE #WorkInProgress
    SET ExcludeRecord = 1
    WHERE PersonnelNumber IN
          (
              SELECT PersonnelNumber
              WHERE PayPlan LIKE 'D%'
                    AND CostElementCode = '6100.11T0'
          );
	IF @Debug = 1 BEGIN
		SELECT 'Line 404'
		SELECT * from #WorkInProgress 
		WHERE Payplan in ('IG', 'CA')
	END


    --delete all records that now need to be excluded

    DELETE FROM #WorkInProgress
    WHERE PersonnelNumber IN
          (
              SELECT DISTINCT
                     PersonnelNumber
              FROM #WorkInProgress
              WHERE ExcludeRecord = 1
          );

    -- we now have the records we are going to use for cost calculations so those should also go right into inventory
    IF @debug = 1
    BEGIN
		Select 'IG and CA Inventory'
		SELECT * from #WorkInProgress where payplan in ('CA','IG')


        SELECT 'inventory summary';
        SELECT PayPlan,
               SUM(Inventory) AS Inventory
        FROM
        (
            SELECT DISTINCT
                   PersonnelNumber,
                   PayPlan,
                   OccupationalGroupNumber,
                   OccupationalSeriesNumber,
                   LocationId,
                   STRL,
                   PayPlan AS gradetype,
                   GradeLevel,
                   Step,
                   1 AS Inventory
            FROM #WorkInProgress
            WHERE CostElementCode IN ( '6100.11B1', '6100.11B3' )
        ) AS a
        GROUP BY PayPlan
        ORDER BY PayPlan;

        SELECT 'inventory table';
        SELECT PayPlan,
               OccupationalGroupNumber,
               OccupationalSeriesNumber,
               LocationId,
               STRL,
               gradetype,
               GradeLevel,
               Step,
               -1 AS YOS,
               SUM(Inventory) AS Inventory,
               @AmcosVersionId
        FROM
        (
            SELECT DISTINCT
                   PersonnelNumber,
                   PayPlan,
                   OccupationalGroupNumber,
                   OccupationalSeriesNumber,
                   LocationId,
                   STRL,
                   PayPlan AS gradetype,
                   GradeLevel,
                   Step,
                   1 AS Inventory
            FROM #WorkInProgress
            WHERE (
                      CostElementCode = '6100.11B1'
                      AND PayPlan <> 'AD'
                  )
                  --3/8/2022 added the following so more AD inventory makes it into the inventory table
                  --7/15/2022 added new pps which use B3
                  OR
                  (
                      CostElementCode IN ( '6100.11B1', '6100.11B3' )
                      AND PayPlan IN ( 'AD', 'EF', 'EE', 'IP' )
                  )
        ) AS a
        GROUP BY PayPlan,
                 OccupationalGroupNumber,
                 OccupationalSeriesNumber,
                 LocationId,
                 STRL,
                 gradetype,
                 GradeLevel,
                 Step;

    END;
    IF @debug = 0
    BEGIN
        DELETE FROM crunch.InventoryGFEBS
        WHERE AmcosVersionId = @AmcosVersionId;

        INSERT INTO crunch.InventoryGFEBS
        (
            PayPlan,
            OccupationalGroupNumber,
            OccupationalSeriesNumber,
            LocationId,
            STRL,
            GradeType,
            GradeLevel,
            Step,
            YOS,
            Inventory,
            AmcosVersionId
        )
        SELECT PayPlan,
               OccupationalGroupNumber,
               OccupationalSeriesNumber,
               LocationId,
               STRL,
               gradetype,
               GradeLevel,
               Step,
               -1,
               SUM(Inventory),
               @AmcosVersionId
        FROM
        (
            SELECT DISTINCT
                   PersonnelNumber,
                   PayPlan,
                   OccupationalGroupNumber,
                   OccupationalSeriesNumber,
                   LocationId,
                   STRL,
                   PayPlan AS gradetype,
                   GradeLevel,
                   Step,
                   1 AS Inventory
            FROM #WorkInProgress
            WHERE (
                      CostElementCode = '6100.11B1'
                      AND PayPlan <> 'AD'
                  )
                  --3/8/2022 added the following so more AD inventory makes it into the inventory table
                  --7/15/2022 added new pps which use B3
                  OR
                  (
                      CostElementCode IN ( '6100.11B1', '6100.11B3' )
                      AND PayPlan IN ( 'AD', 'EF', 'EE', 'IP' )
                  )
        ) AS a
        GROUP BY PayPlan,
                 OccupationalGroupNumber,
                 OccupationalSeriesNumber,
                 LocationId,
                 STRL,
                 gradetype,
                 GradeLevel,
                 Step;
    END;

    IF @debug = 1
    BEGIN
        SELECT 'remaining base pay records';
        SELECT @AnnualHours * ActualHourlyRate,
               PayScheduleMin,
               PayScheduleMax AS payschedulemax1,
               GradeLevel AS GL,
               *
        FROM #WorkInProgress
        WHERE CostElementCode = '6100.11B1'
        ORDER BY PayScheduleMax,
                 PayPlan,
                 GradeLevel;
    END;


    DROP TABLE IF EXISTS #Cost;
    CREATE TABLE #Cost
    (
        PayPlan NVARCHAR(3) NOT NULL,
        OccupationalGroupNumber NVARCHAR(4) NOT NULL,
        OccupationalSeriesNumber NVARCHAR(4) NOT NULL,
        Country NVARCHAR(50) NULL,
        STRL NVARCHAR(20),
        STRLName NVARCHAR(200) NULL,
        GradeLevel TINYINT NOT NULL,
        LocalityCode NVARCHAR(50) NULL,
        Cost NUMERIC(18, 4) NULL,
        PersonnelCount INT NULL,
        LocationName NVARCHAR(100) NULL,
        CostElementId INT NOT NULL,
        CostElementCategory NVARCHAR(50) NOT NULL,
        CostElementName NVARCHAR(250) NOT NULL,
        LocationId INT NULL,
        Inventory INT NULL,
        LocationType NVARCHAR(100) NULL
    );


    INSERT INTO #Cost
    (
        PayPlan,
        OccupationalGroupNumber,
        OccupationalSeriesNumber,
        STRL,
        GradeLevel,
        CostElementId,
        CostElementCategory,
        CostElementName,
        LocationId,
        Inventory
    )
    SELECT a.PayPlan,
           a.OccupationalGroupNumber,
           a.OccupationalSeriesNumber,
           a.STRL,
           a.GradeLevel,
           b.CostElementId,
           b.CostElementCategory,
           b.CostElementName,
           a.LocationId,
           a.inventory
    FROM
    (
        SELECT PayPlan,
               OccupationalGroupNumber,
               OccupationalSeriesNumber,
               STRL,
               GradeLevel,
               LocationId,
               SUM(Inventory) AS inventory
        FROM crunch.InventoryGFEBS
        WHERE AmcosVersionId = @AmcosVersionId
        GROUP BY PayPlan,
                 OccupationalGroupNumber,
                 OccupationalSeriesNumber,
                 STRL,
                 GradeLevel,
                 LocationId
    ) AS a
        INNER JOIN lookup.CostElement AS b
            ON a.PayPlan = b.PayPlan
               AND @AmcosVersionId
               BETWEEN b.AmcosVersionIdStart AND b.AmcosVersionIdEnd;

    --bring in the LocationId for locality acronyms
    UPDATE #Cost
    SET LocationName = b.DisplayName,
        LocationType = b.LocationType
    FROM #Cost AS a
        INNER JOIN warehouse.Location AS b
            ON a.LocationId = b.LocationId;



    /* Its easier to put this logic in one central place then to scatter it throughout
    -- if the payschedule is locality based then locality=1
    -- if the pp inherently is permanent then we want only perm people (11b1)
    -- if the pp inherently is transient or non-perm then we are ok with either 11b1 or 11b3, AD and consultants is a good example of this right now
    -- reviewing the cleaned GFEBS data for which PPs are coming in with 11B3 is a good way to check things each year
	TODO: Determine if these pay plans should be added to PPBasePayRules: ES, GG, GL
	*/
    DROP TABLE IF EXISTS #PPBasePayRules;
    CREATE TABLE #PPBasePayRules
    (
        PayPlan NVARCHAR(2) NULL,
        Locality BIT NULL,
        _11b1 BIT NULL,
        _11b3 BIT NULL,
        frequency NVARCHAR(20) NULL
    );
    INSERT INTO #PPBasePayRules
    (
        PayPlan,
        Locality,
        _11b1,
        _11b3,
        frequency
    )
    SELECT 'DB',
           1,
           1,
           0,
           'annual'
    UNION
    SELECT 'DE',
           1,
           1,
           0,
           'annual'
    UNION
    SELECT 'DJ',
           1,
           1,
           0,
           'annual'
    UNION
    SELECT 'DK',
           1,
           1,
           0,
           'annual'
    UNION
    SELECT 'NH',
           1,
           1,
           0,
           'annual'
    UNION
    SELECT 'NJ',
           1,
           1,
           0,
           'annual'
    UNION
    SELECT 'NK',
           1,
           1,
           0,
           'annual'
    UNION
    SELECT 'GP',
           0,
           1,
           0,
           'annual'
    UNION
    SELECT 'AD',
           0,
           1,
           1,
           'annual'
    UNION
    SELECT 'CA',
           1,
           1,
           0,
           'annual'
    UNION
    SELECT 'EE',
           0,
           1,
           1,
           'hourly'
    UNION
    SELECT 'EF',
           0,
           1,
           1,
           'hourly'
    UNION
    SELECT 'EX',
           0,
           1,
           0,
           'annual'
    UNION
    SELECT 'IP',
           0,
           1,
           0,
           'annual'
    UNION
    SELECT 'IE',
           0,
           1,
           0,
           'annual'
    UNION
    SELECT 'IG',
           0,
           1,
           0,
           'annual'
    UNION
    SELECT 'SL',
           0,
           1,
           0,
           'annual'
    UNION
    SELECT 'ST',
           0,
           1,
           0,
           'annual'
    UNION
    SELECT 'ZZ',
           0,
           1,
           0,
           'annual';


    --this is used to limit the extent to which pay outside the bounds of a payschedule is allowed in so we don't get odd ball situations
    --in GFEBS where people are getting paid significantly more or less than the payschedule dictates to be allowed to skew the data
    DECLARE @PercentileLimit NUMERIC(4, 2) = crunch.GetSingleValue('GFEBS', 'PercentileLimit', @AmcosVersionId);

    --#######################################
    -- Base Pay and Locality Pay Section
    --#######################################

    --base pay for records who get locality
    UPDATE #Cost
    SET Cost = b.AmountPaid,
        PersonnelCount = b.PersonnelCount
    FROM #Cost AS a
        INNER JOIN
        (
            SELECT PayPlan,
                   OccupationalSeriesNumber,
                   Country,
                   STRL,
                   GradeLevel,
                   LocationId,
                   AVG(AmountPaid) / (1 + MAX(LocalityRate) / 100) AS AmountPaid,
                   SUM(PersonnelCount) AS PersonnelCount
            FROM
            (
                SELECT PayPlan,
                       OccupationalSeriesNumber,
                       Country,
                       STRL,
                       GradeLevel,
                       LocationId,
                       PersonnelNumber,
                       CASE
                           WHEN PayPlan IN
                                (
                                    SELECT PayPlan FROM #PPBasePayRules WHERE frequency = 'annual'
                                ) THEN
                               MAX(ActualHourlyRate) * @AnnualHours
                           ELSE
                               MAX(ActualHourlyRate)
                       END AS AmountPaid,
                       1 AS PersonnelCount,
                       MAX(LocalityRate) AS LocalityRate
                FROM #WorkInProgress
                WHERE (
                          (
                              CostElementCode = '6100.11B1'
                              AND PayPlan IN
                                  (
                                      SELECT PayPlan FROM #PPBasePayRules WHERE _11b1 = 1 AND Locality = 1
                                  )
                          )
                          OR
                          (
                              CostElementCode = '6100.11B3'
                              AND PayPlan IN
                                  (
                                      SELECT PayPlan FROM #PPBasePayRules WHERE _11b3 = 1 AND Locality = 1
                                  )
                          )
                      )
                      AND
                    --people who get market pay, or overseas pay don't get locality pay 
                    PersonnelNumber NOT IN
                    (
                        SELECT DISTINCT
                               PersonnelNumber
                        FROM #WorkInProgress
                        WHERE CostElementCode IN ( '6100.11T0', '6100.11J0', '6100.12B0' )
                    )
                      --the following pay plans do not use locality pay

                      AND LocalityCode <> '-1'
                GROUP BY PayPlan,
                         OccupationalSeriesNumber,
                         PersonnelNumber,
                         Country,
                         STRL,
                         GradeLevel,
                         LocationId
            ) AS b
            GROUP BY PayPlan,
                     OccupationalSeriesNumber,
                     Country,
                     STRL,
                     GradeLevel,
                     LocationId
        ) AS b
            ON a.PayPlan = b.PayPlan
               AND a.OccupationalSeriesNumber = b.OccupationalSeriesNumber
               AND a.LocationId = b.LocationId
               AND a.GradeLevel = b.GradeLevel
               AND a.STRL = b.STRL
    WHERE a.CostElementId IN
          (
              SELECT CostElementId
              FROM lookup.CostElement
              WHERE (
                        CostElementName LIKE '%6100.11B1%'
                        OR CostElementName LIKE '%6100.11B3%'
                    )
                    AND PayPlan IN
                        (
                            SELECT PayPlan FROM #PPBasePayRules
                        )
          );



    --locality pay
    UPDATE #Cost
    SET Cost = b.Amount,
        PersonnelCount = b.PersonnelCount
    FROM #Cost AS a
        INNER JOIN
        (
            SELECT a.PayPlan,
                   a.OccupationalSeriesNumber,
                   a.STRL,
                   a.GradeLevel,
                   a.LocationId,
                   a.Cost * (b.LocalityRate / 100) AS Amount, --no annual/hourly case statement needed here as the previous update and this % calc will observe the proper value
                   a.PersonnelCount
            FROM #Cost AS a
                INNER JOIN
                (SELECT DISTINCT LocationId, LocalityRate FROM #WorkInProgress) AS b
                    ON a.LocationId = b.LocationId
            WHERE (
                      (
                          a.CostElementName LIKE '%6100.11B1%'
                          AND a.PayPlan IN
                              (
                                  SELECT PayPlan FROM #PPBasePayRules WHERE _11b1 = 1 AND Locality = 1
                              )
                      )
                      OR
                      (
                          a.CostElementName LIKE '%6100.11B3%'
                          AND a.PayPlan IN
                              (
                                  SELECT PayPlan FROM #PPBasePayRules WHERE _11b3 = 1 AND Locality = 1
                              )
                      )
                  )
                  AND ISNULL(a.Cost, 0) > 0
        ) AS b
            ON a.PayPlan = b.PayPlan
               AND a.OccupationalSeriesNumber = b.OccupationalSeriesNumber
               AND a.GradeLevel = b.GradeLevel
               AND a.STRL = b.STRL
               AND a.LocationId = b.LocationId
    WHERE a.CostElementId IN
          (
              SELECT CostElementId
              FROM lookup.CostElement
              WHERE CostElementName = 'Civ Locality Pay'
                    AND PayPlan IN
                        (
                            SELECT PayPlan FROM #PPBasePayRules
                        ) --note, no PPs without locality
          );




    --base pay for everyone else is just the amount from GFBES
    UPDATE #Cost
    SET Cost = b.AmountPaid,
        PersonnelCount = b.PersonnelCount
    FROM #Cost AS a
        INNER JOIN
        (
            SELECT PayPlan,
                   OccupationalSeriesNumber,
                   Country,
                   STRL,
                   GradeLevel,
                   LocationId,
                   AVG(AmountPaid) AS AmountPaid,
                   SUM(PersonnelCount) AS PersonnelCount
            FROM
            (
                SELECT PayPlan,
                       OccupationalSeriesNumber,
                       Country,
                       STRL,
                       GradeLevel,
                       LocationId,
                       CASE
                           WHEN PayPlan IN
                                (
                                    SELECT PayPlan FROM #PPBasePayRules WHERE frequency = 'annual'
                                ) THEN
                               MAX(ActualHourlyRate) * @AnnualHours
                           ELSE
                               MAX(ActualHourlyRate)
                       END AS AmountPaid,
                       1 AS PersonnelCount
                FROM #WorkInProgress
                GROUP BY PayPlan,
                         OccupationalSeriesNumber,
                         PersonnelNumber,
                         Country,
                         STRL,
                         GradeLevel,
                         LocationId
            ) AS b
            GROUP BY PayPlan,
                     OccupationalSeriesNumber,
                     Country,
                     STRL,
                     GradeLevel,
                     LocationId
        ) AS b
            ON a.PayPlan = b.PayPlan
               AND a.OccupationalSeriesNumber = b.OccupationalSeriesNumber
               AND a.LocationId = b.LocationId
               AND a.GradeLevel = b.GradeLevel
               AND a.STRL = b.STRL
    WHERE a.CostElementId IN
          (
              SELECT CostElementId
              FROM lookup.CostElement
              WHERE (
                        a.CostElementName LIKE '%6100.11B1%'
                        OR a.CostElementName LIKE '%6100.11B3%'
                    )
                    AND PayPlan IN
                        (
                            SELECT PayPlan FROM #PPBasePayRules
                        )
          )
          AND a.Cost IS NULL; --don't update records which were already touched by thee previous calculations

    --#######################################
    -- Amount Paid Annualized (*26) CEs
    --#######################################	 

    --[[CivilianOverseasAllowances]]
    UPDATE #Cost
    SET Cost = b.AmountPaid,
        PersonnelCount = b.PersonnelCount
    FROM #Cost AS a
        INNER JOIN
        (
            SELECT a.PayPlan,
                   a.OccupationalSeriesNumber,
                   a.Country,
                   a.STRL,
                   a.GradeLevel,
                   a.LocationId,
                   CASE
                       WHEN a.PayPlan IN
                            (
                                SELECT PayPlan FROM #PPBasePayRules WHERE frequency = 'annual'
                            ) THEN
                           AVG(AmountPaid) * 26
                       ELSE
                           ISNULL(SUM(AmountPaid) / NULLIF(SUM(b.PaidHours), 0), @ZeroValue)
                   END AS AmountPaid,
                   COUNT(DISTINCT a.PersonnelNumber) AS PersonnelCount
            FROM #WorkInProgress AS a
                LEFT OUTER JOIN
                (
                    SELECT PersonnelNumber,
                           SUM(PaidHours) AS PaidHours
                    FROM #WorkInProgress
                    WHERE CostElementCode IN ( '6100.11B1', '6100.11B3' )
                    GROUP BY PersonnelNumber
                ) AS b
                    ON b.PersonnelNumber = a.PersonnelNumber
            WHERE a.CostElementCode = '6100.12B0'
            GROUP BY a.PayPlan,
                     a.OccupationalSeriesNumber,
                     a.Country,
                     a.STRL,
                     a.GradeLevel,
                     a.LocationId
        ) AS b
            ON a.PayPlan = b.PayPlan
               AND a.OccupationalSeriesNumber = b.OccupationalSeriesNumber
               AND a.LocationId = b.LocationId
               AND a.GradeLevel = b.GradeLevel
               AND a.STRL = b.STRL
    WHERE a.CostElementId IN
          (
              SELECT CostElementId
              FROM lookup.CostElement
              WHERE a.CostElementName LIKE '%6100.12B%'
                    AND a.PayPlan IN
                        (
                            SELECT PayPlan FROM #PPBasePayRules
                        )
          );



    --[CivilianPhysicianComparabilityPay]
    UPDATE #Cost
    SET Cost = b.AmountPaid,
        PersonnelCount = b.PersonnelCount
    FROM #Cost AS a
        INNER JOIN
        (
            SELECT a.PayPlan,
                   a.OccupationalSeriesNumber,
                   a.Country,
                   a.STRL,
                   a.GradeLevel,
                   a.LocationId,
                   CASE
                       WHEN a.PayPlan IN
                            (
                                SELECT PayPlan FROM #PPBasePayRules WHERE frequency = 'annual'
                            ) THEN
                           AVG(AmountPaid) * 26
                       ELSE
                           ISNULL(SUM(AmountPaid) / NULLIF(SUM(b.PaidHours), 0), @ZeroValue)
                   END AS AmountPaid,
                   COUNT(DISTINCT a.PersonnelNumber) AS PersonnelCount
            FROM #WorkInProgress AS a
                LEFT OUTER JOIN
                (
                    SELECT PersonnelNumber,
                           SUM(PaidHours) AS PaidHours
                    FROM #WorkInProgress
                    WHERE CostElementCode IN ( '6100.11B1', '6100.11B3' )
                    GROUP BY PersonnelNumber
                ) AS b
                    ON b.PersonnelNumber = a.PersonnelNumber
            WHERE a.CostElementCode = '6100.11T0'
            GROUP BY a.PayPlan,
                     a.OccupationalSeriesNumber,
                     a.Country,
                     a.STRL,
                     a.GradeLevel,
                     a.LocationId
        ) AS b
            ON a.PayPlan = b.PayPlan
               AND a.OccupationalSeriesNumber = b.OccupationalSeriesNumber
               AND a.LocationId = b.LocationId
               AND a.GradeLevel = b.GradeLevel
               AND a.STRL = b.STRL
    WHERE a.CostElementId IN
          (
              SELECT CostElementId
              FROM lookup.CostElement
              WHERE a.CostElementName LIKE '%6100.11T0%'
                    AND a.PayPlan IN
                        (
                            SELECT PayPlan FROM #PPBasePayRules
                        )
          );



    --CivilianHazardousDutyPay
    UPDATE #Cost
    SET Cost = b.AmountPaid,
        PersonnelCount = b.PersonnelCount
    FROM #Cost AS a
        INNER JOIN
        (
            SELECT PayPlan,
                   OccupationalSeriesNumber,
                   Country,
                   STRL,
                   GradeLevel,
                   LocationId,
                   AVG(AmountPaid) * 26 AS AmountPaid,
                   COUNT(DISTINCT PersonnelNumber) AS PersonnelCount
            FROM #WorkInProgress
            WHERE CostElementCode = '6100.11H0'
            GROUP BY PayPlan,
                     OccupationalSeriesNumber,
                     Country,
                     STRL,
                     GradeLevel,
                     LocationId
        ) AS b
            ON a.PayPlan = b.PayPlan
               AND a.OccupationalSeriesNumber = b.OccupationalSeriesNumber
               AND a.LocationId = b.LocationId
               AND a.GradeLevel = b.GradeLevel
               AND a.STRL = b.STRL
    WHERE a.CostElementId IN
          (
              SELECT CostElementId
              FROM lookup.CostElement
              WHERE a.CostElementName LIKE '%6100.11H0%'
                    AND PayPlan IN
                        (
                            SELECT PayPlan FROM #PPBasePayRules
                        )
          );




    --FEGLI
    UPDATE #Cost
    SET Cost = b.AmountPaid,
        PersonnelCount = b.PersonnelCount
    FROM #Cost AS a
        INNER JOIN
        (
            SELECT a.PayPlan,
                   a.OccupationalSeriesNumber,
                   a.Country,
                   a.STRL,
                   a.GradeLevel,
                   a.LocationId,
                   CASE
                       WHEN a.PayPlan IN
                            (
                                SELECT PayPlan FROM #PPBasePayRules WHERE frequency = 'annual'
                            ) THEN
                           AVG(AmountPaid) * 26
                       ELSE
                           ISNULL(SUM(AmountPaid) / NULLIF(SUM(b.PaidHours), 0), @ZeroValue)
                   END AS AmountPaid,
                   COUNT(DISTINCT a.PersonnelNumber) AS PersonnelCount
            FROM #WorkInProgress AS a
                LEFT OUTER JOIN
                (
                    SELECT PersonnelNumber,
                           SUM(PaidHours) AS PaidHours
                    FROM #WorkInProgress
                    WHERE CostElementCode IN ( '6100.11B1', '6100.11B3' )
                    GROUP BY PersonnelNumber
                ) AS b
                    ON b.PersonnelNumber = a.PersonnelNumber
            WHERE a.CostElementCode = '6400.12K0'
                  AND a.PayPlan NOT IN ( 'EE', 'EF' )
            --per DoD 70000.14-R 100608 experts and consultants are ineligible for FEGLI
            --however, GFEBS MAY show costs here  due to other employment situations but for these two pay plans that is not relevant and the regulation reigns
            GROUP BY a.PayPlan,
                     a.OccupationalSeriesNumber,
                     a.Country,
                     a.STRL,
                     a.GradeLevel,
                     a.LocationId
        ) AS b
            ON a.PayPlan = b.PayPlan
               AND a.OccupationalSeriesNumber = b.OccupationalSeriesNumber
               AND a.LocationId = b.LocationId
               AND a.GradeLevel = b.GradeLevel
               AND a.STRL = b.STRL
    WHERE a.CostElementId IN
          (
              SELECT CostElementId
              FROM lookup.CostElement
              WHERE a.CostElementName LIKE '%6400.12K0%'
                    AND a.PayPlan IN
                        (
                            SELECT PayPlan FROM #PPBasePayRules
                        )
          );
    --for records where 12k is missing for some reason we use an average to fill in the blanks
    --4/7/2021 - due to the odd/haphazard nature of AD we do not fill in the blanks for them
    UPDATE #Cost
    SET Cost = b.Amount,
        PersonnelCount = 1
    FROM #Cost AS a
        INNER JOIN
        (
            SELECT PayPlan,
                   GradeLevel,
                   --because we are pulling from the costs and not the raw table we don't need to account for hourly/annual since the cost table already took care of that
                   SUM(Cost * PersonnelCount) / SUM(PersonnelCount) AS Amount
            FROM #Cost
            WHERE CostElementId IN
                  (
                      SELECT CostElementId
                      FROM lookup.CostElement
                      WHERE CostElementName LIKE '%6400.12K0%'
                            AND PayPlan IN
                                (
                                    SELECT PayPlan FROM #PPBasePayRules
                                )
                  )
                  AND ISNULL(Cost, 0) > 0
            GROUP BY PayPlan,
                     GradeLevel
        ) AS b
            ON a.PayPlan = b.PayPlan
               AND a.GradeLevel = b.GradeLevel
    WHERE a.CostElementId IN
          (
              SELECT CostElementId
              FROM lookup.CostElement
              WHERE CostElementName LIKE '%6400.12K0%'
                    AND PayPlan IN
                        (
                            SELECT PayPlan FROM #PPBasePayRules
                        )
          )
          AND ISNULL(a.Cost, 0) = 0;

    --Medical Premium Pay
    UPDATE #Cost
    SET Cost = b.AmountPaid,
        PersonnelCount = b.PersonnelCount
    FROM #Cost AS a
        INNER JOIN
        (
            SELECT a.PayPlan,
                   a.OccupationalSeriesNumber,
                   a.Country,
                   a.STRL,
                   a.GradeLevel,
                   a.LocationId,
                   CASE
                       WHEN a.PayPlan IN
                            (
                                SELECT PayPlan FROM #PPBasePayRules WHERE frequency = 'annual'
                            ) THEN
                           AVG(AmountPaid) * 26
                       ELSE
                           ISNULL(SUM(AmountPaid) / NULLIF(SUM(b.PaidHours), 0), @ZeroValue)
                   END AS AmountPaid,
                   COUNT(DISTINCT a.PersonnelNumber) AS PersonnelCount
            FROM #WorkInProgress AS a
                LEFT OUTER JOIN
                (
                    SELECT PersonnelNumber,
                           SUM(PaidHours) AS PaidHours
                    FROM #WorkInProgress
                    WHERE CostElementCode IN ( '6100.11B1', '6100.11B3' )
                    GROUP BY PersonnelNumber
                ) AS b
                    ON b.PersonnelNumber = a.PersonnelNumber
            WHERE a.CostElementCode = '6100.11N0'
            GROUP BY a.PayPlan,
                     a.OccupationalSeriesNumber,
                     a.Country,
                     a.STRL,
                     a.GradeLevel,
                     a.LocationId
        ) AS b
            ON a.PayPlan = b.PayPlan
               AND a.OccupationalSeriesNumber = b.OccupationalSeriesNumber
               AND a.LocationId = b.LocationId
               AND a.GradeLevel = b.GradeLevel
               AND a.STRL = b.STRL
    WHERE a.CostElementId IN
          (
              SELECT CostElementId
              FROM lookup.CostElement
              WHERE CostElementName LIKE '%6100.11N0%'
                    AND PayPlan IN
                        (
                            SELECT PayPlan FROM #PPBasePayRules
                        )
          );

    --Cost-of-Living Allowances (COLA) for Nonforeign Area

    UPDATE #Cost
    SET Cost = b.AmountPaid,
        PersonnelCount = b.PersonnelCount
    FROM #Cost AS a
        INNER JOIN
        (
            SELECT a.PayPlan,
                   a.OccupationalSeriesNumber,
                   a.Country,
                   a.STRL,
                   a.GradeLevel,
                   a.LocationId,
                   CASE
                       WHEN a.PayPlan IN
                            (
                                SELECT PayPlan FROM #PPBasePayRules WHERE frequency = 'annual'
                            ) THEN
                           AVG(AmountPaid) * 26
                       ELSE
                           ISNULL(SUM(AmountPaid) / NULLIF(SUM(b.PaidHours), 0), @ZeroValue)
                   END AS AmountPaid,
                   COUNT(DISTINCT a.PersonnelNumber) AS PersonnelCount
            FROM #WorkInProgress AS a
                LEFT OUTER JOIN
                (
                    SELECT PersonnelNumber,
                           SUM(PaidHours) AS PaidHours
                    FROM #WorkInProgress
                    WHERE CostElementCode IN ( '6100.11B1', '6100.11B3' )
                    GROUP BY PersonnelNumber
                ) AS b
                    ON b.PersonnelNumber = a.PersonnelNumber
            WHERE a.CostElementCode = '6100.12C0'
                  AND a.LocationId IN
                      (
                          SELECT b.LocationId
                          FROM PaySchedule.LocalityPay AS a
                              INNER JOIN warehouse.Location AS b
                                  ON a.LocalityCode = b.SourceSystemCode
                                     AND b.LocationType = 'Locality Pay Area'
                          WHERE @AmcosVersionId = a.AmcosVersionId
                      --AND COLA > 0
                      ) --added 6/30/2020 at Marsha's request to prevent Nonforeign Areas from recieving COLA despite GFEBS saying that they do
            GROUP BY a.PayPlan,
                     a.OccupationalSeriesNumber,
                     a.Country,
                     a.STRL,
                     a.GradeLevel,
                     a.LocationId
        ) AS b
            ON a.PayPlan = b.PayPlan
               AND a.OccupationalSeriesNumber = b.OccupationalSeriesNumber
               AND a.GradeLevel = b.GradeLevel
               AND a.STRL = b.STRL
               AND a.LocationId = b.LocationId
    WHERE a.CostElementId IN
          (
              SELECT CostElementId
              FROM lookup.CostElement
              WHERE CostElementName LIKE '%6100.12C0%'
                    AND PayPlan IN
                        (
                            SELECT PayPlan FROM #PPBasePayRules
                        )
          );


    --Other Benefits
    UPDATE #Cost
    SET Cost = b.AmountPaid,
        PersonnelCount = b.PersonnelCount
    FROM #Cost AS a
        INNER JOIN
        (
            SELECT a.PayPlan,
                   a.OccupationalSeriesNumber,
                   a.Country,
                   a.STRL,
                   a.GradeLevel,
                   a.LocationId,
                   CASE
                       WHEN a.PayPlan IN
                            (
                                SELECT PayPlan FROM #PPBasePayRules WHERE frequency = 'annual'
                            ) THEN
                           AVG(AmountPaid) * 26
                       ELSE
                           ISNULL(SUM(AmountPaid) / NULLIF(SUM(b.PaidHours), 0), @ZeroValue)
                   END AS AmountPaid,
                   COUNT(DISTINCT a.PersonnelNumber) AS PersonnelCount
            FROM #WorkInProgress AS a
                LEFT OUTER JOIN
                (
                    SELECT PersonnelNumber,
                           SUM(PaidHours) AS PaidHours
                    FROM #WorkInProgress
                    WHERE CostElementCode IN ( '6100.11B1', '6100.11B3' )
                    GROUP BY PersonnelNumber
                ) AS b
                    ON b.PersonnelNumber = a.PersonnelNumber
            WHERE a.CostElementCode = '6100.12S2'
                  AND a.PersonnelNumber NOT IN
                      --we don't want outliers so get rid of them based on the single value limit
                      (
                          SELECT PersonnelNumber
                          FROM
                          (
                              SELECT PersonnelNumber,
                                     PERCENTILE_CONT(@PercentileLimit)WITHIN GROUP(ORDER BY AmountPaid) OVER (PARTITION BY CostElementCode, GradeLevel, PayPlan) AS cap,
                                     AmountPaid
                              FROM load_GFEBS.Cleaned
                              --2/22/2022 added a three year sliding window
                              WHERE CostElementCode IN ( '6100.12S2' )
                                    AND AmcosVersionId
                                    BETWEEN @AmcosVersionId - 200 AND @AmcosVersionId
                          ) AS a
                          WHERE AmountPaid > cap
                      )
            GROUP BY a.PayPlan,
                     a.OccupationalSeriesNumber,
                     a.Country,
                     a.STRL,
                     a.GradeLevel,
                     a.LocationId
        ) AS b
            ON a.PayPlan = b.PayPlan
               AND a.OccupationalSeriesNumber = b.OccupationalSeriesNumber
               AND a.LocationId = b.LocationId
               AND a.GradeLevel = b.GradeLevel
               AND a.STRL = b.STRL
    WHERE a.CostElementId IN
          (
              SELECT CostElementId
              FROM lookup.CostElement
              WHERE CostElementName LIKE '%6100.12S2%'
                    AND PayPlan IN
                        (
                            SELECT PayPlan FROM #PPBasePayRules
                        )
          );


    --[CivilianSupervisorySpecialPay]
    UPDATE #Cost
    SET Cost = b.AmountPaid,
        PersonnelCount = b.PersonnelCount
    FROM #Cost AS a
        INNER JOIN
        (
            SELECT a.PayPlan,
                   a.OccupationalSeriesNumber,
                   a.Country,
                   a.STRL,
                   a.GradeLevel,
                   a.LocationId,
                   CASE
                       WHEN a.PayPlan IN
                            (
                                SELECT PayPlan FROM #PPBasePayRules WHERE frequency = 'annual'
                            ) THEN
                           AVG(AmountPaid) * 26
                       ELSE
                           ISNULL(SUM(AmountPaid) / NULLIF(SUM(b.PaidHours), 0), @ZeroValue)
                   END AS AmountPaid,
                   COUNT(DISTINCT a.PersonnelNumber) AS PersonnelCount
            FROM #WorkInProgress AS a
                LEFT OUTER JOIN
                (
                    SELECT PersonnelNumber,
                           SUM(PaidHours) AS PaidHours
                    FROM #WorkInProgress
                    WHERE CostElementCode IN ( '6100.11B1', '6100.11B3' )
                    GROUP BY PersonnelNumber
                ) AS b
                    ON b.PersonnelNumber = a.PersonnelNumber
            WHERE a.CostElementCode = '6100.11Q0'
            GROUP BY a.PayPlan,
                     a.OccupationalSeriesNumber,
                     a.Country,
                     a.STRL,
                     a.GradeLevel,
                     a.LocationId
        ) AS b
            ON a.PayPlan = b.PayPlan
               AND a.OccupationalSeriesNumber = b.OccupationalSeriesNumber
               AND a.LocationId = b.LocationId
               AND a.GradeLevel = b.GradeLevel
               AND a.STRL = b.STRL
    WHERE a.CostElementId IN
          (
              SELECT CostElementId
              FROM lookup.CostElement
              WHERE CostElementName LIKE '%6100.11Q0%'
                    AND PayPlan IN
                        (
                            SELECT PayPlan FROM #PPBasePayRules
                        )
          );


    --[CivilianPostDifferentialPay]
    UPDATE #Cost
    SET Cost = b.AmountPaid,
        PersonnelCount = b.PersonnelCount
    FROM #Cost AS a
        INNER JOIN
        (
            SELECT a.PayPlan,
                   a.OccupationalSeriesNumber,
                   a.Country,
                   a.STRL,
                   a.GradeLevel,
                   a.LocationId,
                   CASE
                       WHEN a.PayPlan IN
                            (
                                SELECT PayPlan FROM #PPBasePayRules WHERE frequency = 'annual'
                            ) THEN
                           AVG(AmountPaid) * 26
                       ELSE
                           ISNULL(SUM(AmountPaid) / NULLIF(SUM(b.PaidHours), 0), @ZeroValue)
                   END AS AmountPaid,
                   COUNT(DISTINCT a.PersonnelNumber) AS PersonnelCount
            FROM #WorkInProgress AS a
                LEFT OUTER JOIN
                (
                    SELECT PersonnelNumber,
                           SUM(PaidHours) AS PaidHours
                    FROM #WorkInProgress
                    WHERE CostElementCode IN ( '6100.11B1', '6100.11B3' )
                    GROUP BY PersonnelNumber
                ) AS b
                    ON b.PersonnelNumber = a.PersonnelNumber
            WHERE a.CostElementCode = '6100.11J0'
            GROUP BY a.PayPlan,
                     a.OccupationalSeriesNumber,
                     a.Country,
                     a.STRL,
                     a.GradeLevel,
                     a.LocationId
        ) AS b
            ON a.PayPlan = b.PayPlan
               AND a.OccupationalSeriesNumber = b.OccupationalSeriesNumber
               AND a.LocationId = b.LocationId
               AND a.GradeLevel = b.GradeLevel
               AND a.STRL = b.STRL
    WHERE a.CostElementId IN
          (
              SELECT CostElementId
              FROM lookup.CostElement
              WHERE CostElementName LIKE '%6100.11J0%'
                    AND PayPlan IN
                        (
                            SELECT PayPlan FROM #PPBasePayRules
                        )
          );


    --#######################################
    -- Single Value Fixed Amount Section
    --#######################################
    --[CivilianPostRetirementHealth]
    UPDATE #Cost
    SET Cost = crunch.GetSingleValue('GP', 'postRetirementHealth', @AmcosVersionId),
        PersonnelCount = 1,
        Inventory = 1 --since these are single values the divisor should always be 1 otherwise this value will get incorrectly reduced later when computing averages
    FROM #Cost
    WHERE CostElementId IN
          (
              SELECT CostElementId
              FROM lookup.CostElement
              WHERE CostElementName LIKE '%Post Retirement health insurance%'
                    AND PayPlan IN
                        (
                            SELECT PayPlan FROM #PPBasePayRules
                        )
          )
          --doesn't apply to hourly employees
          AND PayPlan IN
              (
                  SELECT PayPlan FROM #PPBasePayRules WHERE frequency = 'annual'
              );

    --[[CivilianPostRetirementLifeInsurance]]
    UPDATE #Cost
    SET Cost = crunch.GetSingleValue('GP', 'postRetirementLifeInsurance', @AmcosVersionId),
        PersonnelCount = 1,
        Inventory = 1 --since these are single values the divisor should always be 1 otherwise this value will get incorrectly reduced later when computing averages
    FROM #Cost
    WHERE CostElementId IN
          (
              SELECT CostElementId
              FROM lookup.CostElement
              WHERE CostElementName LIKE '%post retirement life insurance%'
                    AND PayPlan IN
                        (
                            SELECT PayPlan FROM #PPBasePayRules
                        )
          )
          --doesn't apply to hourly employees
          AND PayPlan IN
              (
                  SELECT PayPlan FROM #PPBasePayRules WHERE frequency = 'annual'
              );


    --[[[CivilianTraining]]]
    UPDATE #Cost
    SET Cost = crunch.GetSingleValue('GP', 'training', @AmcosVersionId),
        PersonnelCount = 1,
        Inventory = 1 --since these are single values the divisor should always be 1 otherwise this value will get incorrectly reduced later when computing averages
    FROM #Cost
    WHERE CostElementId IN
          (
              SELECT CostElementId
              FROM lookup.CostElement
              WHERE CostElementName LIKE '%training%'
                    AND PayPlan IN
                        (
                            SELECT PayPlan FROM #PPBasePayRules
                        )
          )
          --doesn't apply to hourly employees
          AND PayPlan IN
              (
                  SELECT PayPlan FROM #PPBasePayRules WHERE frequency = 'annual'
              );



    --Cash Awards
    --at some point we need to maybe have separate cash awards values for each pay plan but for now the COR likes one figure for the GP, D and N series
    DECLARE @PercentCivCashAwards NUMERIC(18, 4)
        = crunch.GetSingleValue('GP', 'percentCivCashAwards', @AmcosVersionId) / 100;

    --we have differnet cash awards for certain pay plans so process those first 
    UPDATE #Cost
    SET Cost = c.CashAwards * b.TotalBase,
        PersonnelCount = b.PersonnelCount
    FROM #Cost AS a
        INNER JOIN
        --we've already done the hard work on determining pay so just sum all that up
        --since we're only dealing with non-market pay pay plans we don't have to worry about anything other then base, hourly, and locality CE IDs
        (
            SELECT PayPlan,
                   OccupationalSeriesNumber,
                   Country,
                   STRL,
                   GradeLevel,
                   LocationId,
                   MAX(PersonnelCount) AS PersonnelCount,
                   SUM(Cost) AS TotalBase
            FROM #Cost
            WHERE CostElementId IN
                  (
                      SELECT CostElementId
                      FROM lookup.CostElement
                      WHERE (
                                CostElementName LIKE '%cash award%'
                                OR CostElementName LIKE '%base%'
                                OR CostElementName LIKE '%locality%'
                                OR CostElementName LIKE '%hourly%'
                            )
                            AND PayPlan IN
                                (
                                    SELECT PayPlan FROM #PPBasePayRules
                                )
                            AND @AmcosVersionId
                            BETWEEN AmcosVersionIdStart AND AmcosVersionIdEnd
                  )
            GROUP BY PayPlan,
                     OccupationalSeriesNumber,
                     Country,
                     STRL,
                     GradeLevel,
                     LocationId
        ) AS b
            ON a.PayPlan = b.PayPlan
               AND a.OccupationalSeriesNumber = b.OccupationalSeriesNumber
               AND a.LocationId = b.LocationId
               AND a.GradeLevel = b.GradeLevel
               AND a.STRL = b.STRL
        INNER JOIN
        (
            SELECT PayPlan,
                   paramValue AS CashAwards
            FROM dataload.SingleValues
            WHERE paramName = 'CashAwards'
                  AND @AmcosVersionId = AmcosVersionId
                  AND PayPlan IN
                      (
                          SELECT PayPlan FROM #PPBasePayRules
                      )
        ) AS c
            ON c.PayPlan = a.PayPlan
    WHERE a.CostElementId IN
          (
              SELECT CostElementId
              FROM lookup.CostElement
              WHERE CostElementName LIKE '%6100.11K0%'
                    AND PayPlan IN
                        (
                            SELECT PayPlan FROM #PPBasePayRules
                        )
          );



    UPDATE #Cost
    SET Cost = b.AmountPaid * @PercentCivCashAwards,
        PersonnelCount = b.PersonnelCount
    FROM #Cost AS a
        INNER JOIN
        (
            SELECT PayPlan,
                   OccupationalSeriesNumber,
                   Country,
                   STRL,
                   GradeLevel,
                   LocationId,
                   AVG(AmountPaid) * 26 AS AmountPaid,
                   COUNT(DISTINCT PersonnelNumber) AS PersonnelCount
            FROM #WorkInProgress
            --(Civ Base Pay (6100.11B1) + Civ Physician Comparability Pay (Market Pay) (6100.11T0)) * Cash Awards Percentage
            WHERE (
                      CostElementCode = '6100.11B1'
                      AND PayPlan IN
                          (
                              SELECT PayPlan FROM #PPBasePayRules WHERE _11b1 = 1
                          )
                      OR CostElementCode = '6100.11B3'
                         AND PayPlan IN
                             (
                                 SELECT PayPlan FROM #PPBasePayRules WHERE _11b3 = 1
                             )
                      OR CostElementCode = '6100.11T0'
                  )
                  AND --doesn't apply to hourly employees
                PayPlan IN
                (
                    SELECT PayPlan FROM #PPBasePayRules WHERE frequency = 'annual'
                )
            GROUP BY PayPlan,
                     OccupationalSeriesNumber,
                     Country,
                     STRL,
                     GradeLevel,
                     LocationId
        ) AS b
            ON a.PayPlan = b.PayPlan
               AND a.OccupationalSeriesNumber = b.OccupationalSeriesNumber
               AND a.LocationId = b.LocationId
               AND a.GradeLevel = b.GradeLevel
               AND a.STRL = b.STRL
    WHERE a.CostElementId IN
          (
              SELECT CostElementId
              FROM lookup.CostElement
              WHERE CostElementName LIKE '%6100.11K0%'
                    AND PayPlan IN
                        (
                            SELECT PayPlan FROM #PPBasePayRules
                        )
          )
          --only update cash awards for records we haven't already touched, this will prevent overwriting what we did above for PPs with individual cash awards
          AND a.Cost IS NULL;


    --#######################################
    -- More Complex Calculations Section
    --#######################################


    --[CivilianEmployerShareRetirement] 
    UPDATE #Cost
    SET Cost = b.AmountPaid,
        PersonnelCount = b.PersonnelCount
    FROM #Cost AS a
        INNER JOIN
        (
            SELECT PayPlan,
                   OccupationalSeriesNumber,
                   Country,
                   STRL,
                   GradeLevel,
                   LocationId,
                   AVG(AmountPaid) * 26 AS AmountPaid,
                   COUNT(DISTINCT PersonnelNumber) AS PersonnelCount
            FROM #WorkInProgress
            WHERE CostElementCode IN ( '6100.12Y0', '6400.12L0', '6400.12M0', '6400.12X0' )
                  --doesn't apply to hourly employees per FMR Vol8 Ch10 6.7 (100607)
                  AND PayPlan IN
                      (
                          SELECT PayPlan FROM #PPBasePayRules WHERE frequency = 'annual'
                      )
            GROUP BY PayPlan,
                     OccupationalSeriesNumber,
                     Country,
                     STRL,
                     GradeLevel,
                     LocationId
        ) AS b
            ON a.PayPlan = b.PayPlan
               AND a.OccupationalSeriesNumber = b.OccupationalSeriesNumber
               AND a.LocationId = b.LocationId
               AND a.GradeLevel = b.GradeLevel
               AND a.STRL = b.STRL
    WHERE a.CostElementId IN
          (
              SELECT CostElementId
              FROM lookup.CostElement
              WHERE CostElementName LIKE '%6100.12Y%'
                    AND PayPlan IN
                        (
                            SELECT PayPlan FROM #PPBasePayRules
                        )
          );
    --for records where 12k is missing for some reason we use an average to fill in the blanks

    UPDATE #Cost
    SET Cost = b.Amount,
        PersonnelCount = 1
    FROM #Cost AS a
        INNER JOIN
        (
            SELECT PayPlan,
                   GradeLevel,
                   SUM(Cost * PersonnelCount) / SUM(PersonnelCount) AS Amount
            FROM #Cost
            WHERE CostElementId IN
                  (
                      SELECT CostElementId
                      FROM lookup.CostElement
                      WHERE CostElementName LIKE '%6100.12Y%'
                            AND PayPlan IN
                                (
                                    SELECT PayPlan FROM #PPBasePayRules
                                )
                  )
                  AND ISNULL(Cost, 0) > 0
            GROUP BY PayPlan,
                     GradeLevel
        ) AS b
            ON a.PayPlan = b.PayPlan
               AND a.GradeLevel = b.GradeLevel
    WHERE a.CostElementId IN
          (
              SELECT CostElementId
              FROM lookup.CostElement
              WHERE CostElementName LIKE '%6100.12Y%'
                    AND PayPlan IN
                        (
                            SELECT PayPlan FROM #PPBasePayRules
                        )
          )
          AND ISNULL(a.Cost, 0) = 0;

    --FEHB 
    UPDATE #Cost
    SET Cost = b.AmountPaid,
        PersonnelCount = b.PersonnelCount
    FROM #Cost AS a
        INNER JOIN
        (
            SELECT a.PayPlan,
                   a.OccupationalSeriesNumber,
                   a.Country,
                   a.STRL,
                   a.GradeLevel,
                   a.LocationId,
                   CASE
                       WHEN a.PayPlan IN
                            (
                                SELECT PayPlan FROM #PPBasePayRules WHERE frequency = 'annual'
                            ) THEN
                           AVG(AmountPaid) * 26
                       ELSE
                           ISNULL(SUM(AmountPaid) / NULLIF(SUM(b.PaidHours), 0), @ZeroValue)
                   END AS AmountPaid,
                   COUNT(DISTINCT a.PersonnelNumber) AS PersonnelCount
            FROM #WorkInProgress AS a
                LEFT OUTER JOIN
                (
                    SELECT PersonnelNumber,
                           SUM(PaidHours) AS PaidHours
                    FROM #WorkInProgress
                    WHERE CostElementCode IN ( '6100.11B1', '6100.11B3' )
                    GROUP BY PersonnelNumber
                    --65 comes from FMR Vol8 Ch10 6.9 which states 130 hrs/month for 90 days but we only have one pay period so we halve that and make an assumption
                    HAVING SUM(PaidHours) >= 65
                ) AS b
                    ON b.PersonnelNumber = a.PersonnelNumber
            WHERE a.CostElementCode = '6400.12N0'
            GROUP BY a.PayPlan,
                     a.OccupationalSeriesNumber,
                     a.Country,
                     a.STRL,
                     a.GradeLevel,
                     a.LocationId
        ) AS b
            ON a.PayPlan = b.PayPlan
               AND a.OccupationalSeriesNumber = b.OccupationalSeriesNumber
               AND a.LocationId = b.LocationId
               AND a.GradeLevel = b.GradeLevel
               AND a.STRL = b.STRL
    WHERE a.CostElementId IN
          (
              SELECT CostElementId
              FROM lookup.CostElement
              WHERE CostElementName LIKE '%6400.12N0%'
                    AND PayPlan IN
                        (
                            SELECT PayPlan FROM #PPBasePayRules
                        )
          );

    --for records where 12n is missing for some reason we use an average to fill in the blanks
    --same exception for AD
    UPDATE #Cost
    SET Cost = b.Amount,
        PersonnelCount = 1
    FROM #Cost AS a
        INNER JOIN
        (
            SELECT PayPlan,
                   GradeLevel,
                   SUM(Cost * PersonnelCount) / SUM(PersonnelCount) AS Amount
            FROM #Cost
            WHERE CostElementId IN
                  (
                      SELECT CostElementId
                      FROM lookup.CostElement
                      WHERE CostElementName LIKE '%6400.12N0%'
                            AND PayPlan IN
                                (
                                    SELECT PayPlan FROM #PPBasePayRules
                                )
                  )
                  AND ISNULL(Cost, 0) > 0
            GROUP BY PayPlan,
                     GradeLevel
        ) AS b
            ON a.PayPlan = b.PayPlan
               AND a.GradeLevel = b.GradeLevel
    WHERE a.CostElementId IN
          (
              SELECT CostElementId
              FROM lookup.CostElement
              WHERE CostElementName LIKE '%6400.12N0%'
                    AND PayPlan IN
                        (
                            SELECT PayPlan FROM #PPBasePayRules
                        )
          )
          AND ISNULL(a.Cost, 0) = 0;


    --FICA

    DECLARE @PercentSocialSecurity NUMERIC(9, 8)
        = crunch.GetSingleValue('AA', 'PercentSocialSecurity', @AmcosVersionId);
    DECLARE @Max_Wage_SSW NUMERIC(6, 0) = crunch.GetSingleValue('AA', 'Max_Wage_SSW', @AmcosVersionId);
    DECLARE @MaxSocialSecurityDeduction NUMERIC(18, 2) = @PercentSocialSecurity * @Max_Wage_SSW;
    DECLARE @Medicare NUMERIC(18, 4) = crunch.GetSingleValue('AA', 'percentMedicare', @AmcosVersionId);

    UPDATE #Cost
    SET Cost = CASE
                   WHEN b.AmountPaid * @PercentSocialSecurity > @MaxSocialSecurityDeduction THEN
                       @MaxSocialSecurityDeduction
                   ELSE
                       b.AmountPaid * @PercentSocialSecurity
               END + (b.AmountPaid * @Medicare)
    FROM #Cost AS a
        INNER JOIN
        (
            SELECT PayPlan,
                   OccupationalSeriesNumber,
                   LocationId,
                   STRL,
                   GradeLevel,
                   ISNULL(SUM(Cost), 0) AS AmountPaid
            FROM #Cost
            WHERE CostElementId IN
                  (
                      SELECT CostElementId
                      FROM lookup.CostElement
                      WHERE (
                                CostElementName LIKE '%6100.11B1%'
                                OR CostElementName LIKE '%6100.11B3%'
                                OR CostElementName LIKE '%locality%'
                                OR CostElementName LIKE '%6100.11H0%'
                                OR CostElementName LIKE '%6100.11J0%'
                                OR CostElementName LIKE '%6100.11K0%'
                                OR CostElementName LIKE '%6100.11N0%'
                                OR CostElementName LIKE '%6100.11Q0%'
                                OR CostElementName LIKE '%6100.11T0%'
                                OR CostElementName LIKE '%6100.12B0%'
                                OR CostElementName LIKE '%6100.12C0%'
                            )
                            AND PayPlan IN
                                (
                                    SELECT PayPlan FROM #PPBasePayRules
                                )
                  /*

                   'Civ Base Pay (6100.11B1)', 'Civ Locality Pay',
                                             'Civ Hazardous Duty Pay (6100.11H0)',
                                             'Civ Post Differential Pay (O/S Hardship Post) (6100.11J0)',
                                             'Civ Cash Awards Pay (6100.11K0)',
                                             'Civ Title 38:  Medical Premium Pay (6100.11N0)',
                                             'Civ Supervisory Special Pay (6100.11Q0)',
                                             'Civ Physician Comparability Pay (Market Pay) (6100.11T0)',
                                             'Civ Overseas Allowances (Civ Quarters, COLA, LQA, & Other not classified) (6100.12B0)',
                                             'Civ Non-Foreign COLA (Cost of Living Allowance) Pay (6100.12C0)'
                  */

                  )
            GROUP BY PayPlan,
                     OccupationalSeriesNumber,
                     LocationId,
                     STRL,
                     GradeLevel
        ) AS b
            ON a.PayPlan = b.PayPlan
               AND a.OccupationalSeriesNumber = b.OccupationalSeriesNumber
               AND a.LocationId = b.LocationId
               AND a.GradeLevel = b.GradeLevel
               AND a.STRL = b.STRL
    WHERE a.CostElementId IN
          (
              SELECT CostElementId
              FROM lookup.CostElement
              WHERE CostElementName LIKE '%6400.12Q0%'
                    AND PayPlan IN
                        (
                            SELECT PayPlan FROM #PPBasePayRules
                        )
          );


    --The FICA num records should simply be the same number as 11b1 records
    UPDATE #Cost
    SET PersonnelCount = b.PersonnelCount
    FROM #Cost AS a
        INNER JOIN
        (
            SELECT *
            FROM #Cost
            WHERE CostElementName LIKE '%6100.11B1%'
                  AND PayPlan IN
                      (
                          SELECT PayPlan FROM #PPBasePayRules WHERE _11b1 = 1
                      )
                  OR CostElementName LIKE '%6100.11B3%'
                     AND PayPlan IN
                         (
                             SELECT PayPlan FROM #PPBasePayRules WHERE _11b3 = 1
                         )
        ) AS b
            ON a.PayPlan = b.PayPlan
               AND a.OccupationalSeriesNumber = b.OccupationalSeriesNumber
               AND a.LocationId = b.LocationId
               AND a.STRL = b.STRL
               AND a.GradeLevel = b.GradeLevel
    WHERE a.CostElementId IN
          (
              SELECT CostElementId
              FROM lookup.CostElement
              WHERE CostElementName LIKE '%6400.12Q0%'
                    AND PayPlan IN
                        (
                            SELECT PayPlan FROM #PPBasePayRules
                        )
          );

    IF @debug = 1
    BEGIN
        SELECT 'raw table before averging';
        SELECT *
        FROM #WorkInProgress;

        SELECT 'cost table';
        SELECT *
        FROM #Cost
        WHERE CostElementName LIKE '%11h%';

        SELECT 'These cost elements are not  being calculated for some reason';
        SELECT DISTINCT
               PayPlan,
               GradeLevel,
               CostElementName
        FROM #Cost
        WHERE Cost IS NULL
        ORDER BY CostElementName,
                 GradeLevel,
                 PayPlan;

        SELECT 'More detail on the records not being calculated';
        SELECT DISTINCT
               PayPlan,
               OccupationalSeriesNumber,
               GradeLevel,
               LocationId,
               CostElementId,
               CostElementName
        FROM #Cost
        WHERE Cost IS NULL
        ORDER BY CostElementName,
                 PayPlan,
                 OccupationalSeriesNumber,
                 GradeLevel,
                 LocationId;

        SELECT 'count records by pay plan';
        SELECT PayPlan,
               COUNT(*) AS mycount
        FROM #Cost
        GROUP BY PayPlan
        ORDER BY PayPlan ASC;


        SELECT 'entire table ordered by cost';
        SELECT *
        FROM #Cost
        ORDER BY Cost ASC;


        SELECT 'entire table ordered by costelement then pay plan';
        SELECT *
        FROM #Cost
        ORDER BY CostElementName,
                 PayPlan,
                 GradeLevel;

        SELECT 'these records to be deleted for lack of valid cost';
        SELECT *
        FROM #Cost
        WHERE ISNULL(Cost, 0) = 0
        ORDER BY CostElementName,
                 PayPlan,
                 LocationId,
                 GradeLevel;
    END;


    --remove any negative costs
    --3/7/2024 adjusted this to remove only negative costs instead of include 0 costs
    --reason is we need the zero costs and their inventory for proper averaging
    UPDATE #Cost
    SET Cost = 0
    WHERE Cost IS NULL;

    DELETE FROM #Cost
    --previously:
    --WHERE ISNULL(Cost, 0) <= 0
    --      OR ISNULL(PersonnelCount, 0) <= 0;
    WHERE ISNULL(Cost, 0) < 0;


    --bring in country/locality acronym codes
    UPDATE #Cost
    SET LocalityCode = b.SourceSystemCode,
        Country = '-1'
    FROM #Cost AS a
        INNER JOIN warehouse.Location AS b
            ON b.LocationId = a.LocationId
    WHERE b.LocationType = 'Locality Pay Area';

    UPDATE #Cost
    SET Country = b.SourceSystemCode,
        LocalityCode = '-1'
    FROM #Cost AS a
        INNER JOIN warehouse.Location AS b
            ON b.LocationId = a.LocationId
    WHERE b.LocationType = 'GFEBS Country';

    SELECT 'TEST TEST TEST';
    SELECT *
    FROM #Cost
    WHERE PayPlan = 'NH'
          AND OccupationalSeriesNumber = '1670'
          AND GradeLevel = 4;

    IF @debug = 0
    BEGIN
        DELETE FROM crunch.Costs_GFEBS
        WHERE AmcosVersionId = @AmcosVersionId;

        --insert series/location level costs
        INSERT INTO crunch.Costs_GFEBS
        (
            PayPlan,
            OccupationalGroupNumber,
            OccupationalSeriesNumber,
            CareerProgramNumber,
            CostElementId,
            GradeLevel,
            LocationId,
            STRL,
            Amount,
            CrunchTime,
            AmcosVersionId,
            LocalityCode,
            Country
        )
        SELECT PayPlan,
               OccupationalGroupNumber,
               OccupationalSeriesNumber,
               -1,
               CostElementId,
               GradeLevel,
               LocationId,
               STRL,
               Cost,
               @CrunchTime,
               @AmcosVersionId,
               LocalityCode,
               Country
        FROM #Cost
        WHERE Cost > 0;

        --insert series level costs without location
        INSERT INTO crunch.Costs_GFEBS
        (
            PayPlan,
            OccupationalGroupNumber,
            OccupationalSeriesNumber,
            CareerProgramNumber,
            CostElementId,
            GradeLevel,
            LocationId,
            STRL,
            Amount,
            CrunchTime,
            AmcosVersionId,
            LocalityCode,
            Country
        )
        SELECT PayPlan,
               OccupationalGroupNumber,
               OccupationalSeriesNumber,
               -1,
               CostElementId,
               GradeLevel,
               -1,
               STRL,
               SUM(Cost * Inventory) / SUM(Inventory),
               @CrunchTime,
               @AmcosVersionId,
               '-1',
               '-1'
        FROM #Cost
        WHERE Cost > 0
        GROUP BY PayPlan,
                 OccupationalGroupNumber,
                 OccupationalSeriesNumber,
                 CostElementId,
                 GradeLevel,
                 STRL;





        --compute and insert group level costs by location
        --note that the STRL stays in the group by, this is because D series (which have an STRL) should not be aggregated above the STRL level since
        --payschedules vary by STRL
        INSERT INTO crunch.Costs_GFEBS
        (
            PayPlan,
            OccupationalGroupNumber,
            OccupationalSeriesNumber,
            CareerProgramNumber,
            CostElementId,
            GradeLevel,
            LocationId,
            STRL,
            Amount,
            CrunchTime,
            AmcosVersionId,
            LocalityCode,
            Country
        )
        SELECT PayPlan,
               OccupationalGroupNumber,
               '-1',
               -1,
               CostElementId,
               GradeLevel,
               LocationId,
               STRL,
               SUM(Cost * Inventory) / SUM(Inventory),
               @CrunchTime,
               @AmcosVersionId,
               LocalityCode,
               Country
        FROM #Cost
        WHERE Cost > 0
        GROUP BY PayPlan,
                 OccupationalGroupNumber,
                 CostElementId,
                 GradeLevel,
                 LocationId,
                 STRL,
                 LocalityCode,
                 Country;

        --compute and insert group level costs without location
        --note that the STRL stays in the group by, this is because D series (which have an STRL) should not be aggregated above the STRL level since
        --payschedules vary by STRL
        INSERT INTO crunch.Costs_GFEBS
        (
            PayPlan,
            OccupationalGroupNumber,
            OccupationalSeriesNumber,
            CareerProgramNumber,
            CostElementId,
            GradeLevel,
            LocationId,
            STRL,
            Amount,
            CrunchTime,
            AmcosVersionId,
            LocalityCode,
            Country
        )
        SELECT PayPlan,
               OccupationalGroupNumber,
               '-1',
               -1,
               CostElementId,
               GradeLevel,
               -1,
               STRL,
               SUM(Cost * Inventory) / SUM(Inventory),
               @CrunchTime,
               @AmcosVersionId,
               '-1',
               '-1'
        FROM #Cost AS a
        WHERE Cost > 0
        GROUP BY PayPlan,
                 OccupationalGroupNumber,
                 CostElementId,
                 GradeLevel,
                 STRL;

        --compute and insert payplan levels costs without location
        --same STRL comment as in the insert above
        INSERT INTO crunch.Costs_GFEBS
        (
            PayPlan,
            OccupationalGroupNumber,
            OccupationalSeriesNumber,
            CareerProgramNumber,
            CostElementId,
            GradeLevel,
            LocationId,
            STRL,
            Amount,
            CrunchTime,
            AmcosVersionId,
            LocalityCode,
            Country
        )
        SELECT PayPlan,
               '-1',
               '-1',
               -1,
               CostElementId,
               GradeLevel,
               -1,
               STRL,
               SUM(Cost * Inventory) / SUM(Inventory),
               @CrunchTime,
               @AmcosVersionId,
               '-1',
               '-1-'
        FROM #Cost
        WHERE Cost > 0
        GROUP BY PayPlan,
                 CostElementId,
                 GradeLevel,
                 STRL;

        --compute and insert payplan levels costs with location
        --same STRL comment as in the insert above
        INSERT INTO crunch.Costs_GFEBS
        (
            PayPlan,
            OccupationalGroupNumber,
            OccupationalSeriesNumber,
            CareerProgramNumber,
            CostElementId,
            GradeLevel,
            LocationId,
            STRL,
            Amount,
            CrunchTime,
            AmcosVersionId,
            LocalityCode,
            Country
        )
        SELECT PayPlan,
               '-1',
               '-1',
               -1,
               CostElementId,
               GradeLevel,
               LocationId,
               STRL,
               SUM(Cost * Inventory) / SUM(Inventory),
               @CrunchTime,
               @AmcosVersionId,
               LocalityCode,
               Country
        FROM #Cost
        WHERE Cost > 0
        GROUP BY PayPlan,
                 CostElementId,
                 GradeLevel,
                 LocationId,
                 STRL,
                 LocalityCode,
                 Country;

        --insert career program level average costs without location
        INSERT INTO crunch.Costs_GFEBS
        (
            PayPlan,
            OccupationalGroupNumber,
            OccupationalSeriesNumber,
            CareerProgramNumber,
            CostElementId,
            GradeLevel,
            LocationId,
            STRL,
            Amount,
            CrunchTime,
            AmcosVersionId,
            LocalityCode,
            Country
        )
        SELECT PayPlan,
               '-1',
               '-1',
               CareerProgramNumber,
               CostElementId,
               GradeLevel,
               -1,
               STRL,
               SUM(Cost * Inventory) / SUM(Inventory),
               @CrunchTime,
               @AmcosVersionId,
               '-1',
               '-1'
        FROM
        (
            SELECT a.*,
                   b.CareerProgramNumber
            FROM #Cost AS a
                INNER JOIN xwalk.OccupationalSeriesToCareerProgram AS b
                    ON b.OccupationalSeriesNumber = a.OccupationalSeriesNumber
            WHERE @AmcosVersionId
            BETWEEN b.AmcosVersionIdStart AND b.AmcosVersionIdEnd
        ) AS a
        WHERE Cost > 0
        GROUP BY PayPlan,
                 CostElementId,
                 GradeLevel,
                 STRL,
                 CareerProgramNumber;

        --insert career program level average costs with location
        INSERT INTO crunch.Costs_GFEBS
        (
            PayPlan,
            OccupationalGroupNumber,
            OccupationalSeriesNumber,
            CareerProgramNumber,
            CostElementId,
            GradeLevel,
            LocationId,
            STRL,
            Amount,
            CrunchTime,
            AmcosVersionId,
            LocalityCode,
            Country
        )
        SELECT PayPlan,
               '-1',
               '-1',
               CareerProgramNumber,
               CostElementId,
               GradeLevel,
               LocationId,
               STRL,
               SUM(Cost * Inventory) / SUM(Inventory),
               @CrunchTime,
               @AmcosVersionId,
               LocalityCode,
               Country
        FROM
        (
            SELECT a.*,
                   b.CareerProgramNumber
            FROM #Cost AS a
                INNER JOIN xwalk.OccupationalSeriesToCareerProgram AS b
                    ON b.OccupationalSeriesNumber = a.OccupationalSeriesNumber
            WHERE @AmcosVersionId
            BETWEEN b.AmcosVersionIdStart AND b.AmcosVersionIdEnd
        ) AS a
        WHERE Cost > 0
        GROUP BY PayPlan,
                 CareerProgramNumber,
                 CostElementId,
                 GradeLevel,
                 LocationId,
                 STRL,
                 LocalityCode,
                 Country;


        --added 3/7/2024 to get rid of the zero costs we allowed in to make averaging work correctly
        DELETE FROM crunch.Costs_GFEBS
        WHERE Amount = 0
              AND AmcosVersionId = @AmcosVersionId;


    END;


END;
GO
