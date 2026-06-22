
-- =============================================
-- Author:		Dan Hogan
-- Create date: 10/11/2019
-- Description:	Crunch Proc for wage pay plans
-- History
-- 3/2/2020 - added overtime pay cost element and calculation based on guidance from Marsha Popp (COTR)
-- =============================================
CREATE PROCEDURE [crunch].[CrunchWage]
    @AmcosVersionId INT = -1,
    @debug BIT = 0
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @AnnualHours NUMERIC(18, 2) = crunch.GetSingleValue('GP', 'annualpaidhours', @AmcosVersionId);

    /* This crunch is only for the following pay plans:
	NA, NL, NS, WA, WB, WD, WG, WJ, WK, WL, WN, WO, WQ, WR, WS, WT, WU, WY, XF, XG, XH, XR, XT, XU
	*/
    DROP TABLE IF EXISTS #PayPlans;
    CREATE TABLE #PayPlans
    (
        PayPlan NVARCHAR(2) NOT NULL,
        DisplayTitle NVARCHAR(100) NOT NULL,
        Explanation NVARCHAR(500) NOT NULL
    );

    INSERT INTO #PayPlans
    (
        PayPlan,
        DisplayTitle,
        Explanation
    )
    SELECT PayPlan,
           DisplayTitle,
           Explanation
    FROM lookup.PayPlan
    WHERE PayPlan IN
          (
              SELECT PayPlan FROM lookup.PayPlanTags WHERE Tag = 'Wage'
          )
          AND @AmcosVersionId
          BETWEEN AmcosVersionIdStart AND AmcosVersionIdEnd;


    IF @debug = 1
    BEGIN
        SELECT 'crunch will process the following pay plans';
        SELECT *
        FROM #PayPlans
        ORDER BY PayPlan;
    END;

    /* Wage is broken out into:
	   Pay Plans we do have a payschedule for: NA, NL, NS, WA, WD, WG, WL, WN, WO, WS, WY, XF, XG, XH, XR, XT, XU
	   Pay Plans we do not have a payschedule for WB, WJ, WK, WQ, WR, WT, WU */

    /* WASS pay needs to be aggregated up to the series/location/gradelevel/step first before
	   we can use it, so let's create its own table to make it more transparent */

    DROP TABLE IF EXISTS #WageInventory;
    CREATE TABLE #WageInventory
    (
        PayPlan NVARCHAR(3) NOT NULL,
        FundType NVARCHAR(3) NOT NULL,
        OccupationalGroupNumber NVARCHAR(4) NOT NULL,
        OccupationalSeriesNumber NVARCHAR(4) NOT NULL,
        GradeLevel INT NOT NULL,
        Step INT NOT NULL,
        LocationId INT NOT NULL,
        LocationType NVARCHAR(500) NOT NULL,
        LocationName NVARCHAR(500) NULL,
        Inventory INT NOT NULL,
        Salary NUMERIC(18, 2) NULL,
        AmcosVersionId INT NOT NULL
    );

    /* Insert inventory for Appropriated Fund pay plans from WASS */
    INSERT INTO #WageInventory
    (
        PayPlan,
        FundType,
        OccupationalGroupNumber,
        OccupationalSeriesNumber,
        GradeLevel,
        Step,
        LocationId,
        LocationType,
        LocationName,
        Inventory,
        Salary,
        AmcosVersionId
    )
    SELECT a.PayPlan,
           'AF',
           a.OccupationalGroupNumber,
           a.OccupationalSeriesNumber,
           a.GradeLevel,
           a.Step,
           a.LocationId,
           b.LocationType,
           b.DisplayName,
           a.Inventory,
           a.AveragePay * @AnnualHours,
           a.AmcosVersionId
    FROM crunch.InventoryWASS AS a
        LEFT OUTER JOIN warehouse.Location AS b
            ON a.LocationId = b.LocationId
    WHERE a.PayPlan IN
          (
              SELECT PayPlan FROM lookup.PayPlanTags WHERE Tag = 'WASS'
          )
          AND a.PayPlan IN
              (
                  SELECT PayPlan FROM lookup.PayPlanTags WHERE Tag = 'Wage AF'
              )
          AND a.AmcosVersionId = @AmcosVersionId
          AND b.LocationType = 'Federal Wage System AF';
	IF @debug = 1 BEGIN
		SELECT 'Make sure we have no values in the table below 1'
		SELECT a.PayPlan,
			   'AF',
			   a.OccupationalGroupNumber,
			   a.OccupationalSeriesNumber,
			   a.GradeLevel,
			   a.Step,
			   a.LocationId,
			   b.LocationType,
			   b.DisplayName,
			   a.Inventory,
			   a.AveragePay * @AnnualHours,
			   a.AmcosVersionId
		FROM crunch.InventoryWASS AS a
			LEFT OUTER JOIN warehouse.Location AS b
				ON a.LocationId = b.LocationId
		WHERE a.PayPlan IN
			  (
				  SELECT PayPlan FROM lookup.PayPlanTags WHERE Tag = 'WASS'
			  )
			  AND a.PayPlan IN
				  (
					  SELECT PayPlan FROM lookup.PayPlanTags WHERE Tag = 'Wage AF'
				  )
			  AND a.AmcosVersionId = @AmcosVersionId
			  AND b.LocationType = 'Federal Wage System AF'
			  AND b.DisplayName IS NULL;
	END


    /* Insert inventory for Appropriated Fund pay plans from DMDC */
    INSERT INTO #WageInventory
    (
        PayPlan,
        FundType,
        OccupationalGroupNumber,
        OccupationalSeriesNumber,
        GradeLevel,
        Step,
        LocationId,
        LocationType,
        LocationName,
        Inventory,
        AmcosVersionId
    )
    SELECT a.PayPlan,
           'AF',
           a.CategoryGroup,
           a.CategorySubgroup,
           a.GradeLevel,
           a.Step,
           a.LocationId,
           b.LocationType,
           b.DisplayName,
           a.Inventory,
           a.AmcosVersionId
    FROM crunch.InventoryDMDC AS a
        LEFT OUTER JOIN warehouse.Location AS b
            ON a.LocationId = b.LocationId
    WHERE a.PayPlan IN
          (
              SELECT PayPlan FROM lookup.PayPlanTags WHERE Tag = 'DMDC'
          )
          AND a.PayPlan IN
              (
                  SELECT PayPlan FROM lookup.PayPlanTags WHERE Tag = 'Wage AF'
              )
          AND a.AmcosVersionId = @AmcosVersionId
          AND b.LocationType IN ( 'Federal Wage System AF', 'Federal Wage System AF Overseas' );

    /* Insert inventory for Nonappropriated Fund (NAF) pay plans from WASS
	Exclude CY, NF because they are handled in a separate procedure    */
    INSERT INTO #WageInventory
    (
        PayPlan,
        FundType,
        OccupationalGroupNumber,
        OccupationalSeriesNumber,
        GradeLevel,
        Step,
        LocationId,
        LocationType,
        LocationName,
        Inventory,
        Salary,
        AmcosVersionId
    )
    SELECT a.PayPlan,
           'NAF',
           a.OccupationalGroupNumber,
           a.OccupationalSeriesNumber,
           a.GradeLevel,
           a.Step,
           a.LocationId,
           b.LocationType,
           b.DisplayName,
           a.Inventory,
           a.AveragePay * @AnnualHours,
           a.AmcosVersionId
    FROM crunch.InventoryWASS AS a
        LEFT OUTER JOIN warehouse.Location AS b
            ON a.LocationId = b.LocationId
    WHERE a.PayPlan IN
          (
              SELECT PayPlan FROM lookup.PayPlanTags WHERE Tag = 'WASS'
          )
          AND a.PayPlan IN
              (
                  SELECT PayPlan FROM lookup.PayPlanTags WHERE Tag = 'Wage NAF'
              )
          AND a.PayPlan NOT IN ( 'CY', 'NF' )
          AND a.AmcosVersionId = @AmcosVersionId
          AND b.LocationType IN ( 'Federal Wage System NAF' );

	IF @debug = 1 BEGIN
		SELECT 'Make sure there are no null values for location in WageInventory'
		SELECT * FROM #WageInventory WHERE locationName IS NULL
	END

    /* Insert inventory for Nonappropriated Fund (NAF) pay plans from DMDC
	Exclude CY, NF because they are handled in a separate procedure */
    INSERT INTO #WageInventory
    (
        PayPlan,
        FundType,
        OccupationalGroupNumber,
        OccupationalSeriesNumber,
        LocationId,
        LocationName,
        LocationType,
        GradeLevel,
        Step,
        Inventory,
        AmcosVersionId
    )
    SELECT a.PayPlan,
           'NAF',
           a.CategoryGroup,
           a.CategorySubgroup,
           a.LocationId,
           b.DisplayName,
           b.LocationType,
           a.GradeLevel,
           a.Step,
           a.Inventory,
           a.AmcosVersionId
    FROM crunch.InventoryDMDC AS a
        LEFT OUTER JOIN warehouse.Location AS b
            ON a.LocationId = b.LocationId
    WHERE a.PayPlan IN
          (
              SELECT PayPlan FROM lookup.PayPlanTags WHERE Tag = 'DMDC'
          )
          AND a.PayPlan IN
              (
                  SELECT PayPlan FROM lookup.PayPlanTags WHERE Tag = 'Wage NAF'
              )
          AND a.PayPlan NOT IN ( 'CY', 'NF' )
          AND a.AmcosVersionId = @AmcosVersionId
          AND b.LocationType IN ( 'Federal Wage System NAF', 'Federal Wage System NAF Overseas' );

    IF @debug = 1
    BEGIN
        SELECT 'Distinct Pay Plans from #WageInventory';
        SELECT *
        FROM #WageInventory
        ORDER BY PayPlan;
    END;
    /* create the pay and inventory combined table */
    DROP TABLE IF EXISTS #PayAndInventory;
    CREATE TABLE #PayAndInventory
    (
        PayPlan NVARCHAR(2) NOT NULL,
        FundType NVARCHAR(3) NOT NULL,
        OccupationalSeriesNumber NVARCHAR(4) NOT NULL,
        ScheduleArea NVARCHAR(4) NOT NULL,
        LocationId INT NOT NULL,
        LocationType NVARCHAR(500) NOT NULL,
        LocationName NVARCHAR(500) NOT NULL,
        GradeLevel INT NOT NULL,
        Step INT NOT NULL,
        Inventory INT NULL
            DEFAULT 0,
        SalaryWass NUMERIC(18, 2) NULL,
        SalaryPaySchedule NUMERIC(18, 2) NULL,
        NumberOfDependents INT NOT NULL
            DEFAULT-1,
        DataSource NVARCHAR(50) NOT NULL,
        AmcosVersionId INT NOT NULL
    );

    /* start with the payschedule data and join it with the location and occ
       series from inventory so we don't end up with millions of records, just
       the records that are valid based on inventory */
    INSERT INTO #PayAndInventory
    (
        PayPlan,
        FundType,
        OccupationalSeriesNumber,
        ScheduleArea,
        LocationId,
        LocationType,
        LocationName,
        GradeLevel,
        Step,
        Inventory,
        SalaryPaySchedule,
        NumberOfDependents,
        DataSource,
        AmcosVersionId
    )
    SELECT a.PayPlan,
           a.FundType,
           b.OccupationalSeriesNumber,
           a.AreaCode,
           a.LocationId,
           c.LocationType,
           c.DisplayName,
           a.GradeLevel,
           a.Step,
           ISNULL(b.Inventory, 0),
           a.SalaryPaySchedule,
           -1 AS NumberOfDependents,
           'Inventory',
           @AmcosVersionId
    FROM
    (
        SELECT PayPlan,
               a.FundType,
               AreaCode,
               LocationId,
               GradeLevel,
               Step,
               Rate * @AnnualHours AS SalaryPaySchedule
        FROM PaySchedule.PaySchedule_Wage a
            INNER JOIN lookup.WageArea b
                ON a.AreaCode = b.ScheduleArea
        WHERE AmcosVersionId = @AmcosVersionId
              AND b.AreaName <> 'Foreign Areas' --foreign areas will be handled seperately
    ) AS a
        INNER JOIN
        (
            SELECT PayPlan,
                   FundType,
                   LocationId,
                   OccupationalSeriesNumber,
                   GradeLevel,
                   Step,
                   SUM(Inventory) AS Inventory
            FROM #WageInventory
            GROUP BY PayPlan,
                     FundType,
                     LocationId,
                     OccupationalSeriesNumber,
                     GradeLevel,
                     Step
        ) AS b
            ON a.PayPlan = b.PayPlan
               AND a.LocationId = b.LocationId
               AND a.GradeLevel = b.GradeLevel
               AND a.Step = b.Step
        LEFT OUTER JOIN warehouse.Location AS c
            ON a.LocationId = c.LocationId
               AND c.LocationType IN ( 'Federal Wage System AF', 'Federal Wage System NAF' )
    --bring in foreign areas
    UNION
    SELECT a.PayPlan,
           a.FundType,
           b.OccupationalSeriesNumber,
           a.AreaCode,
           e.LocationId,
           e.LocationType,
           e.DisplayName,
           a.GradeLevel,
           a.Step,
           ISNULL(b.Inventory, 0),
           a.Rate * @AnnualHours,
           d.NumberOfDependents,
           'Inventory',
           @AmcosVersionId
    FROM PaySchedule.PaySchedule_Wage AS a
        CROSS JOIN
        ( --only use DoS locations whose CEs will result in a value greater than 1
            SELECT LocationCode,
                   CASE
                       WHEN Amt > 0 THEN
                           1
                       ELSE
                           0
                   END AS costs
            FROM dataload.DoSLivingAllowance
            WHERE AmcosVersionId = @AmcosVersionId
            UNION
            SELECT LocationCode,
                   CASE
                       WHEN DangerPay > 0
                            OR PostAllowance > 0
                            OR Hardship > 0 THEN
                           1
                       ELSE
                           0
                   END AS costs
            FROM dataload.DoSPostAllowance
            WHERE AmcosVersionId = @AmcosVersionId
        ) AS c
        CROSS JOIN
        (
            --get number of possible  dependents 
            SELECT DISTINCT
                   NumberOfDependents
            FROM dataload.MilitarySpendableIncome
            WHERE AmcosVersionId = @AmcosVersionId
        ) AS d
        LEFT OUTER JOIN warehouse.Location AS e
            ON c.LocationCode = e.SourceSystemCode
        INNER JOIN
        (
            SELECT PayPlan,
                   LocationId,
                   OccupationalSeriesNumber,
                   Step,
                   GradeLevel,
                   SUM(Inventory) AS Inventory
            FROM #WageInventory
            GROUP BY PayPlan,
                     LocationId,
                     OccupationalSeriesNumber,
                     Step,
                     GradeLevel
        ) AS b
            ON a.PayPlan = b.PayPlan
               AND e.LocationId = b.LocationId
               AND a.Step = b.Step
               AND a.GradeLevel = b.GradeLevel
    WHERE c.costs = 1
          AND a.AmcosVersionId = @AmcosVersionId
          AND e.LocationType = 'Civilian Overseas'
          AND a.WageArea = 'FA'
          AND a.PayPlan IN ( 'WG', 'WL', 'WS' );

	IF @debug = 1 BEGIN
		SELECT 'Make sure there are no null values for LocationName'
		SELECT a.PayPlan,
           a.FundType,
           b.SourceSystemCode,
           a.LocationId,
           a.LocationName,
           a.LocationType,
           a.GradeLevel,
           a.Step,
           a.Salary,
           a.OccupationalSeriesNumber,
           @AmcosVersionId,
           'Inventory' AS DataSource,
           -1 AS NumberOfDependents,
           a.Inventory
    FROM #WageInventory AS a
        LEFT OUTER JOIN warehouse.Location AS b
            ON a.LocationId = b.LocationId
    WHERE a.PayPlan NOT IN
          (
              SELECT DISTINCT PayPlan FROM #PayAndInventory
          ) AND a.LocationName IS NULL;
	END

    /* Some payschedules we either don't have or are manual entry so we will use WASS as the authoritative source
	   Only insert inventory records where we don't already have a record for them in the payschedules */
    INSERT INTO #PayAndInventory
    (
        PayPlan,
        FundType,
        ScheduleArea,
        LocationId,
        LocationName,
        LocationType,
        GradeLevel,
        Step,
        SalaryWass,
        OccupationalSeriesNumber,
        AmcosVersionId,
        DataSource,
        NumberOfDependents,
        Inventory
    )
    SELECT a.PayPlan,
           a.FundType,
           b.SourceSystemCode,
           a.LocationId,
           a.LocationName,
           a.LocationType,
           a.GradeLevel,
           a.Step,
           a.Salary,
           a.OccupationalSeriesNumber,
           @AmcosVersionId,
           'Inventory' AS DataSource,
           -1 AS NumberOfDependents,
           a.Inventory
    FROM #WageInventory AS a
        LEFT OUTER JOIN warehouse.Location AS b
            ON a.LocationId = b.LocationId
    WHERE a.PayPlan NOT IN
          (
              SELECT DISTINCT PayPlan FROM #PayAndInventory
          );

	
	UPDATE #PayAndInventory SET SalaryWass = b.AveragePay * @AnnualHours FROM
		#PayAndInventory a JOIN crunch.InventoryWASS b 
		ON a.PayPlan = b.PayPlan AND a.LocationId = b.LocationId
		AND a.GradeLevel = b.GradeLevel
		AND a.Step = b.Step
		AND a.OccupationalSeriesNumber =b.OccupationalSeriesNumber
		AND a.SalaryWass IS NULL AND a.SalaryPaySchedule IS NULL	
		
	IF @debug = 1 BEGIN
		SELECT 'Check here to ensure pay information for either wass or payschedule'
		SELECT *
        FROM #PayAndInventory
        WHERE SalaryPaySchedule IS NULL
              AND SalaryWass IS NULL;
	
	END

    /* Fill in the blanks at the pay plan level for any locations missing inventory */
    INSERT INTO #PayAndInventory
    (
        PayPlan,
        FundType,
        OccupationalSeriesNumber,
        ScheduleArea,
        LocationId,
        LocationName,
        LocationType,
        GradeLevel,
        Step,
        Inventory,
        SalaryWass,
        SalaryPaySchedule,
        AmcosVersionId,
        DataSource,
        NumberOfDependents
    )
    SELECT a.PayPlan,
           a.FundType,
           '-1' AS OccupationalSeriesNumber,
           a.AreaCode,
           a.LocationId,
           LocationName,
           LocationType,
           a.GradeLevel,
           a.Step,
           1 AS Inventory,
           NULL AS SalaryWass,
           a.Rate * @AnnualHours,
           @AmcosVersionId,
           'Fill-in',
           a.NumberOfDependents
    FROM
    (
        --first non-overseas
        SELECT a.PayPlan,
               a.FundType,
               a.AreaCode,
               a.LocationId,
               b.DisplayName AS LocationName,
               b.LocationType,
               a.GradeLevel,
               a.Step,
               a.Rate,
               -1 AS NumberOfDependents
        FROM PaySchedule.PaySchedule_Wage AS a
            LEFT OUTER JOIN warehouse.Location AS b
                ON a.LocationId = b.LocationId
        WHERE a.Step = 3
              AND b.LocationType IN ( 'Federal Wage System AF', 'Federal Wage System NAF' )
              AND a.LocationId <> -1
              AND a.AmcosVersionId = @AmcosVersionId
        UNION
        /* Federal Wage System AF Overseas and Federal Wage System NAF Overseas */
        SELECT a.PayPlan,
               a.FundType,
               a.AreaCode,
               b.LocationId,
               b.DisplayName,
               b.LocationType,
               a.GradeLevel,
               a.Step,
               a.Rate,
               d.NumberOfDependents
        FROM PaySchedule.PaySchedule_Wage AS a
            LEFT OUTER JOIN warehouse.Location AS b
                ON a.LocationId = b.LocationId
            CROSS JOIN
            (
                --get number of possible  dependents 
                SELECT DISTINCT
                       NumberOfDependents
                FROM dataload.MilitarySpendableIncome
                WHERE AmcosVersionId = @AmcosVersionId
            ) AS d
        WHERE a.Step = 3
              AND b.LocationType IN ( 'Federal Wage System AF Overseas', 'Federal Wage System NAF Overseas' )
              AND a.LocationId <> -1
              AND a.AmcosVersionId = @AmcosVersionId
    ) AS a
    WHERE NOT EXISTS
    (
        SELECT DISTINCT
               PayPlan,
               GradeLevel,
               LocationId
        FROM #PayAndInventory AS z
        WHERE z.PayPlan = a.PayPlan
              AND z.GradeLevel = a.GradeLevel
              AND z.LocationId = a.LocationId
			  
    ) and a.LocationName IS NOT NULL;

    IF @debug = 1
    BEGIN
        SELECT 'these records to be deleted as not having actual or fill in the blank inventory';
        SELECT *
        FROM #PayAndInventory
        WHERE Inventory = 0
        ORDER BY PayPlan,
                 ScheduleArea,
                 OccupationalSeriesNumber,
                 GradeLevel,
                 Step;
    END;

    --now any results that remain without inventory of at least one are records we no longer need so we delete them
    DELETE FROM #PayAndInventory
    WHERE Inventory = 0;

    IF @debug = 1
    BEGIN
        SELECT 'pay and inventory table before cost computations';
        SELECT *
        FROM #PayAndInventory
        ORDER BY PayPlan,
                 ScheduleArea,
                 OccupationalSeriesNumber,
                 GradeLevel,
                 Step;
    END;

    --If we have a record without a payschedule or wass pay then we need to call it out and full stop
    IF EXISTS
    (
        SELECT *
        FROM #PayAndInventory
        WHERE SalaryPaySchedule IS NULL
              AND SalaryWass IS NULL
              --9/17/25 DCPAS stopped issuing some WB,WQ,WU, and WK pay plans so we need to prevent them from triggering an error
              AND PayPlan not in ('WB','WQ','WU','WK')              
              AND AmcosVersionId = '202501'
    )
    BEGIN
        SELECT 'these records are mising wass pay and a payschedule, they must have one or the other';

        SELECT *
        FROM #PayAndInventory
        WHERE SalaryPaySchedule IS NULL
              AND SalaryWass IS NULL;

        RAISERROR('Missing a pay amount', 18, 1);
        RETURN;
    END;

    --9/17/25 DCPAS stopped issuing some WB,WQ,WU, and WK pay plans so we need to prevent them from triggering an error
    DELETE FROM #PayAndInventory
    WHERE SalaryPaySchedule IS NULL
          AND SalaryWass IS NULL
          AND PayPlan in ('WB','WQ','WU','WK')          
          AND AmcosVersionId = '202501';

    DROP TABLE IF EXISTS #CostsWage;
    CREATE TABLE #CostsWage
    (
        PayPlan NVARCHAR(2) NOT NULL,
        PayPlanTitle NVARCHAR(100) NULL,
        FundType NVARCHAR(3) NOT NULL,
        OccupationalGroupNumber NVARCHAR(4) NOT NULL
            DEFAULT ('0000'),
        OccupationalSeriesNumber NVARCHAR(4) NOT NULL,
        WageArea NVARCHAR(3) NULL,
        ScheduleArea NVARCHAR(4) NOT NULL,
        GradeLevel INT NOT NULL,
        Inventory INT NOT NULL,
        BasePay NUMERIC(18, 2) NOT NULL,
        CostElementId INT NOT NULL,
        CostAmount NUMERIC(16, 2) NULL
            DEFAULT (0),
        AmcosVersionId INT NOT NULL,
        DataSource NVARCHAR(50) NOT NULL,
        LocationId INT NULL,
        LocationCode NVARCHAR(500) NULL,
        LocationType NVARCHAR(500) NULL,
        NumberOfDependents INT NOT NULL,
        Taxable BIT NOT NULL
            DEFAULT (0)
    );
    INSERT INTO #CostsWage
    (
        PayPlan,
        FundType,
        OccupationalSeriesNumber,
        ScheduleArea,
        GradeLevel,
        Inventory,
        BasePay,
        CostElementId,
        AmcosVersionId,
        DataSource,
        NumberOfDependents,
        LocationId,
        LocationCode,
        LocationType
    )
    SELECT a.PayPlan,
           a.FundType,
           a.OccupationalSeriesNumber,
           a.ScheduleArea,
           a.GradeLevel,
           a.Inventory,
           a.BasePay,
           b.CostElementId,
           a.AmcosVersionId,
           a.DataSource,
           a.NumberOfDependents,
           a.LocationId,
           c.SourceSystemCode,
           a.LocationType
    FROM
    (
        SELECT a.PayPlan,
               a.FundType,
               a.OccupationalSeriesNumber,
               a.ScheduleArea,
               a.GradeLevel,
               SUM(a.Inventory) AS Inventory,
               SUM(a.Inventory * ISNULL(a.SalaryPaySchedule, a.SalaryWass)) / SUM(a.Inventory) AS BasePay,
               a.AmcosVersionId,
               DataSource,
               a.NumberOfDependents,
               a.LocationId,
               a.LocationName,
               a.LocationType
        FROM #PayAndInventory AS a
        GROUP BY a.PayPlan,
                 a.FundType,
                 a.OccupationalSeriesNumber,
                 a.ScheduleArea,
                 a.GradeLevel,
                 a.AmcosVersionId,
                 DataSource,
                 a.NumberOfDependents,
                 a.LocationId,
                 a.LocationName,
                 a.LocationType
    ) AS a
        CROSS JOIN lookup.CostElement AS b
        LEFT OUTER JOIN warehouse.Location AS c
            ON a.LocationId = c.LocationId
    WHERE @AmcosVersionId
          BETWEEN b.AmcosVersionIdStart AND b.AmcosVersionIdEnd
          AND b.PayPlan = a.PayPlan;


    ----bring in locatinid for AF
    --UPDATE #CostsWage
    --SET locationid = b.LocationId, locationcode=b.SourceSystemCode,locationtype=b.LocationType
    --FROM #CostsWage AS a
    --    INNER JOIN warehouse.Location AS b
    --        ON a.schedulearea = b.SourceSystemCode
    --WHERE b.LocationType = 'Federal Wage System AF'
    --      AND
    --      (
    --          PayPlan LIKE 'X%'
    --          OR PayPlan LIKE 'W%'
    --      );

    ----bring in locatinid for NAF
    --UPDATE #CostsWage
    --SET locationid = b.LocationId,locationcode=b.SourceSystemCode,locationtype=b.LocationType
    --FROM #CostsWage AS a
    --    INNER JOIN warehouse.Location AS b
    --        ON a.schedulearea = b.SourceSystemCode
    --WHERE b.LocationType = 'Federal Wage System NAF'
    --      AND (PayPlan LIKE 'N%');

    ----bring in locatinid for overseas
    --UPDATE #CostsWage
    --SET locationid = b.LocationId,locationcode=b.SourceSystemCode,locationtype=b.LocationType
    --FROM #CostsWage AS a
    --    INNER JOIN warehouse.Location AS b
    --        ON a.schedulearea = b.SourceSystemCode
    --WHERE b.LocationType = 'Civilian Overseas'


    -- Before move on to costs let's make sure we have a location for all the data so far
    IF EXISTS
    (
        SELECT *
        FROM #CostsWage
        WHERE LocationId IS NULL
              OR LocationId = '-1'
    )
    BEGIN
        SELECT 'these records have invalid location which is not allowed';

        SELECT *
        FROM #CostsWage
        WHERE LocationId IS NULL
              OR LocationId = '-1';


        RAISERROR('Invalid location codes', 18, 1);
        RETURN;
    END;

    IF @debug = 1
    BEGIN
        SELECT 'the following records are missing a location id in the warehouse table';
        SELECT DISTINCT
               PayPlan,
               WageArea,
               ScheduleArea,
               LocationId
        FROM #CostsWage
        WHERE LocationId IS NULL;
    END;

    DECLARE @FICA NUMERIC(20, 6) = crunch.GetSingleValue('AAw', 'FICA', @AmcosVersionId);
    DECLARE @Max_Wage_SSW NUMERIC(20, 6) = crunch.GetSingleValue('AA', 'Max_Wage_SSW', @AmcosVersionId);
    DECLARE @PostRetHealthIns NUMERIC(20, 6) = crunch.GetSingleValue('AA', 'PostRetHealthIns', @AmcosVersionId);
    DECLARE @PostRetLifeIns NUMERIC(20, 6) = crunch.GetSingleValue('AA', 'PostRetLifeIns', @AmcosVersionId);
    DECLARE @Training NUMERIC(20, 6) = crunch.GetSingleValue('AA', 'Training', @AmcosVersionId);
    DECLARE @ArmyRet NUMERIC(20, 6) = crunch.GetSingleValue('AAw', 'ArmyRet', @AmcosVersionId);
    DECLARE @CashAwards NUMERIC(20, 6) = crunch.GetSingleValue('AAw', 'CashAwards', @AmcosVersionId);
    DECLARE @FEGLI NUMERIC(20, 6) = crunch.GetSingleValue('AAw', 'FEGLI', @AmcosVersionId);
    DECLARE @FormerEmp NUMERIC(20, 6) = crunch.GetSingleValue('AAw', 'FormerEmp', @AmcosVersionId);
    DECLARE @Misc NUMERIC(20, 6) = crunch.GetSingleValue('AAw', 'Misc', @AmcosVersionId);
    DECLARE @Prem NUMERIC(20, 6) = crunch.GetSingleValue('AAw', 'Prem', @AmcosVersionId);
    DECLARE @OT NUMERIC(20, 6) = crunch.GetSingleValue('AAw', 'Ovrt', @AmcosVersionId);
    DECLARE @FEGHI NUMERIC(20, 6) = crunch.GetSingleValue('AAw', 'FEGHI', @AmcosVersionId);
    DECLARE @Groceries NUMERIC(20, 6) = crunch.GetSingleValue('AA', 'DiscountGroceries', @AmcosVersionId);

    -- Base pay, taxable
    UPDATE #CostsWage
    SET CostAmount = BasePay,
        Taxable = 1
    WHERE CostElementId IN ( 4226, 4238, 4250, 628, 4262, 4274, 635, 4286, 4298, 4310, 4322, 642, 4334, 4346, 4358,
                             4370, 4382, 4394, 4406, 4418, 4430, 4463, 4476, 4489
                           );

    --LQA Costs
    --According to the DTMO site https://www.defensetravel.dod.mil/site/faqlqa.cfm

    /* Group 4
       WG 1-13; WL 1-11; WS 1-10 */
    UPDATE #CostsWage
    SET CostAmount = b.Amt
    FROM #CostsWage AS a
        INNER JOIN dataload.DoSLivingAllowance AS b
            ON a.LocationCode = b.LocationCode
    WHERE (
              (
                  a.GradeLevel
          BETWEEN 1 AND 13
                  AND a.PayPlan = 'WG'
              )
              OR
              (
                  a.GradeLevel
          BETWEEN 1 AND 11
                  AND a.PayPlan = 'WL'
              )
              OR
              (
                  a.GradeLevel
          BETWEEN 1 AND 10
                  AND a.PayPlan = 'WS'
              )
          )
          AND b.[Group] = 4
          AND b.AmcosVersionId = @AmcosVersionId
          AND b.Family = 0
          AND a.NumberOfDependents = 0
          AND a.CostElementId IN ( 4884, 4874, 4879 )
          AND a.LocationType = 'Civilian Overseas';

    UPDATE #CostsWage
    SET CostAmount = b.Amt
    FROM #CostsWage AS a
        INNER JOIN dataload.DoSLivingAllowance AS b
            ON a.LocationCode = b.LocationCode
    WHERE (
              (
                  a.GradeLevel
          BETWEEN 1 AND 13
                  AND a.PayPlan = 'WG'
              )
              OR
              (
                  a.GradeLevel
          BETWEEN 1 AND 11
                  AND a.PayPlan = 'WL'
              )
              OR
              (
                  a.GradeLevel
          BETWEEN 1 AND 10
                  AND a.PayPlan = 'WS'
              )
          )
          AND b.[Group] = 4
          AND b.AmcosVersionId = @AmcosVersionId
          AND b.Family = 1
          AND a.NumberOfDependents >= 1
          AND a.CostElementId IN ( 4884, 4874, 4879 )
          AND a.LocationType = 'Civilian Overseas';

    --Group 3
    --WG 14-15; WL 12-15; WS 11-19
    UPDATE #CostsWage
    SET CostAmount = b.Amt
    FROM #CostsWage AS a
        INNER JOIN dataload.DoSLivingAllowance AS b
            ON a.LocationCode = b.LocationCode
    WHERE (
              (
                  a.GradeLevel
          BETWEEN 14 AND 15
                  AND a.PayPlan = 'WG'
              )
              OR
              (
                  a.GradeLevel
          BETWEEN 12 AND 15
                  AND a.PayPlan = 'WL'
              )
              OR
              (
                  a.GradeLevel
          BETWEEN 11 AND 19
                  AND a.PayPlan = 'WS'
              )
          )
          AND b.[Group] = 3
          AND b.AmcosVersionId = @AmcosVersionId
          AND b.Family = 0
          AND a.NumberOfDependents = 0
          AND a.CostElementId IN ( 4884, 4874, 4879 )
          AND a.LocationType = 'Civilian Overseas';

    UPDATE #CostsWage
    SET CostAmount = b.Amt
    FROM #CostsWage AS a
        INNER JOIN dataload.DoSLivingAllowance AS b
            ON a.LocationCode = b.LocationCode
    WHERE (
              (
                  a.GradeLevel
          BETWEEN 14 AND 15
                  AND a.PayPlan = 'WG'
              )
              OR
              (
                  a.GradeLevel
          BETWEEN 12 AND 15
                  AND a.PayPlan = 'WL'
              )
              OR
              (
                  a.GradeLevel
          BETWEEN 11 AND 19
                  AND a.PayPlan = 'WS'
              )
          )
          AND b.[Group] = 3
          AND b.AmcosVersionId = @AmcosVersionId
          AND b.Family = 1
          AND a.NumberOfDependents >= 1
          AND a.CostElementId IN ( 4884, 4874, 4879 )
          AND a.LocationType = 'Civilian Overseas';

    /* Post Allowance costs
    --percentage based on spendable income
    --per DSSR 054.1 the post allowance is NOT taxable */
    UPDATE #CostsWage
    SET CostAmount = b.SpendableIncome * c.PostAllowance
    FROM #CostsWage AS a
        INNER JOIN dataload.MilitarySpendableIncome AS b
            ON a.BasePay
               BETWEEN b.LowerLimit AND b.UpperLimit
               AND b.NumberOfDependents = a.NumberOfDependents
        INNER JOIN dataload.DoSPostAllowance AS c
            ON a.LocationCode = c.LocationCode
    WHERE b.AmcosVersionId = @AmcosVersionId
          AND c.AmcosVersionId = @AmcosVersionId
          AND a.CostElementId IN ( 4885, 4875, 4880 )
          AND a.LocationType = 'Civilian Overseas';

    /* Post Hardship Differential
    --percentage based on basic compensation
    --per DSSR 045.2 this IS INCLUDED for federal tax purposes */
    UPDATE #CostsWage
    SET CostAmount = a.BasePay * b.Hardship,
        Taxable = 1
    FROM #CostsWage AS a
        INNER JOIN dataload.DoSPostAllowance AS b
            ON a.LocationCode = b.LocationCode
    WHERE b.AmcosVersionId = @AmcosVersionId
          AND a.CostElementId IN ( 4886, 4876, 4881 )
          AND a.LocationType = 'Civilian Overseas';

    --Danger Pay Allowance
    --percentage based on basic compensation
    --per DSSR 054.2 this IS INCLUDED for federal tax purposes
    UPDATE #CostsWage
    SET CostAmount = a.BasePay * b.DangerPay,
        Taxable = 1
    FROM #CostsWage AS a
        INNER JOIN dataload.DoSPostAllowance AS b
            ON a.LocationCode = b.LocationCode
    WHERE b.AmcosVersionId = @AmcosVersionId
          AND a.CostElementId IN ( 4887, 4877, 4882 )
          AND a.LocationType = 'Civilian Overseas';

    -- Discount Groceries 
    UPDATE #CostsWage
    SET CostAmount = @Groceries
    WHERE CostElementId IN ( 4888, 4878, 4883 )
          AND LocationType = 'Civilian Overseas';

    -- Avg Cost of Premium Pay, taxable
    UPDATE #CostsWage
    SET CostAmount = BasePay * @Prem,
        Taxable = 1
    WHERE CostElementId IN ( 4227, 4239, 4251, 629, 4263, 4275, 636, 4287, 4299, 4311, 4323, 643, 4335, 4347, 4359,
                             4371, 4383, 4395, 4407, 4419, 4431, 4465, 4478, 4491
                           );

    -- Avg Cost of Overtime Pay, taxable
    UPDATE #CostsWage
    SET CostAmount = BasePay * @OT,
        Taxable = 1
    WHERE CostElementId IN ( 4436, 4437, 4438, 4439, 4440, 4441, 4442, 4443, 4444, 4445, 4446, 4447, 4448, 4449, 4450,
                             4451, 4452, 4453, 4454, 4455, 4456, 4464, 4477, 4490
                           );

    -- Average Cost of Federal Employees Gov't Life Insurance 
    UPDATE #CostsWage
    SET CostAmount = BasePay * @FEGLI
    WHERE CostElementId IN ( 4223, 4235, 4247, 631, 4259, 4271, 638, 4283, 4295, 4307, 4319, 645, 4331, 4343, 4355,
                             4367, 4379, 4391, 4403, 4415, 4427, 4460, 4473, 4486
                           );

    -- Average Cost of Federal Employees Gov't Health Insurance 
    UPDATE #CostsWage
    SET CostAmount = @FEGHI
    WHERE CostElementId IN ( 4222, 4234, 4246, 630, 4258, 4270, 637, 4282, 4294, 4306, 4318, 644, 4330, 4342, 4354,
                             4366, 4378, 4390, 4402, 4414, 4426, 4459, 4472, 4485
                           );

    -- Average Cost of Miscellaneous Pay 
    UPDATE #CostsWage
    SET CostAmount = BasePay * @Misc
    WHERE CostElementId IN ( 4224, 4236, 4248, 632, 4260, 4272, 639, 4284, 4296, 4308, 4320, 646, 4332, 4344, 4356,
                             4368, 4380, 4392, 4404, 4416, 4428, 4461, 4474, 4487
                           );

    --Post retiremeent life 
    UPDATE #CostsWage
    SET CostAmount = @PostRetLifeIns
    WHERE CostElementId IN ( 4230, 4242, 4254, 976, 4266, 4278, 986, 4290, 4302, 4314, 4326, 996, 4338, 4350, 4362,
                             4374, 4386, 4398, 4410, 4422, 4434, 4468, 4481, 4494
                           );

    --Post retirement health
    UPDATE #CostsWage
    SET CostAmount = @PostRetHealthIns
    WHERE CostElementId IN ( 4229, 4241, 4253, 977, 4265, 4277, 987, 4289, 4301, 4313, 4325, 997, 4337, 4349, 4361,
                             4373, 4385, 4397, 4409, 4421, 4433, 4467, 4480, 4493
                           );

    --Cash awards, taxable
    UPDATE #CostsWage
    SET CostAmount = BasePay * @CashAwards,
        Taxable = 1
    WHERE CostElementId IN ( 4225, 4237, 4249, 971, 4261, 4273, 981, 4285, 4297, 4309, 4321, 991, 4333, 4345, 4357,
                             4369, 4381, 4393, 4405, 4417, 4429, 4462, 4475, 4488
                           );

    --FICA
    UPDATE #CostsWage
    SET CostAmount = @FICA * b.taxablecosts
    FROM #CostsWage AS a
        INNER JOIN
        (
            SELECT SUM(CostAmount) AS taxablecosts,
                   PayPlan,
                   OccupationalGroupNumber,
                   OccupationalSeriesNumber,
                   GradeLevel,
                   LocationId,
                   DataSource,
                   NumberOfDependents
            FROM #CostsWage
            WHERE Taxable = 1
            GROUP BY PayPlan,
                     OccupationalGroupNumber,
                     OccupationalSeriesNumber,
                     GradeLevel,
                     LocationId,
                     DataSource,
                     NumberOfDependents
        ) AS b
            ON b.GradeLevel = a.GradeLevel
               AND b.LocationId = a.LocationId
               AND b.OccupationalGroupNumber = a.OccupationalGroupNumber
               AND b.NumberOfDependents = a.NumberOfDependents
               AND b.PayPlan = a.PayPlan
               AND b.OccupationalSeriesNumber = a.OccupationalSeriesNumber
               AND b.DataSource = a.DataSource
    WHERE a.CostElementId IN (
                                 --only FICA CEs
                                 972, 982, 992, 4220, 4232, 4244, 4256, 4268, 4280, 4292, 4304, 4316, 4328, 4340, 4352,
                                 4364, 4376, 4388, 4400, 4412, 4424, 4457, 4470, 4483
                             );
    --set cap on FICA
    UPDATE #CostsWage
    SET CostAmount = @Max_Wage_SSW * @FICA
    WHERE CostAmount > (@Max_Wage_SSW * @FICA)
          AND CostElementId IN (
                                   --only FICA CEs
                                   972, 982, 992, 4220, 4232, 4244, 4256, 4268, 4280, 4292, 4304, 4316, 4328, 4340,
                                   4352, 4364, 4376, 4388, 4400, 4412, 4424, 4457, 4470, 4483
                               );

    --Former Employee Compensation
    UPDATE #CostsWage
    SET CostAmount = BasePay * @FormerEmp
    WHERE CostElementId IN ( 4228, 4240, 4252, 973, 4264, 4276, 983, 4288, 4300, 4312, 4324, 993, 4336, 4348, 4360,
                             4372, 4384, 4396, 4408, 4420, 4432, 4466, 4479, 4492
                           );

    -- Average Cost of Army-Funded Retirement
    UPDATE #CostsWage
    SET CostAmount = BasePay * @ArmyRet
    WHERE CostElementId IN ( 4221, 4233, 4245, 633, 4257, 4269, 640, 4281, 4293, 4305, 4317, 647, 4329, 4341, 4353,
                             4365, 4377, 4389, 4401, 4413, 4425, 4458, 4471, 4484
                           );

    -- OSD CAPE DODI: Training 
    UPDATE #CostsWage
    SET CostAmount = @Training
    WHERE CostElementId IN ( 4231, 4243, 4255, 756, 4267, 4279, 763, 4291, 4303, 4315, 4327, 749, 4339, 4351, 4363,
                             4375, 4387, 4399, 4411, 4423, 4435, 4469, 4482, 4495
                           );

    /* Bring in description to make the final table easier to read */
    UPDATE #CostsWage
    SET PayPlanTitle = b.DisplayTitle
    FROM #CostsWage AS a
        INNER JOIN lookup.PayPlan AS b
            ON a.PayPlan = b.PayPlan
    WHERE @AmcosVersionId
    BETWEEN b.AmcosVersionIdStart AND b.AmcosVersionIdEnd;

    /* Set group number */
    UPDATE #CostsWage
    SET OccupationalGroupNumber = LEFT(OccupationalSeriesNumber, 2) + '00'
    WHERE OccupationalSeriesNumber <> '-1';

    UPDATE #CostsWage
    SET OccupationalGroupNumber = '-1'
    WHERE OccupationalSeriesNumber = '-1';

    --bring in location info
    UPDATE #CostsWage
    SET WageArea = b.WageArea
    FROM #CostsWage AS a
        INNER JOIN lookup.WageArea AS b
            ON a.ScheduleArea = b.ScheduleArea
               AND a.FundType = b.FundType;

    IF @debug = 1
    BEGIN
        SELECT 'pay table';
        SELECT *
        FROM #CostsWage
        WHERE DataSource = 'Fill-in'
        ORDER BY PayPlan,
                 OccupationalSeriesNumber,
                 WageArea,
                 ScheduleArea,
                 GradeLevel,
                 Inventory;
    END;

    IF @debug = 0
    BEGIN
        /* Delete existing values including averages since we'll also insert those as part of this crunch */
        DELETE FROM crunch.Costs_Wage
        WHERE AmcosVersionId = @AmcosVersionId;

        /* According to a discussion with the COR (Marsha Popp) on 8/24/2020 there were two main options on how
        to handle overseas and CONUS costs in terms of averaging:
        1) Assume a typical # of overseas dependants and average that with CONUS (# of dep=-1)
        2) Keep CONUS and OCONUS seperate and force the user to pick # of dep with -1 being called Not Applicable
        Because #1 is a truer average that was chosen 
        For OCONUS locations we assumed civilian and spouse was typical so NumberOfDependents = 1 */
        DECLARE @NumberOfDependentsCONUS INT = -1;
        DECLARE @NumberOfDependentsOCONUS INT = 1;
        DECLARE @NumberOfDependentsAverage INT = -1;


        /* Insert costs
		Do not include fill-in rows */
        INSERT INTO crunch.Costs_Wage
        (
            PayPlan,
            OccupationalGroupNumber,
            OccupationalSeriesNumber,
            WageArea,
            WageSchedule,
            CostElementId,
            GradeType,
            GradeLevel,
            Amount,
            CrunchTime,
            AmcosVersionId,
            LocationId,
            NumberOfDependents
        )
        SELECT PayPlan,
               OccupationalGroupNumber,
               OccupationalSeriesNumber,
               WageArea,
               ScheduleArea,
               CostElementId,
               PayPlan,
               GradeLevel,
               CostAmount,
               CONVERT(SMALLDATETIME, GETDATE()) AS CrunchTime,
               AmcosVersionId,
               LocationId,
               NumberOfDependents
        FROM #CostsWage
        WHERE DataSource = 'Inventory';

        /* Average costs by PayPlan, OccupationalGroupNumber, and OccupationalSeriesNumber
		Location non-specific
		Do not include fill-in rows */
        INSERT INTO crunch.Costs_Wage
        (
            PayPlan,
            OccupationalGroupNumber,
            OccupationalSeriesNumber,
            WageArea,
            WageSchedule,
            CostElementId,
            GradeType,
            GradeLevel,
            Amount,
            CrunchTime,
            AmcosVersionId,
            LocationId,
            NumberOfDependents
        )
        SELECT PayPlan,
               OccupationalGroupNumber,
               OccupationalSeriesNumber,
               -1 AS WageArea,
               -1 AS WageSchedule,
               CostElementId,
               PayPlan,
               GradeLevel,
               SUM(CostAmount * Inventory) / SUM(Inventory) AS Amount,
               CONVERT(SMALLDATETIME, GETDATE()) AS CrunchTime,
               AmcosVersionId,
               -1 AS LocationId,
               @NumberOfDependentsAverage
        FROM #CostsWage
        WHERE DataSource = 'Inventory'
              AND NumberOfDependents IN ( @NumberOfDependentsCONUS, @NumberOfDependentsOCONUS )
        GROUP BY PayPlan,
                 OccupationalGroupNumber,
                 OccupationalSeriesNumber,
                 CostElementId,
                 GradeLevel,
                 AmcosVersionId;

        /* Average costs by PayPlan, OccupationalGroupNumber
                Location non-specific
                Do not include fill-in rows */
        INSERT INTO crunch.Costs_Wage
        (
            PayPlan,
            OccupationalGroupNumber,
            OccupationalSeriesNumber,
            WageArea,
            WageSchedule,
            CostElementId,
            GradeType,
            GradeLevel,
            Amount,
            CrunchTime,
            AmcosVersionId,
            LocationId,
            NumberOfDependents
        )
        SELECT PayPlan,
               OccupationalGroupNumber,
               -1 AS OccupationalSeriesNumber,
               -1 AS WageArea,
               -1 AS WageSchedule,
               CostElementId,
               PayPlan,
               GradeLevel,
               SUM(CostAmount * Inventory) / SUM(Inventory) AS Amount,
               CONVERT(SMALLDATETIME, GETDATE()) AS CrunchTime,
               AmcosVersionId,
               -1 AS LocationId,
               @NumberOfDependentsAverage
        FROM #CostsWage
        WHERE DataSource = 'Inventory'
              AND NumberOfDependents IN ( @NumberOfDependentsCONUS, @NumberOfDependentsOCONUS )
        GROUP BY PayPlan,
                 OccupationalGroupNumber,
                 CostElementId,
                 GradeLevel,
                 AmcosVersionId;


        /* Average costs by PayPlan, OccupationalGroupNumber
                Location-specific
                Do not include fill-in rows */
        INSERT INTO crunch.Costs_Wage
        (
            PayPlan,
            OccupationalGroupNumber,
            OccupationalSeriesNumber,
            WageArea,
            WageSchedule,
            CostElementId,
            GradeType,
            GradeLevel,
            Amount,
            CrunchTime,
            AmcosVersionId,
            LocationId,
            NumberOfDependents
        )
        SELECT PayPlan,
               OccupationalGroupNumber,
               -1 AS OccupationalSeriesNumber,
               -1 AS WageArea,
               -1 AS WageSchedule,
               CostElementId,
               PayPlan,
               GradeLevel,
               SUM(CostAmount * Inventory) / SUM(Inventory) AS Amount,
               CONVERT(SMALLDATETIME, GETDATE()) AS CrunchTime,
               AmcosVersionId,
               LocationId,
               NumberOfDependents
        FROM #CostsWage
        WHERE DataSource = 'Inventory'
        GROUP BY PayPlan,
                 OccupationalGroupNumber,
                 CostElementId,
                 GradeLevel,
                 AmcosVersionId,
                 LocationId,
                 NumberOfDependents;

        /* Average costs by PayPlan
		Location non-specific
		Do not include fill-in rows */
        INSERT INTO crunch.Costs_Wage
        (
            PayPlan,
            OccupationalGroupNumber,
            OccupationalSeriesNumber,
            WageArea,
            WageSchedule,
            CostElementId,
            GradeType,
            GradeLevel,
            Amount,
            CrunchTime,
            AmcosVersionId,
            LocationId,
            NumberOfDependents
        )
        SELECT PayPlan,
               -1 AS OccupationalGroupNumber,
               -1 AS OccupationalSeriesNumber,
               -1 AS WageArea,
               -1 AS WageSchedule,
               CostElementId,
               PayPlan,
               GradeLevel,
               SUM(CostAmount * Inventory) / SUM(Inventory) AS Amount,
               CONVERT(SMALLDATETIME, GETDATE()) AS CrunchTime,
               AmcosVersionId,
               -1 AS LocationId,
               @NumberOfDependentsAverage
        FROM #CostsWage
        WHERE DataSource = 'Inventory'
              AND NumberOfDependents IN ( @NumberOfDependentsCONUS, @NumberOfDependentsOCONUS )
        GROUP BY PayPlan,
                 CostElementId,
                 GradeLevel,
                 AmcosVersionId;

        /* Average costs by PayPlan
		Location-specific
		Do not include fill-in rows */
        INSERT INTO crunch.Costs_Wage
        (
            PayPlan,
            OccupationalGroupNumber,
            OccupationalSeriesNumber,
            WageArea,
            WageSchedule,
            CostElementId,
            GradeType,
            GradeLevel,
            Amount,
            CrunchTime,
            AmcosVersionId,
            LocationId,
            NumberOfDependents
        )
        SELECT PayPlan,
               -1 AS OccupationalGroupNumber,
               -1 AS OccupationalSeriesNumber,
               -1 AS WageArea,
               -1 AS WageSchedule,
               CostElementId,
               PayPlan,
               GradeLevel,
               SUM(CostAmount * Inventory) / SUM(Inventory) AS Amount,
               CONVERT(SMALLDATETIME, GETDATE()) AS CrunchTime,
               AmcosVersionId,
               LocationId,
               NumberOfDependents
        FROM #CostsWage
        WHERE DataSource = 'Inventory'
        GROUP BY PayPlan,
                 CostElementId,
                 GradeLevel,
                 AmcosVersionId,
                 LocationId,
                 NumberOfDependents;

        --since we left zeros in to properly compute weighted average we now delete them
        DELETE FROM crunch.Costs_Wage
        WHERE Amount = 0
              AND @AmcosVersionId = AmcosVersionId;
    END;

END;