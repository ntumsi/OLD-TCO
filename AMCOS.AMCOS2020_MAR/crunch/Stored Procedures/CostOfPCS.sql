
-- =============================================
-- Author:Dan Hogan
-- Create date: 7/31/2019
-- Description:	Cost of PCS
-- Considerations: see below for an accounting of all move costs FMR 11A Chapter 6 guides this calculation

--5A Accession move - this is already accounted for in Ofc Acq & Recruiting so will not removed from the new calc
--5B Training move - remains a part of the PCS CE (not in the cost of training calculations)
--5C Operational move - remains a part of the PCS CE
--5D Rotational move - remains a part of the PCS CE
--5E Separation move - remains a part of the PCS CE
--5F Organizational Unit move/travel - not in AMCOS now so will be an addition in spring 2020


-- =============================================
CREATE PROCEDURE [crunch].[CostOfPCS]
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
    WHERE PayPlan IN ( 'AE', 'AO', 'AWO', 'RE', 'RO', 'RWO', 'NE', 'NO', 'NWO' )
          AND AmcosVersionId = @AmcosVersionId
    GROUP BY PayPlan,
             GradeLevel,
             GradeType,
             CategoryGroupCode,
             CategorySubgroupCode,
             AmcosVersionId;


    -- note that the FMR states the calculation is the cost  / average strength which we used the PB projected inventory for

    --get the inventory amounts
    DECLARE @AE_PB_Inv INT = crunch.GetArmyBudgetSingleValue('Avg_AE_End_Strength', 'MPA', 'avg', @AmcosVersionId);
    DECLARE @AO_AWO_PB_Inv INT
        = crunch.GetArmyBudgetSingleValue('Avg_AO_End_Strength', 'MPA', 'avg', @AmcosVersionId)
          + crunch.GetArmyBudgetSingleValue('Avg_AWO_End_Strength', 'MPA', 'avg', @AmcosVersionId);

    SET @AE_PB_Inv =
    (
        SELECT SUM(inventory)FROM #inventory WHERE PayPlan = 'AE'
    );
    SET @AO_AWO_PB_Inv =
    (
        SELECT SUM(inventory)FROM #inventory WHERE PayPlan IN ( 'AO', 'AWO' )
    );


    --5B Training move - remains a part of the PCS CE (not in the cost of training calculations)
    --5C Operational move - remains a part of the PCS CE
    --5D Rotational move - remains a part of the PCS CE
    --5E Separation move - remains a part of the PCS CE
    --5F Organizational Unit move/travel - not in AMCOS now so will be an addition in spring 2020


    --Active Enlisted calculations
    DECLARE @AE_Training_move FLOAT
        = crunch.GetArmyBudgetSingleValue('Enlisted_PCS_Training_Move_Budget', 'MPA', 'avg', @AmcosVersionId)
          / @AE_PB_Inv;
    DECLARE @AE_Rotational_move FLOAT
        = crunch.GetArmyBudgetSingleValue('Enlisted_PCS_Rotational_Move_Budget', 'MPA', 'avg', @AmcosVersionId)
          / @AE_PB_Inv;
    DECLARE @AE_Separation_move FLOAT
        = crunch.GetArmyBudgetSingleValue('Enlisted_PCS_Separation_Move_Budget', 'MPA', 'avg', @AmcosVersionId)
          / @AE_PB_Inv;
    DECLARE @AE_Organizational_move FLOAT
        = crunch.GetArmyBudgetSingleValue('Enlisted_PCS_Unit_Move_Budget', 'MPA', 'avg', @AmcosVersionId) / @AE_PB_Inv;
    DECLARE @AE_Operational_move FLOAT
        = crunch.GetArmyBudgetSingleValue('Enlisted_PCS_Operational_Move_Budget', 'MPA', 'avg', @AmcosVersionId)
          / @AE_PB_Inv;
    DECLARE @AE_PCS_Total FLOAT
        = @AE_Training_move + @AE_Rotational_move + @AE_Separation_move + @AE_Organizational_move
          + @AE_Operational_move;

    --Active Officer/Warrant calculations
    DECLARE @AO_AWO_Training_move FLOAT
        = crunch.GetArmyBudgetSingleValue('Officer_PCS_Training_Move_Budget', 'MPA', 'avg', @AmcosVersionId)
          / @AO_AWO_PB_Inv;
    DECLARE @AO_AWO_Rotational_move FLOAT
        = crunch.GetArmyBudgetSingleValue('Officer_PCS_Rotational_Move_Budget', 'MPA', 'avg', @AmcosVersionId)
          / @AO_AWO_PB_Inv;
    DECLARE @AO_AWO_Separation_move FLOAT
        = crunch.GetArmyBudgetSingleValue('Officer_PCS_Separation_Move_Budget', 'MPA', 'avg', @AmcosVersionId)
          / @AO_AWO_PB_Inv;
    DECLARE @AO_AWO_Organizational_move FLOAT
        = crunch.GetArmyBudgetSingleValue('Officer_PCS_Unit_Move_Budget', 'MPA', 'avg', @AmcosVersionId)
          / @AO_AWO_PB_Inv;
    DECLARE @AO_AWO_Operational_move FLOAT
        = crunch.GetArmyBudgetSingleValue('Officer_PCS_Operational_Move_Budget', 'MPA', 'avg', @AmcosVersionId)
          / @AO_AWO_PB_Inv;
    DECLARE @AO_AWO_PCS_Total FLOAT
        = @AO_AWO_Training_move + @AO_AWO_Rotational_move + @AO_AWO_Separation_move + @AO_AWO_Organizational_move
          + @AO_AWO_Operational_move;



    --show calculations up to this point if debug mode is on
    IF @Debug = 1
    BEGIN
        SELECT 'AE PB inv: ' + FORMAT(ISNULL(@AE_PB_Inv, 0), 'N', 'en-us');
        SELECT 'AO_AWO PB inv: ' + FORMAT(ISNULL(@AO_AWO_PB_Inv, 0), 'N', 'en-us');



        SELECT 'AE Trainnig: ' + FORMAT(ISNULL(@AE_Training_move, 0), 'C', 'en-us');
        SELECT 'AE Rotational: ' + FORMAT(ISNULL(@AE_Rotational_move, 0), 'C', 'en-us');
        SELECT 'AE Separation: ' + FORMAT(ISNULL(@AE_Separation_move, 0), 'C', 'en-us');
        SELECT 'AE Org Unit: ' + FORMAT(ISNULL(@AE_Organizational_move, 0), 'C', 'en-us');
        SELECT 'AE Operational: ' + FORMAT(ISNULL(@AE_Operational_move, 0), 'C', 'en-us');
        SELECT 'AE Total: ' + FORMAT(ISNULL(@AE_PCS_Total, 0), 'C', 'en-us');

        SELECT 'AO AWO Trainnig: ' + FORMAT(ISNULL(@AO_AWO_Training_move, 0), 'C', 'en-us');
        SELECT 'AO AWO Rotational: ' + FORMAT(ISNULL(@AO_AWO_Rotational_move, 0), 'C', 'en-us');
        SELECT 'AO AWO Separation: ' + FORMAT(ISNULL(@AO_AWO_Separation_move, 0), 'C', 'en-us');
        SELECT 'AO AWO Org Unit: ' + FORMAT(ISNULL(@AO_AWO_Organizational_move, 0), 'C', 'en-us');
        SELECT 'AO AWO Operational: ' + FORMAT(ISNULL(@AO_AWO_Operational_move, 0), 'C', 'en-us');
        SELECT 'AO AWO Total: ' + FORMAT(ISNULL(@AO_AWO_PCS_Total, 0), 'C', 'en-us');

    END;
    IF @Debug = 0
    BEGIN
        /* clear out the existing cost table for all the CE IDs we are about to insert values for */
        DELETE FROM crunch.Costs_AE
        WHERE CostElementId IN ( 14, 15, 16, 12, 13, 17, 4217 )
              AND AmcosVersionId = @AmcosVersionId;

        DELETE FROM crunch.Costs_AO
        WHERE CostElementId IN ( 146, 147, 148, 149, 150, 4218 )
              AND AmcosVersionId = @AmcosVersionId;

        DELETE FROM crunch.Costs_AWO
        WHERE CostElementId IN ( 221, 222, 223, 220, 224, 4219 )
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

        --training move
        SELECT PayPlan,
               CategoryGroupCode,
               CategorySubgroupCode,
               16,
               GradeType,
               GradeLevel,
               -1,
               @AE_Training_move,
               @CrunchTime,
               @AmcosVersionId,
               -1
        FROM #inventory
        WHERE PayPlan = 'AE'
        UNION
        --rotational move
        SELECT PayPlan,
               CategoryGroupCode,
               CategorySubgroupCode,
               14,
               GradeType,
               GradeLevel,
               -1,
               @AE_Rotational_move,
               @CrunchTime,
               @AmcosVersionId,
               -1
        FROM #inventory
        WHERE PayPlan = 'AE'
        UNION
        --separation move
        SELECT PayPlan,
               CategoryGroupCode,
               CategorySubgroupCode,
               15,
               GradeType,
               GradeLevel,
               -1,
               @AE_Separation_move,
               @CrunchTime,
               @AmcosVersionId,
               -1
        FROM #inventory
        WHERE PayPlan = 'AE'
        UNION
        --organizational move
        SELECT PayPlan,
               CategoryGroupCode,
               CategorySubgroupCode,
               4217,
               GradeType,
               GradeLevel,
               -1,
               @AE_Organizational_move,
               @CrunchTime,
               @AmcosVersionId,
               -1
        FROM #inventory
        WHERE PayPlan = 'AE'
        UNION
        --operational move
        SELECT PayPlan,
               CategoryGroupCode,
               CategorySubgroupCode,
               13,
               GradeType,
               GradeLevel,
               -1,
               @AE_Operational_move,
               @CrunchTime,
               @AmcosVersionId,
               -1
        FROM #inventory
        WHERE PayPlan = 'AE'
        UNION
        --total move cost
        SELECT PayPlan,
               CategoryGroupCode,
               CategorySubgroupCode,
               17,
               GradeType,
               GradeLevel,
               -1,
               @AE_PCS_Total,
               @CrunchTime,
               @AmcosVersionId,
               -1
        FROM #inventory
        WHERE PayPlan = 'AE';



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
        --training move
        SELECT PayPlan,
               CategoryGroupCode,
               CategorySubgroupCode,
               149,
               GradeType,
               GradeLevel,
               -1,
               @AO_AWO_Training_move,
               @CrunchTime,
               @AmcosVersionId,
               -1
        FROM #inventory
        WHERE PayPlan = 'AO'
        UNION
        --rotational move
        SELECT PayPlan,
               CategoryGroupCode,
               CategorySubgroupCode,
               147,
               GradeType,
               GradeLevel,
               -1,
               @AO_AWO_Rotational_move,
               @CrunchTime,
               @AmcosVersionId,
               -1
        FROM #inventory
        WHERE PayPlan = 'AO'
        UNION
        --separation move
        SELECT PayPlan,
               CategoryGroupCode,
               CategorySubgroupCode,
               148,
               GradeType,
               GradeLevel,
               -1,
               @AO_AWO_Separation_move,
               @CrunchTime,
               @AmcosVersionId,
               -1
        FROM #inventory
        WHERE PayPlan = 'AO'
        UNION
        --organizational move
        SELECT PayPlan,
               CategoryGroupCode,
               CategorySubgroupCode,
               4218,
               GradeType,
               GradeLevel,
               -1,
               @AO_AWO_Organizational_move,
               @CrunchTime,
               @AmcosVersionId,
               -1
        FROM #inventory
        WHERE PayPlan = 'AO'
        UNION
        --operational move
        SELECT PayPlan,
               CategoryGroupCode,
               CategorySubgroupCode,
               146,
               GradeType,
               GradeLevel,
               -1,
               @AO_AWO_Operational_move,
               @CrunchTime,
               @AmcosVersionId,
               -1
        FROM #inventory
        WHERE PayPlan = 'AO'
        UNION
        --total move cost
        SELECT PayPlan,
               CategoryGroupCode,
               CategorySubgroupCode,
               150,
               GradeType,
               GradeLevel,
               -1,
               @AO_AWO_PCS_Total,
               @CrunchTime,
               @AmcosVersionId,
               -1
        FROM #inventory
        WHERE PayPlan = 'AO';

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
        --training move
        SELECT PayPlan,
               CategoryGroupCode,
               CategorySubgroupCode,
               223,
               GradeType,
               GradeLevel,
               -1,
               @AO_AWO_Training_move,
               @CrunchTime,
               @AmcosVersionId,
               -1
        FROM #inventory
        WHERE PayPlan = 'AWO'
        UNION
        --rotational move
        SELECT PayPlan,
               CategoryGroupCode,
               CategorySubgroupCode,
               221,
               GradeType,
               GradeLevel,
               -1,
               @AO_AWO_Rotational_move,
               @CrunchTime,
               @AmcosVersionId,
               -1
        FROM #inventory
        WHERE PayPlan = 'AWO'
        UNION
        --separation move
        SELECT PayPlan,
               CategoryGroupCode,
               CategorySubgroupCode,
               222,
               GradeType,
               GradeLevel,
               -1,
               @AO_AWO_Separation_move,
               @CrunchTime,
               @AmcosVersionId,
               -1
        FROM #inventory
        WHERE PayPlan = 'AWO'
        UNION
        --organizational move
        SELECT PayPlan,
               CategoryGroupCode,
               CategorySubgroupCode,
               4219,
               GradeType,
               GradeLevel,
               -1,
               @AO_AWO_Organizational_move,
               @CrunchTime,
               @AmcosVersionId,
               -1
        FROM #inventory
        WHERE PayPlan = 'AWO'
        UNION
        --operational move
        SELECT PayPlan,
               CategoryGroupCode,
               CategorySubgroupCode,
               220,
               GradeType,
               GradeLevel,
               -1,
               @AO_AWO_Operational_move,
               @CrunchTime,
               @AmcosVersionId,
               -1
        FROM #inventory
        WHERE PayPlan = 'AWO'
        UNION
        --total move cost
        SELECT PayPlan,
               CategoryGroupCode,
               CategorySubgroupCode,
               224,
               GradeType,
               GradeLevel,
               -1,
               @AO_AWO_PCS_Total,
               @CrunchTime,
               @AmcosVersionId,
               -1
        FROM #inventory
        WHERE PayPlan = 'AWO';

    END;
END;