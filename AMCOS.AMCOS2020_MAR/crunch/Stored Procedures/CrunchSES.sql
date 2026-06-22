CREATE PROCEDURE [crunch].[CrunchSES]
    @debug BIT = 0,
    @AmcosVersionId INT = -1

/*
Description: Calculate Average Cost factors for the Civilian Senior Executive Schedule (SES)
    Created: 11/8/2019
 
*/
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @IsValidAmcosVersion BIT = crunch.ValidateAmcosVersion(@AmcosVersionId);

    IF (@IsValidAmcosVersion = 0)
        RETURN 0;


    DECLARE @minGL INT = 1;
    DECLARE @avgGL INT = 2;
    DECLARE @maxGL INT = 3;
    DECLARE @SES_Min INT =
            (
                SELECT MinPay
                FROM PaySchedule.OpmSesRaw
                WHERE RateType = 'Annual'
                      AND AmcosVersionId = @AmcosVersionId
            );
    DECLARE @SES_Max INT =
            (
                SELECT MaxPay
                FROM PaySchedule.OpmSesRaw
                WHERE RateType = 'Annual'
                      AND AmcosVersionId = @AmcosVersionId
            );

    CREATE TABLE #Costs_SES
    (
        PayPlan NVARCHAR(3) NOT NULL,
        OccupationalGroupNumber NVARCHAR(4) NOT NULL,
        OccupationalSeriesNumber NVARCHAR(4) NOT NULL,
        CostElementId INT NOT NULL,
        CostElementName NVARCHAR(150) NOT NULL,
        CostElementCategory NVARCHAR(150) NOT NULL,
        GradeType NVARCHAR(3) NOT NULL,
        GradeLevel TINYINT NOT NULL,
        BasePay NUMERIC(18, 2) NOT NULL,
        CostAmount NUMERIC(18, 2) NOT NULL
            DEFAULT (-1000000),
        Inventory INT NOT NULL,
        LocationId INT NOT NULL,
        LocationName NVARCHAR(500) NOT NULL,
        LocationType NVARCHAR(500) NOT NULL,
        LocationCode NVARCHAR(500) NOT NULL,
        NumberOfDependents INT NOT NULL
            DEFAULT-1,
        AmcosVersionId INT NOT NULL,
        [Source] NVARCHAR(50) NOT NULL
    );
    INSERT INTO #Costs_SES
    (
        PayPlan,
        OccupationalGroupNumber,
        OccupationalSeriesNumber,
        CostElementId,
        CostElementName,
        CostElementCategory,
        GradeType,
        GradeLevel,
        BasePay,
        Inventory,
        LocationId,
        LocationName,
        LocationType,
        LocationCode,
        AmcosVersionId,
        Source
    )


    --############################### Because we need the raw values to compute min and max we need to use the raw inventory file, not the processed
    --## Series Level Values
    --minimum SES values
    SELECT 'SES',
           LEFT(RIGHT('00' + CAST(a.OccupationalSeriesNumber AS NVARCHAR(4)), 4), 2) + '00',
           RIGHT('00' + CAST(a.OccupationalSeriesNumber AS NVARCHAR(4)), 4),
           b.CostElementId,
           b.CostElementName,
           b.CostElementCategory,
           'SES',
           @minGL,
           CASE
               WHEN MIN(a.SAL_WAG) < @SES_Min THEN
                   @SES_Min
               ELSE
                   MIN(a.SAL_WAG)
           END,
           SUM(a.Count),
           -1,
           'na',
           'na',
           'na',
           a.AmcosVersionId,
           'inventory'
    FROM load_inventory.WASS_Raw AS a
        CROSS JOIN
        (
            SELECT CostElementId,
                   CostElementName,
                   CostElementCategory
            FROM lookup.CostElement
            WHERE PayPlan = 'SES'
                  AND @AmcosVersionId
                  BETWEEN AmcosVersionIdStart AND AmcosVersionIdEnd
        ) AS b
    WHERE a.PayPlan = 'ES'
          AND a.AmcosVersionId = @AmcosVersionId
    GROUP BY a.OccupationalSeriesNumber,
             b.CostElementId,
             b.CostElementName,
             b.CostElementCategory,
             a.AmcosVersionId
    UNION
    --average SES values
    SELECT 'SES',
           LEFT(RIGHT('00' + CAST(a.OccupationalSeriesNumber AS NVARCHAR(4)), 4), 2) + '00',
           RIGHT('00' + CAST(a.OccupationalSeriesNumber AS NVARCHAR(4)), 4),
           b.CostElementId,
           b.CostElementName,
           b.CostElementCategory,
           'SES',
           @avgGL,
           AVG(   CASE
                      WHEN a.SAL_WAG < @SES_Min THEN
                          @SES_Min
                      WHEN a.SAL_WAG > @SES_Max THEN
                          @SES_Max
                      ELSE
                          a.SAL_WAG
                  END
              ),
           SUM(a.Count),
           -1,
           'na',
           'na',
           'na',
           a.AmcosVersionId,
           'inventory'
    FROM load_inventory.WASS_Raw AS a
        CROSS JOIN
        (
            SELECT CostElementId,
                   CostElementName,
                   CostElementCategory
            FROM lookup.CostElement
            WHERE PayPlan = 'SES'
                  AND @AmcosVersionId
                  BETWEEN AmcosVersionIdStart AND AmcosVersionIdEnd
        ) AS b
    WHERE a.PayPlan = 'ES'
          AND a.AmcosVersionId = @AmcosVersionId
    GROUP BY a.OccupationalSeriesNumber,
             b.CostElementId,
             b.CostElementName,
             b.CostElementCategory,
             a.AmcosVersionId
    UNION
    --max SES values
    SELECT 'SES',
           LEFT(RIGHT('00' + CAST(a.OccupationalSeriesNumber AS NVARCHAR(4)), 4), 2) + '00',
           RIGHT('00' + CAST(a.OccupationalSeriesNumber AS NVARCHAR(4)), 4),
           b.CostElementId,
           b.CostElementName,
           b.CostElementCategory,
           'SES',
           @maxGL,
           CASE
               WHEN MAX(a.SAL_WAG) > @SES_Max THEN
                   @SES_Max
               ELSE
                   MAX(a.SAL_WAG)
           END,
           SUM(a.Count),
           -1,
           'na',
           'na',
           'na',
           a.AmcosVersionId,
           'inventory'
    FROM load_inventory.WASS_Raw AS a
        CROSS JOIN
        (
            SELECT CostElementId,
                   CostElementName,
                   CostElementCategory
            FROM lookup.CostElement
            WHERE PayPlan = 'SES'
                  AND @AmcosVersionId
                  BETWEEN AmcosVersionIdStart AND AmcosVersionIdEnd
        ) AS b
    WHERE a.PayPlan = 'ES'
          AND a.AmcosVersionId = @AmcosVersionId
    GROUP BY a.OccupationalSeriesNumber,
             b.CostElementId,
             b.CostElementName,
             b.CostElementCategory,
             a.AmcosVersionId
    UNION
    --## Group Level Values
    --minimum SES values
    SELECT 'SES',
           LEFT(RIGHT('00' + CAST(a.OccupationalSeriesNumber AS NVARCHAR(4)), 4), 2) + '00',
           CAST(-1 AS NVARCHAR(4)),
           b.CostElementId,
           b.CostElementName,
           b.CostElementCategory,
           'SES',
           @minGL,
           CASE
               WHEN MIN(a.SAL_WAG) < @SES_Min THEN
                   @SES_Min
               ELSE
                   MIN(a.SAL_WAG)
           END,
           SUM(a.Count),
           -1,
           'na',
           'na',
           'na',
           a.AmcosVersionId,
           'inventory'
    FROM load_inventory.WASS_Raw AS a
        CROSS JOIN
        (
            SELECT CostElementId,
                   CostElementName,
                   CostElementCategory
            FROM lookup.CostElement
            WHERE PayPlan = 'SES'
                  AND @AmcosVersionId
                  BETWEEN AmcosVersionIdStart AND AmcosVersionIdEnd
        ) AS b
    WHERE a.PayPlan = 'ES'
          AND a.AmcosVersionId = @AmcosVersionId
    GROUP BY LEFT(RIGHT('00' + CAST(a.OccupationalSeriesNumber AS NVARCHAR(4)), 4), 2) + '00',
             b.CostElementId,
             b.CostElementName,
             b.CostElementCategory,
             a.AmcosVersionId
    UNION
    --average SES values
    SELECT 'SES',
           LEFT(RIGHT('00' + CAST(a.OccupationalSeriesNumber AS NVARCHAR(4)), 4), 2) + '00',
           CAST(-1 AS NVARCHAR(4)),
           b.CostElementId,
           b.CostElementName,
           b.CostElementCategory,
           'SES',
           @avgGL,
           AVG(   CASE
                      WHEN a.SAL_WAG < @SES_Min THEN
                          @SES_Min
                      WHEN a.SAL_WAG > @SES_Max THEN
                          @SES_Max
                      ELSE
                          a.SAL_WAG
                  END
              ),
           SUM(a.Count),
           -1,
           'na',
           'na',
           'na',
           a.AmcosVersionId,
           'inventory'
    FROM load_inventory.WASS_Raw AS a
        CROSS JOIN
        (
            SELECT CostElementId,
                   CostElementName,
                   CostElementCategory
            FROM lookup.CostElement
            WHERE PayPlan = 'SES'
                  AND @AmcosVersionId
                  BETWEEN AmcosVersionIdStart AND AmcosVersionIdEnd
        ) AS b
    WHERE a.PayPlan = 'ES'
          AND a.AmcosVersionId = @AmcosVersionId
    GROUP BY LEFT(RIGHT('00' + CAST(a.OccupationalSeriesNumber AS NVARCHAR(4)), 4), 2) + '00',
             b.CostElementId,
             b.CostElementName,
             b.CostElementCategory,
             a.AmcosVersionId
    UNION
    --max SES values
    SELECT 'SES',
           LEFT(RIGHT('00' + CAST(a.OccupationalSeriesNumber AS NVARCHAR(4)), 4), 2) + '00',
           CAST(-1 AS NVARCHAR(4)),
           b.CostElementId,
           b.CostElementName,
           b.CostElementCategory,
           'SES',
           @maxGL,
           CASE
               WHEN MAX(a.SAL_WAG) > @SES_Max THEN
                   @SES_Max
               ELSE
                   MAX(a.SAL_WAG)
           END,
           SUM(a.Count),
           -1,
           'na',
           'na',
           'na',
           a.AmcosVersionId,
           'inventory'
    FROM load_inventory.WASS_Raw AS a
        CROSS JOIN
        (
            SELECT CostElementId,
                   CostElementName,
                   CostElementCategory
            FROM lookup.CostElement
            WHERE PayPlan = 'SES'
                  AND @AmcosVersionId
                  BETWEEN AmcosVersionIdStart AND AmcosVersionIdEnd
        ) AS b
    WHERE a.PayPlan = 'ES'
          AND a.AmcosVersionId = @AmcosVersionId
    GROUP BY LEFT(RIGHT('00' + CAST(a.OccupationalSeriesNumber AS NVARCHAR(4)), 4), 2) + '00',
             b.CostElementId,
             b.CostElementName,
             b.CostElementCategory,
             a.AmcosVersionId
    UNION
    --## PayPlan Level Values
    --minimum SES values
    SELECT 'SES',
           CAST(-1 AS NVARCHAR(4)),
           CAST(-1 AS NVARCHAR(4)),
           b.CostElementId,
           b.CostElementName,
           b.CostElementCategory,
           'SES',
           @minGL,
           CASE
               WHEN MIN(a.SAL_WAG) < @SES_Min THEN
                   @SES_Min
               ELSE
                   MIN(a.SAL_WAG)
           END,
           SUM(a.Count),
           -1,
           'na',
           'na',
           'na',
           a.AmcosVersionId,
           'inventory'
    FROM load_inventory.WASS_Raw AS a
        CROSS JOIN
        (
            SELECT CostElementId,
                   CostElementName,
                   CostElementCategory
            FROM lookup.CostElement
            WHERE PayPlan = 'SES'
                  AND @AmcosVersionId
                  BETWEEN AmcosVersionIdStart AND AmcosVersionIdEnd
        ) AS b
    WHERE a.PayPlan = 'ES'
          AND a.AmcosVersionId = @AmcosVersionId
    GROUP BY b.CostElementId,
             b.CostElementName,
             b.CostElementCategory,
             a.AmcosVersionId
    UNION
    --average SES values
    SELECT 'SES',
           CAST(-1 AS NVARCHAR(4)),
           CAST(-1 AS NVARCHAR(4)),
           b.CostElementId,
           b.CostElementName,
           b.CostElementCategory,
           'SES',
           @avgGL,
           AVG(   CASE
                      WHEN a.SAL_WAG < @SES_Min THEN
                          @SES_Min
                      WHEN a.SAL_WAG > @SES_Max THEN
                          @SES_Max
                      ELSE
                          a.SAL_WAG
                  END
              ),
           SUM(a.Count),
           -1,
           'na',
           'na',
           'na',
           a.AmcosVersionId,
           'inventory'
    FROM load_inventory.WASS_Raw AS a
        CROSS JOIN
        (
            SELECT CostElementId,
                   CostElementName,
                   CostElementCategory
            FROM lookup.CostElement
            WHERE PayPlan = 'SES'
                  AND @AmcosVersionId
                  BETWEEN AmcosVersionIdStart AND AmcosVersionIdEnd
        ) AS b
    WHERE a.PayPlan = 'ES'
          AND a.AmcosVersionId = @AmcosVersionId
    GROUP BY b.CostElementId,
             b.CostElementName,
             b.CostElementCategory,
             a.AmcosVersionId
    UNION
    --max SES values
    SELECT 'SES',
           CAST(-1 AS NVARCHAR(4)),
           CAST(-1 AS NVARCHAR(4)),
           b.CostElementId,
           b.CostElementName,
           b.CostElementCategory,
           'SES',
           @maxGL,
           CASE
               WHEN MAX(a.SAL_WAG) > @SES_Max THEN
                   @SES_Max
               ELSE
                   MAX(a.SAL_WAG)
           END,
           -SUM(a.Count),
           -1,
           'na',
           'na',
           'na',
           a.AmcosVersionId,
           'inventory'
    FROM load_inventory.WASS_Raw AS a
        CROSS JOIN
        (
            SELECT CostElementId,
                   CostElementName,
                   CostElementCategory
            FROM lookup.CostElement
            WHERE PayPlan = 'SES'
                  AND @AmcosVersionId
                  BETWEEN AmcosVersionIdStart AND AmcosVersionIdEnd
        ) AS b
    WHERE a.PayPlan = 'ES'
          AND a.AmcosVersionId = @AmcosVersionId
    GROUP BY b.CostElementId,
             b.CostElementName,
             b.CostElementCategory,
             a.AmcosVersionId;

    -- now we insert foreign locations from the dep of state
    INSERT INTO #Costs_SES
    (
        PayPlan,
        OccupationalGroupNumber,
        OccupationalSeriesNumber,
        CostElementId,
        CostElementName,
        CostElementCategory,
        GradeType,
        GradeLevel,
        BasePay,
        Inventory,
        LocationId,
        LocationName,
        LocationType,
        LocationCode,
        NumberOfDependents,
        AmcosVersionId,
        Source
    )
    SELECT a.PayPlan,
           a.OccupationalGroupNumber,
           a.OccupationalSeriesNumber,
           a.CostElementId,
           a.CostElementName,
           a.CostElementCategory,
           a.GradeType,
           a.GradeLevel,
           a.BasePay,
           0 AS inventory,
           e.LocationId,
           e.DisplayName,
           e.LocationType,
           e.SourceSystemCode,
           d.NumberOfDependents,
           a.AmcosVersionId,
           'fill in'
    FROM #Costs_SES AS a
        CROSS JOIN
        (
            SELECT DISTINCT
                   a.LocationCode
            FROM lookup.DosLocations AS a
                LEFT OUTER JOIN
                (
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
                ) AS b
                    ON a.LocationCode = b.LocationCode
            WHERE b.costs = 1
        ) AS C
        CROSS JOIN
        (
            --get number of possible  dependents 
            SELECT DISTINCT
                   NumberOfDependents
            FROM dataload.MilitarySpendableIncome
            WHERE AmcosVersionId = @AmcosVersionId
        ) AS d
        LEFT OUTER JOIN warehouse.Location AS e
            ON C.LocationCode = e.SourceSystemCode
    WHERE e.LocationType = 'Civilian Overseas';

    --next we bring in foreign inventory
    UPDATE #Costs_SES
    SET Inventory = b.Inventory,
        Source = 'inventory'
    FROM #Costs_SES AS a
        INNER JOIN data.Inventory AS b
            ON a.PayPlan = b.PayPlan
               AND a.OccupationalSeriesNumber = b.CategorySubgroupCode
               AND a.LocationId = b.LocationId
    --no join on grade level because inventory for SES is GL 0 while here we are artificially creating GL 1-3 for min/avg/max
    WHERE a.NumberOfDependents <> -1; --no conus based records since we are only doing location based costs for overseas

    --now we remove all non-inventory based locations except for alls without inventory
    --this allows us to do a partial fill in the blank targeting only locations to avoid creating too many fill in the blanks at every location and group/series level
    UPDATE #Costs_SES
    SET Source = 'delete'
    WHERE Inventory <= 0
          AND Source <> 'inventory';
    --if a locationid has no inventory under it then we are going to fill in the blanks so it shows up at the all level
    UPDATE #Costs_SES
    SET Source = 'fill in'
    WHERE Source = 'delete'
          AND OccupationalGroupNumber = '-1'
          AND LocationId NOT IN
              (
                  SELECT DISTINCT LocationId FROM #Costs_SES WHERE Source = 'inventory'
              );


    DELETE FROM #Costs_SES
    WHERE Source = 'delete';

    IF @debug = 1
    BEGIN

        SELECT 'location and series table before costs';
        SELECT *
        FROM #Costs_SES
        ORDER BY Source;
    END;

    DECLARE @FEGLI FLOAT = crunch.GetSingleValue('SES', 'FEGLI', @AmcosVersionId);
    DECLARE @ArmyRet FLOAT = crunch.GetSingleValue('SES', 'ArmyRet', @AmcosVersionId);
    DECLARE @CashAwards FLOAT = crunch.GetSingleValue('SES', 'CashAwards', @AmcosVersionId);
    DECLARE @FEGHI FLOAT = crunch.GetSingleValue('SES', 'FEGHI', @AmcosVersionId);
    DECLARE @Training FLOAT = crunch.GetSingleValue('AA', 'Training', @AmcosVersionId);
    DECLARE @PostRetLifeIns FLOAT = crunch.GetSingleValue('AA', 'PostRetLifeIns', @AmcosVersionId);
    DECLARE @PostRetHealthIns FLOAT = crunch.GetSingleValue('AA', 'PostRetHealthIns', @AmcosVersionId);
    DECLARE @PercentMedicare FLOAT = crunch.GetSingleValue('AA', 'percentMedicare', @AmcosVersionId);
    DECLARE @PercentSocialSecurity FLOAT = crunch.GetSingleValue('AA', 'PercentSocialSecurity', @AmcosVersionId);
    DECLARE @Max_Wage_SSW MONEY = crunch.GetSingleValue('AA', 'Max_Wage_SSW', @AmcosVersionId);
    DECLARE @groceries FLOAT = crunch.GetSingleValue('AA', 'DiscountGroceries', @AmcosVersionId);


    -- Avg Cost of Base Pay (Civilian)
    UPDATE #Costs_SES
    SET CostAmount = BasePay
    WHERE CostElementId = 616;

    --LQA Costs
    --According to the DTMO site https://www.defensetravel.dod.mil/site/faqlqa.cfm

    --group 2 all SES
    UPDATE #Costs_SES
    SET CostAmount = b.Amt
    FROM #Costs_SES AS a
        INNER JOIN dataload.DoSLivingAllowance AS b
            ON a.LocationCode = b.LocationCode
    WHERE b.[Group] = 2
          AND b.AmcosVersionId = @AmcosVersionId
          AND b.Family = 0
          AND a.NumberOfDependents = 0
          AND a.CostElementId IN ( 4889 );

    UPDATE #Costs_SES
    SET CostAmount = b.Amt
    FROM #Costs_SES AS a
        INNER JOIN dataload.DoSLivingAllowance AS b
            ON a.LocationCode = b.LocationCode
    WHERE b.[Group] = 2
          AND b.AmcosVersionId = @AmcosVersionId
          AND b.Family = 1
          AND a.NumberOfDependents >= 1
          AND a.CostElementId IN ( 4889 );

    --Post Allowance costs
    --percentage based on spendable income
    --per DSSR 054.1 the post allowance is NOT taxable
    UPDATE #Costs_SES
    SET CostAmount = b.SpendableIncome * c.PostAllowance
    FROM #Costs_SES AS a
        INNER JOIN dataload.MilitarySpendableIncome AS b
            ON a.BasePay
               BETWEEN b.LowerLimit AND b.UpperLimit
               AND b.NumberOfDependents = a.NumberOfDependents
        INNER JOIN dataload.DoSPostAllowance AS c
            ON a.LocationCode = c.LocationCode
    WHERE b.AmcosVersionId = @AmcosVersionId
          AND c.AmcosVersionId = @AmcosVersionId
          AND a.CostElementId IN ( 4890 );

    --Post Hardship Differential
    --percentage based on basic compensation
    --per DSSR 045.2 this IS INCLUDED for federal tax purposes
    UPDATE #Costs_SES
    SET CostAmount = a.BasePay * b.Hardship
    FROM #Costs_SES AS a
        INNER JOIN dataload.DoSPostAllowance AS b
            ON a.LocationCode = b.LocationCode
    WHERE b.AmcosVersionId = @AmcosVersionId
          AND a.CostElementId IN ( 4891 );


    /* Danger Pay Allowance
       percentage based on basic compensation
       per DSSR 054.2 this IS INCLUDED for federal tax purposes */
    UPDATE #Costs_SES
    SET CostAmount = a.BasePay * b.DangerPay
    FROM #Costs_SES AS a
        INNER JOIN dataload.DoSPostAllowance AS b
            ON a.LocationCode = b.LocationCode
    WHERE b.AmcosVersionId = @AmcosVersionId
          AND a.CostElementId IN ( 4892 );

    /* Discount Groceries */
    UPDATE #Costs_SES
    SET CostAmount = @groceries
    WHERE CostElementId IN ( 4893 )
          AND LocationType = 'Civilian Overseas';

    -- Other Benefits 
    -- Average Cost of Federal Employees Gov't Life Insurance 
    UPDATE #Costs_SES
    SET CostAmount = BasePay * @FEGLI
    WHERE CostElementId = 621;

    -- Average Cost of Federal Employees Gov't Health Insurance 
    UPDATE #Costs_SES
    SET CostAmount = @FEGHI
    WHERE CostElementId = 620;

    -- Adverage Cost of Cash Awards
    UPDATE #Costs_SES
    SET CostAmount = BasePay * @CashAwards
    WHERE CostElementId = 619;

    -- Average Cost of Army-Funded Retirement 
    UPDATE #Costs_SES
    SET CostAmount = BasePay * @ArmyRet
    WHERE CostElementId = 625;

    -- Training
    UPDATE #Costs_SES
    SET CostAmount = @Training
    WHERE CostElementId = 902;

    /* FICA = Social Security + Medicare
    Social Security is capped
    Medicare tax does not have a cap
	*/
    UPDATE #Costs_SES
    SET CostAmount = CASE
                         WHEN CashCompensation.CostAmount > @Max_Wage_SSW THEN
                             ISNULL(@Max_Wage_SSW * @PercentSocialSecurity, 0)
                             + ISNULL(@Max_Wage_SSW * @PercentMedicare, 0)
                         ELSE
                             ISNULL(CashCompensation.CostAmount * @PercentSocialSecurity, 0)
                             + ISNULL(CashCompensation.CostAmount * @PercentMedicare, 0)
                     END
    FROM #Costs_SES Costs
        INNER JOIN
        (
            SELECT SUM(CostAmount) AS CostAmount,
                   OccupationalSeriesNumber,
                   GradeLevel,
                   LocationId
            FROM #Costs_SES
            WHERE CostElementId IN ( 616, 4891, 4892, 619 )
                  AND CostAmount > 0
            GROUP BY OccupationalSeriesNumber,
                     GradeLevel,
                     LocationId
        ) AS CashCompensation
            ON CashCompensation.GradeLevel = Costs.GradeLevel
               AND CashCompensation.LocationId = Costs.LocationId
               AND CashCompensation.OccupationalSeriesNumber = Costs.OccupationalSeriesNumber
    WHERE Costs.CostElementId = 961;

    /* Post retirement life */
    UPDATE #Costs_SES
    SET CostAmount = @PostRetLifeIns
    WHERE CostElementId = 962;

    /* Post retirement health */
    UPDATE #Costs_SES
    SET CostAmount = @PostRetHealthIns
    WHERE CostElementId = 963;

    /* get rid of costs which are 0 or negative */
    DELETE FROM #Costs_SES
    WHERE CostAmount <= 0;

    IF @debug = 1
    BEGIN
        SELECT 'complete cost table';
        SELECT *
        FROM #Costs_SES
        --WHERE OccupationalSeriesNumber='0131' AND costelementid=616 AND dependents=1 AND locationid=12521
        ORDER BY OccupationalGroupNumber,
                 OccupationalSeriesNumber,
                 GradeLevel;
    END;

    IF @debug = 0
    BEGIN
        --clear out existing costs
        DELETE FROM crunch.Costs_SES
        WHERE AmcosVersionId = @AmcosVersionId;


        --insert new costs
        INSERT INTO crunch.Costs_SES
        (
            PayPlan,
            OccupationalGroupNumber,
            OccupationalSeriesNumber,
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
               CostElementId,
               GradeType,
               GradeLevel,
               CostAmount,
               CONVERT(SMALLDATETIME, GETDATE()) AS CrunchTime,
               AmcosVersionId,
               LocationId,
               NumberOfDependents
        FROM #Costs_SES;

    --clear out existing payschedule
    /* with the 12/2022 release we got ride of the old SES table for payschedule so this can now be commented out
        DELETE FROM PaySchedule.PaySchedule_SES
        WHERE AmcosVersionId = @AmcosVersionId;
		
        --insert new payschedule based on base pay
        INSERT INTO PaySchedule.PaySchedule_SES
        (
            PayPlan,
            OccupationalSeriesNumber,
            GradeType,
            GradeLevel,
            Step,
            DateEffective,
            RateType,
            Rate,
            AmcosVersionId
        )
        SELECT PayPlan,
               OccupationalSeriesNumber,
               GradeType,
               GradeLevel,
               0 AS step,
               DATEFROMPARTS(LEFT(@AmcosVersionId, 4), 1, 1),
               'Annual',
               CostAmount,
               AmcosVersionId
        FROM #Costs_SES
        WHERE CostElementId = 616
              AND OccupationalSeriesNumber <> '-1'
              AND LocationId = -1; --since SES overseas base pay is the same as CONUS we only need to insert one payschedule record to rule them all regardless of location
			  */

    END;
END;
