
-- =============================================
-- Author:Dan Hogan
-- Create date: 7/17/2019
-- Description:	Cost of Clothing Calculation
-- Considerations: this script relies on a processed DMDC pay table and assumes necessary CategorySubgroupCode conversions/adjustments 
-- and a bounce against inventory is handled in that script, before the work here takes place
-- =============================================
CREATE PROCEDURE [crunch].[CostOfClothing]
    @AmcosVersionId INT = -1,
    @CrunchTime AS SMALLDATETIME = NULL,
    @Debug AS BIT = 0 --to see all of the intermediate calculations/tables set this variable to 1, otherwise set it to 0
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @IsValidAmcosVersion BIT = crunch.ValidateAmcosVersion(@AmcosVersionId);

    IF (@IsValidAmcosVersion = 0)
        RETURN 0;

    IF (@CrunchTime IS NULL)
        SET @CrunchTime = CONVERT(SMALLDATETIME, GETDATE());

    DROP TABLE IF EXISTS #TempDMDCPay;
    CREATE TABLE #TempDMDCPay
    (
        PayType NVARCHAR(50) NULL,
        PayPlan NVARCHAR(3) NULL,
        GradeLevel TINYINT NULL,
        Pay NUMERIC(17, 2) NULL,
        AmcosVersionId INT NULL,
    );

    INSERT INTO #TempDMDCPay
    (
        PayType,
        PayPlan,
        AmcosVersionId,
        GradeLevel,
        Pay
    )
    SELECT PayType,
           PayPlan,
           @AmcosVersionId,
           GradeLevel,
           SUM(TotalPayAmount) AS Pay
    FROM DMDC.Pay
    WHERE PayType = 'Uniform/Equipment Allowance'
          AND AmcosVersionId = @AmcosVersionId
    GROUP BY PayType,
             PayPlan,
             GradeLevel
    ORDER BY PayPlan,
             GradeLevel;

    DROP TABLE IF EXISTS #TempClothingCalc;
    CREATE TABLE #TempClothingCalc
    (
        PayPlan NVARCHAR(3) NULL,
        GradeLevel TINYINT NULL,
        Inventory INT NULL,
        AmcosVersionId INT NULL,
        YOS0 INT NULL,
        InKind NUMERIC(17, 2) NULL,
        InCash NUMERIC(17, 2) NULL,
        Total NUMERIC(17, 2) NULL
    );

    INSERT INTO #TempClothingCalc
    (
        PayPlan,
        GradeLevel,
        AmcosVersionId,
        Inventory
    )
    SELECT PayPlan,
           GradeLevel,
           AmcosVersionId,
           SUM(Inventory) AS inventory
    FROM data.KnownInventory
    WHERE PayPlan IN ( 'AE', 'AO', 'AWO', 'NE', 'NO', 'NWO', 'RE', 'RO', 'RWO' )
          AND AmcosVersionId = @AmcosVersionId
    GROUP BY PayPlan,
             GradeLevel,
             AmcosVersionId;

    /* now we add in the yos 0 folks who are our new recruits getting in kind clothing */
    UPDATE #TempClothingCalc
    SET YOS0 = ISNULL(Inventory.Inventory, 0)
    FROM #TempClothingCalc TempClothingCalc
        LEFT OUTER JOIN
        (
            SELECT PayPlan,
                   GradeLevel,
                   AmcosVersionId,
                   SUM(Inventory) AS Inventory
            FROM data.KnownInventory
            WHERE PayPlan IN ( 'AO', 'AE', 'AWO', 'RE', 'RO', 'RWO', 'NE', 'NO', 'NWO' )
                  AND AmcosVersionId = @AmcosVersionId
                  AND YOS = 0
            GROUP BY PayPlan,
                     GradeLevel,
                     AmcosVersionId
        ) Inventory
            ON TempClothingCalc.PayPlan = Inventory.PayPlan
               AND TempClothingCalc.GradeLevel = Inventory.GradeLevel;

    /* the following gets the budget amounts for every associated pay plan */
    DECLARE @AE_PB AS NUMERIC(17, 2);
    DECLARE @AO_AWO_PB AS NUMERIC(17, 2);
    DECLARE @NE_PB AS NUMERIC(17, 2);
    DECLARE @NO_NWO_PB AS NUMERIC(17, 2);
    DECLARE @RE_PB AS NUMERIC(17, 2);
    DECLARE @RO_RWO_PB AS NUMERIC(17, 2);
    SET @AE_PB = crunch.GetArmyBudgetSingleValue('AE_Clothing', 'MPA', 'Avg', @AmcosVersionId);
    SET @AO_AWO_PB = crunch.GetArmyBudgetSingleValue('AO_AWO_Clothing', '', 'Avg', @AmcosVersionId);
    SET @NE_PB = crunch.GetArmyBudgetSingleValue('NE_Clothing', 'NGPA', 'Avg', @AmcosVersionId);
    SET @NO_NWO_PB = crunch.GetArmyBudgetSingleValue('NO_NWO_Clothing', 'NGPA', 'Avg', @AmcosVersionId);
    SET @RE_PB = crunch.GetArmyBudgetSingleValue('RE_Clothing', 'RPA', 'Avg', @AmcosVersionId);
    SET @RO_RWO_PB = crunch.GetArmyBudgetSingleValue('RO_RWO_Clothing', 'RPA', 'Avg', @AmcosVersionId);

    /* the following computes the average cost per recruit (enlisted only),
	 per discussion with Marsha on 7/17/2019 YOS of 0 is used as the best representation of recruit */
    DECLARE @AE_YOS0_Cost AS NUMERIC(17, 2);
    DECLARE @RE_YOS0_Cost AS NUMERIC(17, 2);
    DECLARE @NE_YOS0_Cost AS NUMERIC(17, 2);

    /* the cost of in kind is the PB - the cash paid from dmdc */
    SET @AE_YOS0_Cost = (@AE_PB -
                         (
                             SELECT SUM(Pay)FROM #TempDMDCPay WHERE PayPlan = 'AE'
                         )
                        ) /
                        (
                            SELECT SUM(YOS0)FROM #TempClothingCalc WHERE PayPlan = 'AE'
                        );
    SET @RE_YOS0_Cost = (@RE_PB -
                         (
                             SELECT SUM(Pay)FROM #TempDMDCPay WHERE PayPlan = 'RE'
                         )
                        ) /
                        (
                            SELECT SUM(YOS0)FROM #TempClothingCalc WHERE PayPlan = 'RE'
                        );
    SET @NE_YOS0_Cost = (@NE_PB -
                         (
                             SELECT SUM(Pay)FROM #TempDMDCPay WHERE PayPlan = 'NE'
                         )
                        ) /
                        (
                            SELECT SUM(YOS0)FROM #TempClothingCalc WHERE PayPlan = 'NE'
                        );

    /* the cost of in kind is simply the average cost for each yos0 service member times the number of them in each 
    grade divided by the total inventory in that grade */
    UPDATE #TempClothingCalc
    SET InKind = (@AE_YOS0_Cost * YOS0) / Inventory
    WHERE PayPlan = 'AE';
    UPDATE #TempClothingCalc
    SET InKind = (@RE_YOS0_Cost * YOS0) / Inventory
    WHERE PayPlan = 'RE';
    UPDATE #TempClothingCalc
    SET InKind = (@NE_YOS0_Cost * YOS0) / Inventory
    WHERE PayPlan = 'NE';

    /* the in cash calculation is just straight from dmdc pay which is averaged */
    UPDATE #TempClothingCalc
    SET InCash = TempDMDCPay.Pay / TempClothingCalc.Inventory
    FROM #TempClothingCalc TempClothingCalc
        INNER JOIN #TempDMDCPay TempDMDCPay
            ON TempClothingCalc.PayPlan = TempDMDCPay.PayPlan
               AND TempClothingCalc.GradeLevel = TempDMDCPay.GradeLevel;

    --total then is the sum of the in cash and in kind values
    UPDATE #TempClothingCalc
    SET Total = ISNULL(InKind, 0) + ISNULL(InCash, 0);


    IF @Debug = 1
    BEGIN
        SELECT 'dmdc pay data';
        SELECT PayType,
               PayPlan,
               GradeLevel,
               Pay,
               AmcosVersionId
        FROM #TempDMDCPay;

        SELECT 'president budget data';
        SELECT ParameterName,
               Appropriation,
               FY,
               AmcosVersionId,
               Amount
        FROM crunch.ArmyBudgetSingleValues
        WHERE ParameterName LIKE '%clothing%'
              AND AmcosVersionId = @AmcosVersionId;

        SELECT 'clothing calculation table';
        SELECT PayPlan,
               GradeLevel,
               Inventory,
               AmcosVersionId,
               YOS0,
               InKind,
               InCash,
               Total
        FROM #TempClothingCalc;
    END;

    IF @Debug = 0
    BEGIN
        /* clear out the existing cost table for all the CE IDs we are about to insert values for */
        DELETE FROM crunch.Costs_AE
        WHERE CostElementId IN ( 7 )
              AND AmcosVersionId = @AmcosVersionId;

        DELETE FROM crunch.Costs_AO
        WHERE CostElementId IN ( 4215 )
              AND AmcosVersionId = @AmcosVersionId;

        DELETE FROM crunch.Costs_AWO
        WHERE CostElementId IN ( 4216 )
              AND AmcosVersionId = @AmcosVersionId;

        DELETE FROM crunch.Costs_NE
        WHERE CostElementId IN ( 327 )
              AND AmcosVersionId = @AmcosVersionId;

        DELETE FROM crunch.Costs_NO
        WHERE CostElementId IN ( 398 )
              AND AmcosVersionId = @AmcosVersionId;

        DELETE FROM crunch.Costs_NWO
        WHERE CostElementId IN ( 438 )
              AND AmcosVersionId = @AmcosVersionId;

        DELETE FROM crunch.Costs_RE
        WHERE CostElementId IN ( 491 )
              AND AmcosVersionId = @AmcosVersionId;


        DELETE FROM crunch.Costs_RO
        WHERE CostElementId IN ( 562 )
              AND AmcosVersionId = @AmcosVersionId;


        DELETE FROM crunch.Costs_RWO
        WHERE CostElementId IN ( 602 )
              AND AmcosVersionId = @AmcosVersionId;

        /* Insert average cost elements, note we calculate at the grade level but we need costs at the subgroup level
        so we join on inventory to bring in the subgroups */
        --AE
        INSERT INTO crunch.Costs_AE
        (
            PayPlan,
            CMF,
            MOS,
            CostElementId,
            GradeType,
            GradeLevel,
            WeaponSystemId,
            Amount,
            CrunchTime,
            AmcosVersionId,
            LocationId
        )
        SELECT Inventory.PayPlan,
               Inventory.CategoryGroupCode,
               Inventory.CategorySubgroupCode,
               7,
               Inventory.GradeType,
               Inventory.GradeLevel,
               -1,
               ISNULL(TempClothingCalc.Total, 0),
               @CrunchTime,
               @AmcosVersionId,
               -1
        FROM
        (
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   GradeType,
                   GradeLevel
            FROM data.KnownInventory
            WHERE PayPlan = 'AE'
                  AND AmcosVersionId = @AmcosVersionId
            GROUP BY PayPlan,
                     CategoryGroupCode,
                     CategorySubgroupCode,
                     GradeType,
                     GradeLevel
        ) Inventory
            LEFT OUTER JOIN #TempClothingCalc TempClothingCalc
                ON Inventory.PayPlan = TempClothingCalc.PayPlan
                   AND Inventory.GradeLevel = TempClothingCalc.GradeLevel;


        --NE
        INSERT INTO crunch.Costs_NE
        (
            PayPlan,
            CMF,
            MOS,
            CostElementId,
            GradeType,
            GradeLevel,
            WeaponSystemId,
            Amount,
            CrunchTime,
            AmcosVersionId
        )
        SELECT Inventory.PayPlan,
               Inventory.CategoryGroupCode,
               Inventory.CategorySubgroupCode,
               327,
               Inventory.GradeType,
               Inventory.GradeLevel,
               -1,
               ISNULL(TempClothingCalc.Total, 0),
               @CrunchTime,
               @AmcosVersionId
        FROM
        (
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   GradeType,
                   GradeLevel
            FROM data.KnownInventory
            WHERE PayPlan = 'NE'
                  AND AmcosVersionId = @AmcosVersionId
            GROUP BY PayPlan,
                     CategoryGroupCode,
                     CategorySubgroupCode,
                     GradeType,
                     GradeLevel
        ) Inventory
            LEFT OUTER JOIN #TempClothingCalc TempClothingCalc
                ON Inventory.PayPlan = TempClothingCalc.PayPlan
                   AND Inventory.GradeLevel = TempClothingCalc.GradeLevel;

        --RE
        INSERT INTO crunch.Costs_RE
        (
            PayPlan,
            CMF,
            MOS,
            CostElementId,
            GradeType,
            GradeLevel,
            WeaponSystemId,
            Amount,
            CrunchTime,
            AmcosVersionId
        )
        SELECT Inventory.PayPlan,
               Inventory.CategoryGroupCode,
               Inventory.CategorySubgroupCode,
               491,
               Inventory.GradeType,
               Inventory.GradeLevel,
               -1,
               ISNULL(TempClothingCalc.Total, 0),
               @CrunchTime,
               @AmcosVersionId
        FROM
        (
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   GradeType,
                   GradeLevel
            FROM data.KnownInventory
            WHERE PayPlan = 'RE'
                  AND AmcosVersionId = @AmcosVersionId
            GROUP BY PayPlan,
                     CategoryGroupCode,
                     CategorySubgroupCode,
                     GradeType,
                     GradeLevel
        ) Inventory
            LEFT OUTER JOIN #TempClothingCalc TempClothingCalc
                ON Inventory.PayPlan = TempClothingCalc.PayPlan
                   AND Inventory.GradeLevel = TempClothingCalc.GradeLevel;

        --AO
        INSERT INTO crunch.Costs_AO
        (
            PayPlan,
            CMF,
            AOC,
            CostElementId,
            GradeType,
            GradeLevel,
            WeaponSystemId,
            Amount,
            CrunchTime,
            AmcosVersionId,
            LocationId
        )
        SELECT Inventory.PayPlan,
               Inventory.CategoryGroupCode,
               Inventory.CategorySubgroupCode,
               4215,
               Inventory.GradeType,
               Inventory.GradeLevel,
               -1,
               ISNULL(TempClothingCalc.Total, 0),
               @CrunchTime,
               @AmcosVersionId,
               -1
        FROM
        (
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   GradeType,
                   GradeLevel
            FROM data.KnownInventory
            WHERE PayPlan = 'AO'
                  AND AmcosVersionId = @AmcosVersionId
            GROUP BY PayPlan,
                     CategoryGroupCode,
                     CategorySubgroupCode,
                     GradeType,
                     GradeLevel
        ) Inventory
            LEFT OUTER JOIN #TempClothingCalc TempClothingCalc
                ON Inventory.PayPlan = TempClothingCalc.PayPlan
                   AND Inventory.GradeLevel = TempClothingCalc.GradeLevel;

        --RO
        INSERT INTO crunch.Costs_RO
        (
            PayPlan,
            CMF,
            AOC,
            CostElementId,
            GradeType,
            GradeLevel,
            WeaponSystemId,
            Amount,
            CrunchTime,
            AmcosVersionId
        )
        SELECT Inventory.PayPlan,
               Inventory.CategoryGroupCode,
               Inventory.CategorySubgroupCode,
               562,
               Inventory.GradeType,
               Inventory.GradeLevel,
               -1,
               ISNULL(TempClothingCalc.Total, 0),
               @CrunchTime,
               @AmcosVersionId
        FROM
        (
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   GradeType,
                   GradeLevel
            FROM data.KnownInventory
            WHERE PayPlan = 'RO'
                  AND AmcosVersionId = @AmcosVersionId
            GROUP BY PayPlan,
                     CategoryGroupCode,
                     CategorySubgroupCode,
                     GradeType,
                     GradeLevel
        ) Inventory
            LEFT OUTER JOIN #TempClothingCalc TempClothingCalc
                ON Inventory.PayPlan = TempClothingCalc.PayPlan
                   AND Inventory.GradeLevel = TempClothingCalc.GradeLevel;

        --NO
        INSERT INTO crunch.Costs_NO
        (
            PayPlan,
            CMF,
            AOC,
            CostElementId,
            GradeType,
            GradeLevel,
            WeaponSystemId,
            Amount,
            CrunchTime,
            AmcosVersionId
        )
        SELECT Inventory.PayPlan,
               Inventory.CategoryGroupCode,
               Inventory.CategorySubgroupCode,
               398,
               Inventory.GradeType,
               Inventory.GradeLevel,
               -1,
               ISNULL(TempClothingCalc.Total, 0),
               @CrunchTime,
               @AmcosVersionId
        FROM
        (
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   GradeType,
                   GradeLevel
            FROM data.KnownInventory
            WHERE PayPlan = 'NO'
                  AND AmcosVersionId = @AmcosVersionId
            GROUP BY PayPlan,
                     CategoryGroupCode,
                     CategorySubgroupCode,
                     GradeType,
                     GradeLevel
        ) Inventory
            LEFT OUTER JOIN #TempClothingCalc TempClothingCalc
                ON Inventory.PayPlan = TempClothingCalc.PayPlan
                   AND Inventory.GradeLevel = TempClothingCalc.GradeLevel;

        --AWO
        INSERT INTO crunch.Costs_AWO
        (
            PayPlan,
            Branch,
            WOMOS,
            CostElementId,
            GradeType,
            GradeLevel,
            WeaponSystemId,
            Amount,
            CrunchTime,
            AmcosVersionId,
            LocationId
        )
        SELECT Inventory.PayPlan,
               Inventory.CategoryGroupCode,
               Inventory.CategorySubgroupCode,
               4216,
               Inventory.GradeType,
               Inventory.GradeLevel,
               -1,
               ISNULL(TempClothingCalc.Total, 0),
               @CrunchTime,
               @AmcosVersionId,
               -1
        FROM
        (
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   GradeType,
                   GradeLevel
            FROM data.KnownInventory
            WHERE PayPlan = 'AWO'
                  AND AmcosVersionId = @AmcosVersionId
            GROUP BY PayPlan,
                     CategoryGroupCode,
                     CategorySubgroupCode,
                     GradeType,
                     GradeLevel
        ) Inventory
            LEFT OUTER JOIN #TempClothingCalc TempClothingCalc
                ON Inventory.PayPlan = TempClothingCalc.PayPlan
                   AND Inventory.GradeLevel = TempClothingCalc.GradeLevel;

        --RWO
        INSERT INTO crunch.Costs_RWO
        (
            PayPlan,
            Branch,
            WOMOS,
            CostElementId,
            GradeType,
            GradeLevel,
            WeaponSystemId,
            Amount,
            CrunchTime,
            AmcosVersionId
        )
        SELECT Inventory.PayPlan,
               Inventory.CategoryGroupCode,
               Inventory.CategorySubgroupCode,
               602,
               Inventory.GradeType,
               Inventory.GradeLevel,
               -1,
               ISNULL(TempClothingCalc.Total, 0),
               @CrunchTime,
               @AmcosVersionId
        FROM
        (
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   GradeType,
                   GradeLevel
            FROM data.KnownInventory
            WHERE PayPlan = 'RWO'
                  AND AmcosVersionId = @AmcosVersionId
            GROUP BY PayPlan,
                     CategoryGroupCode,
                     CategorySubgroupCode,
                     GradeType,
                     GradeLevel
        ) Inventory
            LEFT OUTER JOIN #TempClothingCalc TempClothingCalc
                ON Inventory.PayPlan = TempClothingCalc.PayPlan
                   AND Inventory.GradeLevel = TempClothingCalc.GradeLevel;

        --NWO
        INSERT INTO crunch.Costs_NWO
        (
            PayPlan,
            Branch,
            WOMOS,
            CostElementId,
            GradeType,
            GradeLevel,
            WeaponSystemId,
            Amount,
            CrunchTime,
            AmcosVersionId
        )
        SELECT Inventory.PayPlan,
               Inventory.CategoryGroupCode,
               Inventory.CategorySubgroupCode,
               438,
               Inventory.GradeType,
               Inventory.GradeLevel,
               -1,
               ISNULL(TempClothingCalc.Total, 0),
               @CrunchTime,
               @AmcosVersionId
        FROM
        (
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   GradeType,
                   GradeLevel
            FROM data.KnownInventory
            WHERE PayPlan = 'NWO'
                  AND AmcosVersionId = @AmcosVersionId
            GROUP BY PayPlan,
                     CategoryGroupCode,
                     CategorySubgroupCode,
                     GradeType,
                     GradeLevel
        ) Inventory
            LEFT OUTER JOIN #TempClothingCalc TempClothingCalc
                ON Inventory.PayPlan = TempClothingCalc.PayPlan
                   AND Inventory.GradeLevel = TempClothingCalc.GradeLevel;

    END;
END;