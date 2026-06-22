
-- =============================================
-- Author:Dan Hogan
-- Create date: 8/2/2019
-- Description:	Cost of Simple Cost Elements
-- Considerations: this crunch consolidates simple (e.g. single value based CEs or simple calculations)
-- into a single crunch which is easier to read and understand
-- =============================================
CREATE PROCEDURE [crunch].[CostOfSimpleCEs]
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

    DROP TABLE IF EXISTS #Inventory;
    CREATE TABLE #Inventory
    (
        PayPlan NVARCHAR(3) NULL,
        GradeLevel TINYINT NULL,
        CategoryGroupCode NVARCHAR(2) NULL,
        CategorySubgroupCode NVARCHAR(4) NULL,
        GradeType NVARCHAR(3) NULL,
        Inventory INT NULL,
        AmcosVersionId INT NULL,
    );

    INSERT INTO #Inventory
    (
        PayPlan,
        GradeLevel,
        GradeType,
        CategoryGroupCode,
        CategorySubgroupCode,
        Inventory,
        AmcosVersionId
    )
    /* get all the military inventory at the subgroup level */
    SELECT PayPlan,
           GradeLevel,
           GradeType,
           CategoryGroupCode,
           CategorySubgroupCode,
           SUM(Inventory) AS Inventory,
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

    --days in a year
    DECLARE @Days FLOAT = 365.0;
    DECLARE @activeDays FLOAT = crunch.GetSingleValue('AA', 'activedays', @AmcosVersionId);


    -- ### Active computations ####
    --Cost of MERHC
    DECLARE @CE_AE_MERHC INT = 83,
            @CE_AO_MerHC INT = 180,
            @CE_AWO_MERHC INT = 245,
            @Amt_Active_MERHC NUMERIC(20, 2) = crunch.GetSingleValue('AA', 'MERHC', @AmcosVersionId);




    --Cost of Morale Welfare and Recreation (MWR)
    DECLARE @CE_AE_MWR INT
        = 75,
            @CE_AO_MWR INT = 174,
            @CE_AWO_MWR INT = 248,
            @Amt_Active_MWR NUMERIC(20, 2) = crunch.GetArmyBudgetSingleValue(
                                                                                'MoraleWelfareRecreation',
                                                                                'OMA',
                                                                                'Avg',
                                                                                @AmcosVersionId
                                                                            )
                                             / crunch.GetArmyBudgetSingleValue(
                                                                                  'Avg_OE_End_Strength',
                                                                                  'MPA',
                                                                                  'Avg',
                                                                                  @AmcosVersionId
                                                                              );



    --Cost of Medical Suport
    DECLARE @CE_AE_Medical INT
        = 74,
            @CE_AO_Medical INT = 173,
            @CE_AWO_medical INT = 247,
            @Amt_Active_medical NUMERIC(20, 2) = crunch.GetSingleValue(
                                                                          'AA',
                                                                          'Health_Care_Cost_Per_Family_Member',
                                                                          @AmcosVersionId
                                                                      );




    --Cost of Discount Groceries
    DECLARE @CE_AE_Groceries INT = 774,
            @CE_AO_Groceries INT = 790,
            @CE_AWO_Groceries INT = 806,
            @Amt_Active_Groceries NUMERIC(20, 2) = crunch.GetSingleValue('AA', 'DiscountGroceries', @AmcosVersionId);



    --DoDEA and FA
    DECLARE @CE_AE_DoDEA INT
        = 775,
            @CE_AO_DoDEA INT = 791,
            @CE_AWO_DoDEA INT = 807,
            @Amt_Active_DoDEA NUMERIC(20, 2) = crunch.GetSingleValue('AA', 'DoDEAandFamilyAssistance', @AmcosVersionId);


    --Child Education
    DECLARE @CE_AE_ChildEdu INT = 773,
            @CE_AO_ChildEdu INT = 789,
            @CE_AWO_ChildEdu INT = 805,
            @Amt_Active_ChildEdu NUMERIC(20, 2) = crunch.GetSingleValue('AA', 'ChildEducation', @AmcosVersionId);




    --Treasury Concurrent Receipts
    DECLARE @CE_AE_ConcurRec INT
        = 777,
            @CE_AO_ConcurRec INT = 793,
            @CE_AWO_ConcurRec INT = 809,
            @Amt_Active_ConcurRec NUMERIC(20, 2) = crunch.GetSingleValue(
                                                                            'AA',
                                                                            'TreasuryContributionForConcurrentReceipts',
                                                                            @AmcosVersionId
                                                                        );


    --Treasury MERHC
    DECLARE @CE_AE_Treas_MERHCF INT
        = 778,
            @CE_AO_Treas_MERHCF INT = 794,
            @CE_AWO_Treas_MERHCF INT = 810,
            @Amt_Active_Treas_MERHCF NUMERIC(20, 2) = crunch.GetSingleValue(
                                                                               'AA',
                                                                               'TreasuryContributionToMERHC',
                                                                               @AmcosVersionId
                                                                           );

    --Veteran Benefits
    DECLARE @CE_AE_Veteran INT = 780,
            @CE_AO_Veteran INT = 796,
            @CE_AWO_Veteran INT = 812,
            @Amt_Active_Veteran NUMERIC(20, 2) = crunch.GetSingleValue('AA', 'VeteransBenefits', @AmcosVersionId);


    --#### NG/R Computations #####

    --Cost of Health Care
    --this is only for the NG/R and its just prorating the medical support cost above
    DECLARE @CE_NE_Health INT = 288,
            @CE_NO_Health INT = 358,
            @CE_NWO_Health INT = 412,
            @CE_RE_Health INT = 452,
            @CE_RO_Health INT = 522,
            @CE_RWO_Health INT = 576,
            @Amt_NG_R_Health NUMERIC(20, 2) = @Amt_Active_medical / @Days * @activeDays;

    -- RE Disability, Hospitalization & Death Gratuities (DHDG)
    DECLARE @RE_DHDG NUMERIC(20, 2)
        = crunch.GetArmyBudgetSingleValue('RE_DHDG', 'RPA', 'Avg', @AmcosVersionId),
            @RE_Endstrength NUMERIC(20, 2) = crunch.GetArmyBudgetSingleValue(
                                                                                'RE_Endstrength',
                                                                                'RPA',
                                                                                'Avg',
                                                                                @AmcosVersionId
                                                                            );
    DECLARE @Amt_RE_DHDG NUMERIC(20, 2) = @RE_DHDG / @RE_Endstrength,
            @CE_RE_DHDG INT = 494;

    -- RO/RWO Disability, Hospitalization & Death Gratuities (DHDG)
    DECLARE @RO_RWO_DHDG NUMERIC(20, 2)
        = crunch.GetArmyBudgetSingleValue('RO_RWO_DHDG', 'RPA', 'Avg', @AmcosVersionId),
            @RO_RWO_Endstrength NUMERIC(20, 2) = crunch.GetArmyBudgetSingleValue(
                                                                                    'RO_RWO_Endstrength',
                                                                                    'RPA',
                                                                                    'Avg',
                                                                                    @AmcosVersionId
                                                                                );
    DECLARE @Amt_RO_RWO_DHDG NUMERIC(20, 2) = @RO_RWO_DHDG / @RO_RWO_Endstrength,
            @CE_RO_DHDG INT = 563,
            @CE_RWO_DHDG INT = 603;

    -- NE Disability, Hospitalization & Death Gratuities (DHDG)
    DECLARE @NE_DHDG NUMERIC(20, 2)
        = crunch.GetArmyBudgetSingleValue('NE_DHDG', 'NGPA', 'Avg', @AmcosVersionId),
            @NE_Endstrength NUMERIC(20, 2) = crunch.GetArmyBudgetSingleValue(
                                                                                'NE_Endstrength',
                                                                                'NGPA',
                                                                                'Avg',
                                                                                @AmcosVersionId
                                                                            );
    DECLARE @Amt_NE_DHDG NUMERIC(20, 2) = @NE_DHDG / @NE_Endstrength,
            @CE_NE_DHDG NUMERIC(20, 2) = 330;

    -- NO/NWO Disability, Hospitalization & Death Gratuities (DHDG)
    DECLARE @NO_NWO_Endstrength NUMERIC(20, 2)
        = crunch.GetArmyBudgetSingleValue('NO_NWO_Endstrength', 'NGPA', 'Avg', @AmcosVersionId),
            @NO_NWO_DHDG NUMERIC(20, 2) = crunch.GetArmyBudgetSingleValue('NO_NWO_DHDG', 'NGPA', 'Avg', @AmcosVersionId);
    DECLARE @AMT_NO_NWO_DHDG NUMERIC(20, 2) = @NO_NWO_DHDG / @NO_NWO_Endstrength,
            @CE_NO_DHDG INT = 399,
            @CE_NWO_DHDG INT = 439;


    -- RE Educational Benefits (GI Bill)
    DECLARE @RE_Basic_Benefit NUMERIC(20, 2)
        = crunch.GetArmyBudgetSingleValue('RE_Basic_Benefit', 'RPA', 'Avg', @AmcosVersionId),
            @RE_Kicker NUMERIC(20, 2) = crunch.GetArmyBudgetSingleValue('RE_Edu_Kicker', 'RPA', 'Avg', @AmcosVersionId);
    DECLARE @Amt_RE_EduBen NUMERIC(20, 2) = (@RE_Basic_Benefit + @RE_Kicker) /
                                            (
                                                SELECT SUM(Inventory)FROM #Inventory WHERE PayPlan = 'RE'
                                            ),
            @CE_RE_Educ_Benefits INT = 492;

    -- NE Educational Benefits (GI Bill)
    DECLARE @NE_Basic_Benefit NUMERIC(20, 2)
        = crunch.GetArmyBudgetSingleValue('NE_Basic_Benefit', 'NGPA', 'Avg', @AmcosVersionId),
            @NE_Kicker NUMERIC(20, 2) = crunch.GetArmyBudgetSingleValue('NE_Edu_Kicker', 'NGPA', 'Avg', @AmcosVersionId);
    DECLARE @Amt_NE_EduBen NUMERIC(20, 2) = (@NE_Basic_Benefit + @NE_Kicker) /
                                            (
                                                SELECT SUM(Inventory)FROM #Inventory WHERE PayPlan = 'NE'
                                            ),
            @CE_NE_Educ_Benefits INT = 328;

    --NE Student Loan Repayment Program (SLRP)
    DECLARE @NEStudentLoanRepayment NUMERIC(20, 2)
        = crunch.GetArmyBudgetSingleValue('NE_Student_Loan_Repayment', 'NGPA', 'Avg', @AmcosVersionId);
    DECLARE @Amt_NE_SLRP NUMERIC(20, 2) = @NEStudentLoanRepayment /
                                          (
                                              SELECT SUM(Inventory)FROM #Inventory WHERE PayPlan = 'NE'
                                          ),
            @CE_NE_SLRP INT = 329;

    --RE Student Loan Repayment Program (SLRP)
    DECLARE @REStudentLoanRepayment NUMERIC(20, 2)
        = crunch.GetArmyBudgetSingleValue('RE_Student_Loan_Repayment', 'RPA', 'Avg', @AmcosVersionId);
    DECLARE @Amt_RE_SLRP NUMERIC(20, 2) = @NEStudentLoanRepayment /
                                          (
                                              SELECT SUM(Inventory)FROM #Inventory WHERE PayPlan = 'RE'
                                          ),
            @CE_RE_SLRP INT = 493;





    --show calculations up to this point if debug mode is on
    IF @Debug = 1
    BEGIN
        SELECT '--Active CEs--';
        SELECT 'MERHC: ' + FORMAT(ISNULL(@Amt_Active_MERHC, 0), 'C', 'en-us');
        SELECT 'Morale Welfare and Recreation: ' + FORMAT(ISNULL(@Amt_Active_MWR, 0), 'C', 'en-us');
        SELECT 'Active Medical Costs: ' + FORMAT(ISNULL(@Amt_Active_medical, 0), 'C', 'en-us');

        SELECT 'Discount Groceries: ' + FORMAT(ISNULL(@Amt_Active_Groceries, 0), 'C', 'en-us');
        SELECT 'DoDEA: ' + FORMAT(ISNULL(@Amt_Active_DoDEA, 0), 'C', 'en-us');

        SELECT 'Child Education: ' + FORMAT(ISNULL(@Amt_Active_ChildEdu, 0), 'C', 'en-us');
        SELECT 'Treasury Concurrent Receipts: ' + FORMAT(ISNULL(@Amt_Active_ConcurRec, 0), 'C', 'en-us');
        SELECT 'Treasury MERHCF: ' + FORMAT(ISNULL(@Amt_Active_Treas_MERHCF, 0), 'C', 'en-us');
        SELECT 'Veteran Benefits: ' + FORMAT(ISNULL(@Amt_Active_Veteran, 0), 'C', 'en-us');
        SELECT '--NG/R CEs--';
        SELECT 'DHDG RE' + FORMAT(ISNULL(@Amt_RE_DHDG, 0), 'C', 'en-us');
        SELECT 'DHDG NE' + FORMAT(ISNULL(@Amt_NE_DHDG, 0), 'C', 'en-us');
        SELECT 'DHDG RO_RWO ' + FORMAT(ISNULL(@Amt_RO_RWO_DHDG, 0), 'C', 'en-us');
        SELECT 'DHDG NO_NWO ' + FORMAT(ISNULL(@AMT_NO_NWO_DHDG, 0), 'C', 'en-us');
        SELECT 'Edu Benefits RE ' + FORMAT(ISNULL(@Amt_RE_EduBen, 0), 'C', 'en-us');
        SELECT 'Edu Benefits NE ' + FORMAT(ISNULL(@Amt_RE_EduBen, 0), 'C', 'en-us');
        SELECT 'SLRP RE ' + FORMAT(ISNULL(@Amt_RE_SLRP, 0), 'C', 'en-us');
        SELECT 'SLRP NE ' + FORMAT(ISNULL(@Amt_NE_SLRP, 0), 'C', 'en-us');

    END;
    IF @Debug = 0
    BEGIN
        /* clear out the existing cost table for all the CE IDs we are about to insert values for */
        DELETE FROM crunch.Costs_AE
        WHERE CostElementId IN ( @CE_AE_ChildEdu, @CE_AE_ConcurRec, @CE_AE_DoDEA, @CE_AE_Groceries, @CE_AE_Medical,
                                 @CE_AE_MERHC, @CE_AE_MWR, @CE_AE_Treas_MERHCF, @CE_AE_Veteran
                               )
              AND AmcosVersionId = @AmcosVersionId;

        DELETE FROM crunch.Costs_AO
        WHERE CostElementId IN ( @CE_AO_ChildEdu, @CE_AO_ConcurRec, @CE_AO_DoDEA, @CE_AO_Groceries, @CE_AO_Medical,
                                 @CE_AO_MerHC, @CE_AO_MWR, @CE_AO_Treas_MERHCF, @CE_AO_Veteran
                               )
              AND AmcosVersionId = @AmcosVersionId;

        DELETE FROM crunch.Costs_AWO
        WHERE CostElementId IN ( @CE_AWO_ChildEdu, @CE_AWO_ConcurRec, @CE_AWO_DoDEA, @CE_AWO_Groceries,
                                 @CE_AWO_medical, @CE_AWO_MERHC, @CE_AWO_MWR, @CE_AWO_Treas_MERHCF, @CE_AWO_Veteran
                               )
              AND AmcosVersionId = @AmcosVersionId;


        DELETE FROM crunch.Costs_NE
        WHERE CostElementId IN ( @CE_NE_Health, @CE_NE_DHDG, @CE_NE_Educ_Benefits, @CE_NE_SLRP )
              AND AmcosVersionId = @AmcosVersionId;

        DELETE FROM crunch.Costs_RE
        WHERE CostElementId IN ( @CE_RE_Health, @CE_RE_DHDG, @CE_RE_Educ_Benefits, @CE_RE_SLRP )
              AND AmcosVersionId = @AmcosVersionId;


        DELETE FROM crunch.Costs_NO
        WHERE CostElementId IN ( @CE_NO_Health, @CE_NO_DHDG )
              AND AmcosVersionId = @AmcosVersionId;

        DELETE FROM crunch.Costs_RO
        WHERE CostElementId IN ( @CE_RO_Health, @CE_RO_DHDG )
              AND AmcosVersionId = @AmcosVersionId;

        DELETE FROM crunch.Costs_NWO
        WHERE CostElementId IN ( @CE_NWO_Health, @CE_NWO_DHDG )
              AND AmcosVersionId = @AmcosVersionId;

        DELETE FROM crunch.Costs_RWO
        WHERE CostElementId IN ( @CE_RWO_Health, @CE_RWO_DHDG )
              AND AmcosVersionId = @AmcosVersionId;

        /* Insert average cost elements, note we calculate at the Single Value level but we need costs at the subgroup level
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
        SELECT PayPlan,
               CategoryGroupCode,
               CategorySubgroupCode,
               @CE_AE_MERHC,
               GradeType,
               GradeLevel,
               -1,
               @Amt_Active_MERHC,
               @CrunchTime,
               @AmcosVersionId,
               -1
        FROM #Inventory
        WHERE PayPlan = 'AE'
        UNION
        SELECT PayPlan,
               CategoryGroupCode,
               CategorySubgroupCode,
               @CE_AE_MWR,
               GradeType,
               GradeLevel,
               -1,
               @Amt_Active_MWR,
               @CrunchTime,
               @AmcosVersionId,
               -1
        FROM #Inventory
        WHERE PayPlan = 'AE'
        UNION
        SELECT PayPlan,
               CategoryGroupCode,
               CategorySubgroupCode,
               @CE_AE_Medical,
               GradeType,
               GradeLevel,
               -1,
               @Amt_Active_medical,
               @CrunchTime,
               @AmcosVersionId,
               -1
        FROM #Inventory
        WHERE PayPlan = 'AE'
        UNION
        SELECT PayPlan,
               CategoryGroupCode,
               CategorySubgroupCode,
               @CE_AE_Groceries,
               GradeType,
               GradeLevel,
               -1,
               @Amt_Active_Groceries,
               @CrunchTime,
               @AmcosVersionId,
               -1
        FROM #Inventory
        WHERE PayPlan = 'AE'
        UNION
        SELECT PayPlan,
               CategoryGroupCode,
               CategorySubgroupCode,
               @CE_AE_DoDEA,
               GradeType,
               GradeLevel,
               -1,
               @Amt_Active_DoDEA,
               @CrunchTime,
               @AmcosVersionId,
               -1
        FROM #Inventory
        WHERE PayPlan = 'AE'
        UNION
        SELECT PayPlan,
               CategoryGroupCode,
               CategorySubgroupCode,
               @CE_AE_ChildEdu,
               GradeType,
               GradeLevel,
               -1,
               @Amt_Active_ChildEdu,
               @CrunchTime,
               @AmcosVersionId,
               -1
        FROM #Inventory
        WHERE PayPlan = 'AE'
        UNION
        SELECT PayPlan,
               CategoryGroupCode,
               CategorySubgroupCode,
               @CE_AE_ConcurRec,
               GradeType,
               GradeLevel,
               -1,
               @Amt_Active_ConcurRec,
               @CrunchTime,
               @AmcosVersionId,
               -1
        FROM #Inventory
        WHERE PayPlan = 'AE'
        UNION
        SELECT PayPlan,
               CategoryGroupCode,
               CategorySubgroupCode,
               @CE_AE_Treas_MERHCF,
               GradeType,
               GradeLevel,
               -1,
               @Amt_Active_Treas_MERHCF,
               @CrunchTime,
               @AmcosVersionId,
               -1
        FROM #Inventory
        WHERE PayPlan = 'AE'
        UNION
        SELECT PayPlan,
               CategoryGroupCode,
               CategorySubgroupCode,
               @CE_AE_Veteran,
               GradeType,
               GradeLevel,
               -1,
               @Amt_Active_Veteran,
               @CrunchTime,
               @AmcosVersionId,
               -1
        FROM #Inventory
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
        SELECT PayPlan,
               CategoryGroupCode,
               CategorySubgroupCode,
               @CE_AO_MerHC,
               GradeType,
               GradeLevel,
               -1,
               @Amt_Active_MERHC,
               @CrunchTime,
               @AmcosVersionId,
               -1
        FROM #Inventory
        WHERE PayPlan = 'AO'
        UNION
        SELECT PayPlan,
               CategoryGroupCode,
               CategorySubgroupCode,
               @CE_AO_MWR,
               GradeType,
               GradeLevel,
               -1,
               @Amt_Active_MWR,
               @CrunchTime,
               @AmcosVersionId,
               -1
        FROM #Inventory
        WHERE PayPlan = 'AO'
        UNION
        SELECT PayPlan,
               CategoryGroupCode,
               CategorySubgroupCode,
               @CE_AO_Medical,
               GradeType,
               GradeLevel,
               -1,
               @Amt_Active_medical,
               @CrunchTime,
               @AmcosVersionId,
               -1
        FROM #Inventory
        WHERE PayPlan = 'AO'
        UNION
        SELECT PayPlan,
               CategoryGroupCode,
               CategorySubgroupCode,
               @CE_AO_Groceries,
               GradeType,
               GradeLevel,
               -1,
               @Amt_Active_Groceries,
               @CrunchTime,
               @AmcosVersionId,
               -1
        FROM #Inventory
        WHERE PayPlan = 'AO'
        UNION
        SELECT PayPlan,
               CategoryGroupCode,
               CategorySubgroupCode,
               @CE_AO_DoDEA,
               GradeType,
               GradeLevel,
               -1,
               @Amt_Active_DoDEA,
               @CrunchTime,
               @AmcosVersionId,
               -1
        FROM #Inventory
        WHERE PayPlan = 'AO'
        UNION
        SELECT PayPlan,
               CategoryGroupCode,
               CategorySubgroupCode,
               @CE_AO_ChildEdu,
               GradeType,
               GradeLevel,
               -1,
               @Amt_Active_ChildEdu,
               @CrunchTime,
               @AmcosVersionId,
               -1
        FROM #Inventory
        WHERE PayPlan = 'AO'
        UNION
        SELECT PayPlan,
               CategoryGroupCode,
               CategorySubgroupCode,
               @CE_AO_ConcurRec,
               GradeType,
               GradeLevel,
               -1,
               @Amt_Active_ConcurRec,
               @CrunchTime,
               @AmcosVersionId,
               -1
        FROM #Inventory
        WHERE PayPlan = 'AO'
        UNION
        SELECT PayPlan,
               CategoryGroupCode,
               CategorySubgroupCode,
               @CE_AO_Treas_MERHCF,
               GradeType,
               GradeLevel,
               -1,
               @Amt_Active_Treas_MERHCF,
               @CrunchTime,
               @AmcosVersionId,
               -1
        FROM #Inventory
        WHERE PayPlan = 'AO'
        UNION
        SELECT PayPlan,
               CategoryGroupCode,
               CategorySubgroupCode,
               @CE_AO_Veteran,
               GradeType,
               GradeLevel,
               -1,
               @Amt_Active_Veteran,
               @CrunchTime,
               @AmcosVersionId,
               -1
        FROM #Inventory
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
        SELECT PayPlan,
               CategoryGroupCode,
               CategorySubgroupCode,
               @CE_AWO_MERHC,
               GradeType,
               GradeLevel,
               -1,
               @Amt_Active_MERHC,
               @CrunchTime,
               @AmcosVersionId,
               -1
        FROM #Inventory
        WHERE PayPlan = 'AWO'
        UNION
        SELECT PayPlan,
               CategoryGroupCode,
               CategorySubgroupCode,
               @CE_AWO_MWR,
               GradeType,
               GradeLevel,
               -1,
               @Amt_Active_MWR,
               @CrunchTime,
               @AmcosVersionId,
               -1
        FROM #Inventory
        WHERE PayPlan = 'AWO'
        UNION
        SELECT PayPlan,
               CategoryGroupCode,
               CategorySubgroupCode,
               @CE_AWO_medical,
               GradeType,
               GradeLevel,
               -1,
               @Amt_Active_medical,
               @CrunchTime,
               @AmcosVersionId,
               -1
        FROM #Inventory
        WHERE PayPlan = 'AWO'
        UNION
        SELECT PayPlan,
               CategoryGroupCode,
               CategorySubgroupCode,
               @CE_AWO_Groceries,
               GradeType,
               GradeLevel,
               -1,
               @Amt_Active_Groceries,
               @CrunchTime,
               @AmcosVersionId,
               -1
        FROM #Inventory
        WHERE PayPlan = 'AWO'
        UNION
        SELECT PayPlan,
               CategoryGroupCode,
               CategorySubgroupCode,
               @CE_AWO_DoDEA,
               GradeType,
               GradeLevel,
               -1,
               @Amt_Active_DoDEA,
               @CrunchTime,
               @AmcosVersionId,
               -1
        FROM #Inventory
        WHERE PayPlan = 'AWO'
        UNION
        SELECT PayPlan,
               CategoryGroupCode,
               CategorySubgroupCode,
               @CE_AWO_ChildEdu,
               GradeType,
               GradeLevel,
               -1,
               @Amt_Active_ChildEdu,
               @CrunchTime,
               @AmcosVersionId,
               -1
        FROM #Inventory
        WHERE PayPlan = 'AWO'
        UNION
        SELECT PayPlan,
               CategoryGroupCode,
               CategorySubgroupCode,
               @CE_AWO_ConcurRec,
               GradeType,
               GradeLevel,
               -1,
               @Amt_Active_ConcurRec,
               @CrunchTime,
               @AmcosVersionId,
               -1
        FROM #Inventory
        WHERE PayPlan = 'AWO'
        UNION
        SELECT PayPlan,
               CategoryGroupCode,
               CategorySubgroupCode,
               @CE_AWO_Treas_MERHCF,
               GradeType,
               GradeLevel,
               -1,
               @Amt_Active_Treas_MERHCF,
               @CrunchTime,
               @AmcosVersionId,
               -1
        FROM #Inventory
        WHERE PayPlan = 'AWO'
        UNION
        SELECT PayPlan,
               CategoryGroupCode,
               CategorySubgroupCode,
               @CE_AWO_Veteran,
               GradeType,
               GradeLevel,
               -1,
               @Amt_Active_Veteran,
               @CrunchTime,
               @AmcosVersionId,
               -1
        FROM #Inventory
        WHERE PayPlan = 'AWO';


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
        SELECT PayPlan,
               CategoryGroupCode,
               CategorySubgroupCode,
               @CE_NE_Health,
               GradeType,
               GradeLevel,
               -1,
               @Amt_NG_R_Health,
               @CrunchTime,
               @AmcosVersionId
        FROM #Inventory
        WHERE PayPlan = 'NE'
        UNION
        SELECT PayPlan,
               CategoryGroupCode,
               CategorySubgroupCode,
               @CE_NE_DHDG,
               GradeType,
               GradeLevel,
               -1,
               @Amt_NE_DHDG,
               @CrunchTime,
               @AmcosVersionId
        FROM #Inventory
        WHERE PayPlan = 'NE'
        UNION
        SELECT PayPlan,
               CategoryGroupCode,
               CategorySubgroupCode,
               @CE_NE_Educ_Benefits,
               GradeType,
               GradeLevel,
               -1,
               @Amt_NE_EduBen,
               @CrunchTime,
               @AmcosVersionId
        FROM #Inventory
        WHERE PayPlan = 'NE'
        UNION
        SELECT PayPlan,
               CategoryGroupCode,
               CategorySubgroupCode,
               @CE_NE_SLRP,
               GradeType,
               GradeLevel,
               -1,
               @Amt_NE_SLRP,
               @CrunchTime,
               @AmcosVersionId
        FROM #Inventory
        WHERE PayPlan = 'NE';


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
        SELECT PayPlan,
               CategoryGroupCode,
               CategorySubgroupCode,
               @CE_RE_Health,
               GradeType,
               GradeLevel,
               -1,
               @Amt_NG_R_Health,
               @CrunchTime,
               @AmcosVersionId
        FROM #Inventory
        WHERE PayPlan = 'RE'
        UNION
        SELECT PayPlan,
               CategoryGroupCode,
               CategorySubgroupCode,
               @CE_RE_DHDG,
               GradeType,
               GradeLevel,
               -1,
               @Amt_RE_DHDG,
               @CrunchTime,
               @AmcosVersionId
        FROM #Inventory
        WHERE PayPlan = 'RE'
        UNION
        SELECT PayPlan,
               CategoryGroupCode,
               CategorySubgroupCode,
               @CE_RE_Educ_Benefits,
               GradeType,
               GradeLevel,
               -1,
               @Amt_RE_EduBen,
               @CrunchTime,
               @AmcosVersionId
        FROM #Inventory
        WHERE PayPlan = 'RE'
        UNION
        SELECT PayPlan,
               CategoryGroupCode,
               CategorySubgroupCode,
               @CE_RE_SLRP,
               GradeType,
               GradeLevel,
               -1,
               @Amt_RE_SLRP,
               @CrunchTime,
               @AmcosVersionId
        FROM #Inventory
        WHERE PayPlan = 'RE';


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
        SELECT PayPlan,
               CategoryGroupCode,
               CategorySubgroupCode,
               @CE_NO_Health,
               GradeType,
               GradeLevel,
               -1,
               @Amt_NG_R_Health,
               @CrunchTime,
               @AmcosVersionId
        FROM #Inventory
        WHERE PayPlan = 'NO'
        UNION
        SELECT PayPlan,
               CategoryGroupCode,
               CategorySubgroupCode,
               @CE_NO_DHDG,
               GradeType,
               GradeLevel,
               -1,
               @AMT_NO_NWO_DHDG,
               @CrunchTime,
               @AmcosVersionId
        FROM #Inventory
        WHERE PayPlan = 'NO';


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
        SELECT PayPlan,
               CategoryGroupCode,
               CategorySubgroupCode,
               @CE_RO_Health,
               GradeType,
               GradeLevel,
               -1,
               @Amt_NG_R_Health,
               @CrunchTime,
               @AmcosVersionId
        FROM #Inventory
        WHERE PayPlan = 'RO'
        UNION
        SELECT PayPlan,
               CategoryGroupCode,
               CategorySubgroupCode,
               @CE_RO_DHDG,
               GradeType,
               GradeLevel,
               -1,
               @Amt_RO_RWO_DHDG,
               @CrunchTime,
               @AmcosVersionId
        FROM #Inventory
        WHERE PayPlan = 'RO';


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
        SELECT PayPlan,
               CategoryGroupCode,
               CategorySubgroupCode,
               @CE_NWO_Health,
               GradeType,
               GradeLevel,
               -1,
               @Amt_NG_R_Health,
               @CrunchTime,
               @AmcosVersionId
        FROM #Inventory
        WHERE PayPlan = 'NWO'
        UNION
        SELECT PayPlan,
               CategoryGroupCode,
               CategorySubgroupCode,
               @CE_NWO_DHDG,
               GradeType,
               GradeLevel,
               -1,
               @AMT_NO_NWO_DHDG,
               @CrunchTime,
               @AmcosVersionId
        FROM #Inventory
        WHERE PayPlan = 'NWO';


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
        SELECT PayPlan,
               CategoryGroupCode,
               CategorySubgroupCode,
               @CE_RWO_Health,
               GradeType,
               GradeLevel,
               -1,
               @Amt_NG_R_Health,
               @CrunchTime,
               @AmcosVersionId
        FROM #Inventory
        WHERE PayPlan = 'RWO'
        UNION
        SELECT PayPlan,
               CategoryGroupCode,
               CategorySubgroupCode,
               @CE_RWO_DHDG,
               GradeType,
               GradeLevel,
               -1,
               @Amt_RO_RWO_DHDG,
               @CrunchTime,
               @AmcosVersionId
        FROM #Inventory
        WHERE PayPlan = 'RWO';



    END;
END;