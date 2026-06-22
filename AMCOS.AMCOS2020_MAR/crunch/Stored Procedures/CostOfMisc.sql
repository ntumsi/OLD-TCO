
-- =============================================
-- Author:Dan Hogan
-- Create date: 8/26/2019
-- Description:	Cost of Misc and all other Benefits
-- Considerations: this crunch must be run after crunches which compute other benefit costs
-- for example at the time of writing the cost of clothing and fica are separate crunches and must be run BEFORE this crunch



-- =============================================
CREATE PROCEDURE [crunch].[CostOfMisc]
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


    DROP TABLE IF EXISTS #inventory;
    CREATE TABLE #inventory
    (
        PayPlan NVARCHAR(3) NULL,
        GradeLevel TINYINT NULL,
        CategoryGroupCode NVARCHAR(2) NULL,
        CategorySubgroupCode NVARCHAR(4) NULL,
        GradeType NVARCHAR(3) NULL,
        inventory INT NULL,
        AmcosVersionId INT NULL,
    );

    INSERT INTO #inventory
    (
        PayPlan,
        GradeLevel,
        GradeType,
        CategoryGroupCode,
        CategorySubgroupCode,
        inventory,
        AmcosVersionId
    )
    -- get all the military inventory at the subgroup level
    SELECT PayPlan,
           GradeLevel,
           GradeType,
           CategoryGroupCode,
           CategorySubgroupCode,
           SUM(Inventory) AS inventory,
           AmcosVersionId
    FROM data.KnownInventory
    WHERE PayPlan IN ( 'AE', 'AO', 'AWO' ) --,'RE','RO','RWO','NE','NO','NWO')
          AND AmcosVersionId = @AmcosVersionId
    GROUP BY PayPlan,
             GradeLevel,
             GradeType,
             CategoryGroupCode,
             CategorySubgroupCode,
             AmcosVersionId;



    DECLARE @AO_Misc_budget NUMERIC(20, 2) = crunch.GetArmyBudgetSingleValue('AO_Misc', 'MPA', 'Avg', @AmcosVersionId),
            @AE_Misc_budget NUMERIC(20, 2) = crunch.GetArmyBudgetSingleValue('AE_Misc', 'MPA', 'Avg', @AmcosVersionId);

    --AWO doesn't have a budget so we use AO's budget for both
    DECLARE @Amt_AO_AWO_Misc NUMERIC(20, 2)
        = @AO_Misc_budget /
          (
              SELECT SUM(inventory)FROM #inventory WHERE PayPlan IN ( 'AO', 'AWO' )
          ),
            @Amt_AE_Misc NUMERIC(20, 2) = @AE_Misc_budget /
                                          (
                                              SELECT SUM(inventory)FROM #inventory WHERE PayPlan = 'AE'
                                          );

    --Declare all the CE IDs we are going to use
    DECLARE @CE_AE_Misc INT = 9,
            @CE_AO_Misc INT = 144,
            @CE_AWO_Misc INT = 218,
            @CE_AE_Clothing INT = 7,
            @CE_AO_Clothing INT = 4215,
            @CE_AWO_Clothing INT = 4216,
            @CE_AE_FICA INT = 8,
            @CE_AO_FICA INT = 143,
            @CE_AWO_FICA INT = 217,
            @CE_AE_Total INT = 10,
            @CE_AO_Total INT = 145,
            @CE_AWO_Total INT = 219;




    --show calculations up to this point if debug mode is on
    IF @Debug = 1
    BEGIN

        SELECT 'AO/AWO Amt: ' + FORMAT(ISNULL(@Amt_AO_AWO_Misc, 0), 'C', 'en-us');
        SELECT 'AE Amt:' + FORMAT(ISNULL(@Amt_AE_Misc, 0), 'C', 'en-us');
    END;
    IF @Debug = 0
    BEGIN
        /* clear out the existing cost table for all the CE IDs we are about to insert values for */
        DELETE FROM crunch.Costs_AE
        WHERE CostElementId IN ( @CE_AE_Misc, @CE_AE_Total )
              AND AmcosVersionId = @AmcosVersionId;

        DELETE FROM crunch.Costs_AO
        WHERE CostElementId IN ( @CE_AO_Misc, @CE_AO_Total )
              AND AmcosVersionId = @AmcosVersionId;

        DELETE FROM crunch.Costs_AWO
        WHERE CostElementId IN ( @CE_AWO_Misc, @CE_AWO_Total )
              AND AmcosVersionId = @AmcosVersionId;

        /* Insert average cost elements, note we calculate at the Single Value level but we need costs at the subgroup level
        so we join on inventory to bring in the subgroups */
        --Note that the total costs is the sum of the other benefits parts for MPA
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
        SELECT PayPlan,
               CategoryGroupCode,
               CategorySubgroupCode,
               @CE_AE_Misc,
               GradeType,
               GradeLevel,
               -1,
               @Amt_AE_Misc,
               @CrunchTime,
               @AmcosVersionId,
               -1
        FROM #inventory
        WHERE PayPlan = 'AE'
        UNION
        SELECT PayPlan,
               CMF,
               MOS,
               @CE_AE_Total,
               GradeType,
               GradeLevel,
               -1,
               SUM(Amount) + @Amt_AE_Misc,
               @CrunchTime,
               @AmcosVersionId,
               -1
        FROM crunch.Costs_AE
        WHERE PayPlan = 'AE'
              AND AmcosVersionId = @AmcosVersionId
              AND CostElementId IN ( @CE_AE_Clothing, @CE_AE_FICA )
        GROUP BY PayPlan,
                 CMF,
                 MOS,
                 GradeType,
                 GradeLevel;


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
        SELECT PayPlan,
               CategoryGroupCode,
               CategorySubgroupCode,
               @CE_AO_Misc,
               GradeType,
               GradeLevel,
               -1,
               @Amt_AO_AWO_Misc,
               @CrunchTime,
               @AmcosVersionId,
               -1
        FROM #inventory
        WHERE PayPlan = 'AO'
        UNION
        SELECT PayPlan,
               CMF,
               AOC,
               @CE_AO_Total,
               GradeType,
               GradeLevel,
               -1,
               SUM(Amount) + @Amt_AO_AWO_Misc,
               @CrunchTime,
               @AmcosVersionId,
               -1
        FROM crunch.Costs_AO
        WHERE PayPlan = 'AO'
              AND AmcosVersionId = @AmcosVersionId
              AND CostElementId IN ( @CE_AO_Clothing, @CE_AO_FICA )
        GROUP BY PayPlan,
                 CMF,
                 AOC,
                 GradeType,
                 GradeLevel;

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
        SELECT PayPlan,
               CategoryGroupCode,
               CategorySubgroupCode,
               @CE_AWO_Misc,
               GradeType,
               GradeLevel,
               -1,
               @Amt_AO_AWO_Misc,
               @CrunchTime,
               @AmcosVersionId,
               -1
        FROM #inventory
        WHERE PayPlan = 'AWO'
        UNION
        SELECT PayPlan,
               Branch,
               WOMOS,
               @CE_AWO_Total,
               GradeType,
               GradeLevel,
               -1,
               SUM(Amount) + @Amt_AO_AWO_Misc,
               @CrunchTime,
               @AmcosVersionId,
               -1
        FROM crunch.Costs_AWO
        WHERE PayPlan = 'AWO'
              AND AmcosVersionId = @AmcosVersionId
              AND CostElementId IN ( @CE_AWO_Clothing, @CE_AWO_FICA )
        GROUP BY PayPlan,
                 Branch,
                 WOMOS,
                 GradeType,
                 GradeLevel;




    END;
END;