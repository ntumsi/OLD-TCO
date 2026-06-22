-- Stored Procedure

-- =============================================
-- Author:Dan Hogan
-- Create date: 10/12/2018
-- Last updated: 
-- Description:	Sandbox version of the process to update Officer Acquisition cost calculations and remove amortization
-- Per 10/2018 meeting with Mr Barth the intent of Ofc Acq should be to evenly spread costs across all Grade levels
-- this is so that say O1 doesn't look more expensive then O2 or O3.  This approach favors consistency
-- across AMCOS releases inst
-- Dependencies: 
--	  lookup.SingleValues - JBook data 
--    MilitaryAcqSOC_Transaction - new acqs by MOS/AOC (note we only use it at the PayPlan level)
--    
-- =============================================
CREATE PROCEDURE [crunch].[CostOfOfficerAcquisition]
    @AmcosVersionId INT = -1,
    @CrunchTime AS SMALLDATETIME = NULL,
    @Debug AS BIT = 0
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @IsValidAmcosVersion BIT = crunch.ValidateAmcosVersion(@AmcosVersionId);

    IF (@IsValidAmcosVersion = 0)
        RETURN 0;

    IF (@CrunchTime IS NULL)
        SET @CrunchTime = CONVERT(SMALLDATETIME, GETDATE());

    --to see all of the intermediate calculations/tables set this variable to 1, otherwise set it to 0

    --drop our temp tables in case there weren't dropped in a previous run on this script
    DROP TABLE IF EXISTS crunch.TempAcq_Calc;
    TRUNCATE TABLE crunch_temp.SOCTransactionGL; -- BY Grade level
    TRUNCATE TABLE crunch_temp.SOCTransaction; --aggregated without Grade level

    --pull data from the transaction file into a temp table
    --the DMDC transaction file shows Army gains by Source of Commission
    --note that the lookup for Acq Transaction types determines which transactions
    --are included/excluded in this process
    --included transactions are gains only new to the force, not from another services or prior service

    INSERT INTO crunch_temp.SOCTransactionGL
    (
        PayPlan,
        Grade,
        GradeLevel,
        SOC,
        SOC_Name,
        Total
    )
    SELECT a.PayPlan,
           a.Grade,
           CAST(GradeLevel AS INT) AS GradeLevel,
           a.SourceOfCommission AS SOC,
           b.Description AS SOC_Name,
           a.Total
    FROM
    (
        --to get the DMDC file into a format like the inventory table we do some manipulation
        SELECT a.Component,
               REPLACE(CONCAT(LEFT(a.Component, 1), LEFT(a.PayGrade, 1)), 'W', 'WO') AS PayPlan,
               a.PayGrade,
               LEFT(a.PayGrade, 1) AS Grade,
               (RIGHT(a.PayGrade, 2)) AS GradeLevel,
               a.SourceOfCommission,
               SUM(Total) AS Total
        FROM DMDC.MilitaryAcqSourceOfCommission AS a
            LEFT JOIN lookup.MilitaryAcqTransaction AS b
                ON a.TransactionTypeCode = b.Code
        --remove those transaction codes which we not 'NEW' to the force
        WHERE b.Include_Exclude = 'Include'
              AND a.AmcosVersionId = @AmcosVersionId
              AND (@AmcosVersionId
              BETWEEN b.AmcosVersionIdStart AND b.AmcosVersionIdEnd
                  )
        GROUP BY a.Component,
                 a.PayGrade,
                 a.SourceOfCommission
    ) AS a
        INNER JOIN lookup.MilitarySOC AS b
            ON a.SourceOfCommission = b.Code
               AND (@AmcosVersionId
               BETWEEN b.AmcosVersionIdStart AND b.AmcosVersionIdEnd
                   )
    WHERE a.PayPlan IN ( 'AO', 'NO', 'RO' ); --we don't compute acq costs for warrants per Marsha, warrant acq costs come in for training through WOCS
                                             --note that we can have some Grade levels greater than 1 based on what the DMDC data says


    DECLARE @int AS INT = 0;

    INSERT INTO crunch_temp.SOCTransaction
    (
        PayPlan,
        Grade,
        SOC,
        SOC_Name,
        number,
        mypercent,
        MPA_cost,
        OMA_cost,
        PP_inventory,
        avg_MPA,
        avg_oma
    )
    SELECT PayPlan,
           Grade,
           SOC,
           SOC_Name,
           SUM(Total) AS number,
           0.0 AS mypercent,
           0.0 AS MPA_cost,
           0.0 AS OMA_cost,
           @int AS PP_inventory,
           0.0 AS avg_MPA,
           0.0 AS avg_oma
    FROM crunch_temp.SOCTransactionGL
    GROUP BY PayPlan,
             Grade,
             SOC,
             SOC_Name;

    --calculate the PayPlan's percent of the SOC Total
    --we'll need this later to divy out some costs
    UPDATE crunch_temp.SOCTransaction
    SET mypercent = b.calc_perc
    FROM crunch_temp.SOCTransaction AS a
        INNER JOIN
        (
            SELECT *,
                   (number) / SUM(number) OVER (PARTITION BY SOC_Name) AS calc_perc
            FROM crunch_temp.SOCTransaction
        ) AS b
            ON a.PayPlan = b.PayPlan
               AND a.Grade = b.Grade
               AND a.SOC = b.SOC;



    -- =============================================
    --Compute the Contribution of Active Accession move costs
    -- =============================================

    --an accession move cost is considered part of the acq cost for MPA
    DECLARE @Accession_Cost_3yr_avg AS NUMERIC(18, 2)
        = crunch.GetArmyBudgetSingleValue('Accession_Travel_Officer', 'MPA', 'Avg', @AmcosVersionId);
    DECLARE @Inv_AOs AS NUMERIC(18, 2);
    DECLARE @Accession_cost_per_Officer AS NUMERIC(18, 2);

    SET @Inv_AOs =
    (
        SELECT SUM(Inventory)FROM data.Inventory WHERE PayPlan IN ( 'AO', 'AWO' ) and amcosversionid = @AmcosVersionid
    );
    --it is believed that even though this is an MPA cost, reserve officers benefit from it to since PCS doesn't
    --appear in the RPA or NGPA books
    SET @Accession_cost_per_Officer = @Accession_Cost_3yr_avg / @Inv_AOs;

    IF @Debug = 1
    BEGIN
        SELECT CONCAT('Accession Travel: 3 yr avg: ', FORMAT(@Accession_Cost_3yr_avg, 'C', 'en-us'));
        SELECT CONCAT('Number active W&Os ', @Inv_AOs);

        SELECT CONCAT('Accession Travel: Cost per officer all PPs  ', FORMAT(@Accession_cost_per_Officer, 'C', 'en-us'));

    END;

    -- =============================================
    --Compute the Contribution of Advertising 
    -- =============================================

    --The JBooks do not publish recruiting and advertising costs by SoC or by Grade type so we'll compute our own estimate
    DECLARE @Adv_OMA_3yr_Avg NUMERIC(18, 2)
        = crunch.GetArmyBudgetSingleValue('Advertising', 'OMA', 'Avg', @AmcosVersionId);

    DECLARE @Inv_OWs NUMERIC(18, 2);
    DECLARE @Inv_Total NUMERIC(18, 2);
    DECLARE @Adv_OMA_OW_Estimate NUMERIC(18, 2);
    DECLARE @Adv_OMA_OW_Per_soldier NUMERIC(18, 2);

    --get the inventory so we can make a ratio and divvy out R&A costs to officers, there's no precise way to do this so we do a simple ratio of Total inventory
    -- we assume that theR&A budget benefits the entire force (all 3 components) even though it is an MPA line item
    SET @Inv_OWs =
    (
        SELECT SUM(Inventory)
        FROM data.Inventory
        WHERE PayPlan IN ( 'AO', 'RO', 'NO', 'RWO', 'AWO', 'NWO' )
		AND AmcosVersionId = @AmcosVersionId
    );
    SET @Inv_Total =
    (
        SELECT SUM(Inventory)FROM data.Inventory
		WHERE AmcosVersionId = @AmcosVersionId
    );

    SET @Adv_OMA_OW_Estimate = (@Inv_OWs / @Inv_Total) * @Adv_OMA_3yr_Avg;
    SET @Adv_OMA_OW_Per_soldier = @Adv_OMA_OW_Estimate / @Inv_OWs;



    IF @Debug = 1
    BEGIN
        SELECT CONCAT('Advertising 3 yr avg: ', FORMAT(@Adv_OMA_3yr_Avg, 'C', 'en-us'));
        SELECT CONCAT('Advertising officer/warrant estimate of 3 yr avg ', FORMAT(@Adv_OMA_OW_Estimate, 'C', 'en-us'));
        SELECT CONCAT('Advertising cost per officer/warrant  ', FORMAT(@Adv_OMA_OW_Per_soldier, 'C', 'en-us'));
    END;

    -- =============================================
    --Compute the Contribution of Army Reserve Recruiting
    -- =============================================



    --####### RPA Non-Full Time reservists (e.g. short tours of duty to support recruiting mission) #######

    DECLARE @Recruiting_RPA_Non_FT_3yr_avg NUMERIC(18, 2)
        = crunch.GetArmyBudgetSingleValue('Recruiting', 'RPA', 'avg', @AmcosVersionId);
    DECLARE @Recruiting_RPA_Non_FT_E_Per_soldier NUMERIC(18, 2);

    DECLARE @Inv_R_Os NUMERIC(18, 2);
    SET @Inv_R_Os =
    (
        SELECT SUM(Inventory)FROM data.Inventory WHERE PayPlan IN ( 'RO' ) AND AmcosVersionId = @AmcosVersionId
    );
    DECLARE @Inv_R NUMERIC(18, 2);
    SET @Inv_R =
    (
        SELECT SUM(Inventory)
        FROM data.Inventory
        WHERE PayPlan IN ( 'RO', 'RWO', 'RE' )
		AND AmcosVersionId = @AmcosVersionId
    );
    --compute the officer percentage of this cost, the recruiting CE will pick up the rest
    SET @Recruiting_RPA_Non_FT_E_Per_soldier = @Recruiting_RPA_Non_FT_3yr_avg * (@Inv_R_Os / @Inv_R) / @Inv_R_Os;



    IF @Debug = 1
    BEGIN
        SELECT CONCAT('RPA Reserve Non-FT Recruiting 3yr avg: ', FORMAT(@Recruiting_RPA_Non_FT_3yr_avg, 'C', 'en-us'));
        SELECT CONCAT(
                         'RPA Recruiting Non-FT Recruiting cost per RE ',
                         FORMAT(@Recruiting_RPA_Non_FT_E_Per_soldier, 'C', 'en-us')
                     );
    END;

    -- =============================================
    --Compute the Contribution of National Guard  Recruiting
    -- =============================================

    --####### NGPA Non-Full Time reservists (e.g. short tours of duty to support recruiting mission) #######

    DECLARE @Recruiting_NGPA_Non_FT_3yr_avg NUMERIC(18, 2)
        = crunch.GetArmyBudgetSingleValue('Recruiting_Retention', 'NGPA', 'avg', @AmcosVersionId);
    DECLARE @Recruiting_NGPA_Non_FT_E_Per_soldier NUMERIC(18, 2);

    DECLARE @Inv_NG_Os NUMERIC(18, 2);
    SET @Inv_NG_Os =
    (
        SELECT SUM(Inventory)FROM data.Inventory WHERE PayPlan IN ( 'NO' )
		AND AmcosVersionId = @AmcosVersionId
    );
    DECLARE @Inv_NG NUMERIC(18, 2);
    SET @Inv_NG =
    (
        SELECT SUM(Inventory)
        FROM data.Inventory
        WHERE PayPlan IN ( 'NO', 'NWO', 'NE' )
		AND AmcosVersionId = @AmcosVersionId
    );

    SET @Recruiting_NGPA_Non_FT_E_Per_soldier = @Recruiting_NGPA_Non_FT_3yr_avg * (@Inv_NG_Os / @Inv_NG) / @Inv_NG_Os;



    IF @Debug = 1
    BEGIN
        SELECT CONCAT('NGPA Non FT  Recruiting 3yr avg: ', FORMAT(@Recruiting_NGPA_Non_FT_3yr_avg, 'C', 'en-us'));
        SELECT CONCAT(
                         'NGPA Non FT Recruiting cost per NE ',
                         FORMAT(@Recruiting_NGPA_Non_FT_E_Per_soldier, 'C', 'en-us')
                     );

    END;

    -- =============================================
    --Compute the Average Cost of United States Military Academy
    -- =============================================

    --Get Single Values
    --Total annual costs by year
    DECLARE @USMA_MPA_est AS NUMERIC(18, 2) = crunch.GetArmyBudgetSingleValue('USMA', 'MPA', 'avg', @AmcosVersionId);
    DECLARE @USMA_OMA_est AS NUMERIC(18, 2) = crunch.GetArmyBudgetSingleValue('USMA', 'OMA', 'avg', @AmcosVersionId);

    --number of military personnel who support the school
    DECLARE @USMA_MPA_Officers INT = crunch.GetArmyBudgetSingleValue('Officer_USMA', 'MPA', 'avg', @AmcosVersionId);
    DECLARE @USMA_MPA_Enlisted INT = crunch.GetArmyBudgetSingleValue('Enlisted_USMA', 'MPA', 'avg', @AmcosVersionId);
    DECLARE @USMA_MPA_Warrant INT = crunch.GetArmyBudgetSingleValue('Warrant_USMA', 'MPA', 'avg', @AmcosVersionId);

    --pay for the above soldiers, we assume 
    DECLARE @E7_Composite_Standard NUMERIC(18, 2)
        = crunch.GetSingleValue('AA', 'E7_Composite_Standard_Rate', @AmcosVersionId);
    DECLARE @O5_Composite_Standard NUMERIC(18, 2)
        = crunch.GetSingleValue('AA', 'O5_Composite_Standard_Rate', @AmcosVersionId);
    DECLARE @W2_Composite_Standard NUMERIC(18, 2)
        = crunch.GetSingleValue('AA', 'W2_Composite_Standard_Rate', @AmcosVersionId);

    --compute MPA and OMA costs
    SET @USMA_MPA_est
        = @USMA_MPA_est + (@USMA_MPA_Officers * @O5_Composite_Standard) + (@USMA_MPA_Enlisted * @E7_Composite_Standard)
          + (@USMA_MPA_Warrant * @W2_Composite_Standard);

    UPDATE crunch_temp.SOCTransaction
    SET MPA_cost = @USMA_MPA_est * mypercent
    WHERE SOC = 'A';

    UPDATE crunch_temp.SOCTransaction
    SET OMA_cost = @USMA_OMA_est * mypercent
    WHERE SOC = 'A';


    IF @Debug = 1
    BEGIN
        SELECT CONCAT('USMA Avg Officers: ', @USMA_MPA_Officers);
        SELECT CONCAT('USMA Avg Enlisted: ', @USMA_MPA_Enlisted);
        SELECT CONCAT('USMA Avg Warrants: ', @USMA_MPA_Warrant);
        SELECT CONCAT('USMA MPA Est: ', FORMAT(@USMA_MPA_est, 'C', 'en-us'));
        SELECT CONCAT('USMA OMA : ', FORMAT(@USMA_OMA_est, 'C', 'en-us'));
    END;

    -- =============================================
    --Compute the Average Cost of Officer Candidate School
    -- =============================================

    --OCS per graduate Costs come directly from the TRADOC ATRM-159 report
    --NOTE!!!! - these OCS costs need to be EXCLUDED from the training calculation so we are not double counting
    -- 3 year averaging is not used for OCS
    DECLARE @OCS_MPA_ACPG NUMERIC(18, 2) = crunch.GetSingleValue('AO', 'OCS_MPA_Cost_Per_Grad', @AmcosVersionId);
    DECLARE @OCS_OMA_ACPG NUMERIC(18, 2) = crunch.GetSingleValue('AO', 'OCS_OMA_Cost_Per_Grad', @AmcosVersionId);

    UPDATE crunch_temp.SOCTransaction
    SET MPA_cost = @OCS_MPA_ACPG * number
    WHERE SOC IN ( 'J', 'X', 'Z' );

    UPDATE crunch_temp.SOCTransaction
    SET OMA_cost = @OCS_OMA_ACPG * number
    WHERE SOC IN ( 'J', 'X', 'Z' );

    -- =============================================
    --Compute the Average Cost of National Guard state OCS
    -- =============================================


    --Get Single Values
    --Total Annual Program Cost (TAPC)
    DECLARE @NGOCS_MPA_3YR_Avg AS NUMERIC(18, 2)
        = crunch.GetArmyBudgetSingleValue('NGOCS', 'NGPA', 'avg', @AmcosVersionId);
    --OMNG JBook lumps OMA costs with other programs, assume the same ratio of OMA to (MPA + OMA) ACPG costs as Army OCS
    DECLARE @NGOCS_OMNG_3YR_Avg AS NUMERIC(18, 2)
        = crunch.GetArmyBudgetSingleValue('NGOCS', 'OMNG', 'avg', @AmcosVersionId);

    IF @Debug = 1
    BEGIN
        SELECT CONCAT('NGOCS MPA 3 yr avg: ', FORMAT(@NGOCS_MPA_3YR_Avg, 'C', 'en-us'));
        SELECT CONCAT('NGOCS OMA 3 year avg: ', FORMAT(@NGOCS_OMNG_3YR_Avg, 'C', 'en-us'));
    END;

    UPDATE crunch_temp.SOCTransaction
    SET MPA_cost = @NGOCS_MPA_3YR_Avg * mypercent
    WHERE SOC IN ( 'L' );

    UPDATE crunch_temp.SOCTransaction
    SET OMA_cost = @NGOCS_OMNG_3YR_Avg * mypercent
    WHERE SOC IN ( 'L' );


    -- =============================================
    --Compute the Average cost of Aviation training program other than OCS, AOCS, OTS, or PLC
    -- =============================================
    --SOC=P
    --There should be some costs for this I think but not sure where the program costs would come from
    --Don't see it mentioned in the JBooks or in the TRADOC 159 report



    -- =============================================
    --Compute the Average Cost of WOCS
    -- =============================================
    --Per meeting with Marsha on 5/23/2018, warrants will receive no commissioning costs, instead any costs to make them a warrant
    -- like WOCS will be burdened against the applicable WOMOSes in the training CEs
    --NOTE - if this is restored we then need to EXCLUDE the WOCS costs from the training data so we don't double count 


    -- =============================================
    --Compute the  Cost of ROTC Scholarship & Non-Scholarship Program
    -- =============================================
    -- Scholarship is SoC= G
    --Non-Scholarship is SoC = H
    --We calculate them both together because the JBook data combines both in some areas which we need to divvy out
    --Get Single Values
    --Total Annual Program Cost (TAPC)

    --Compute 3 year average costs
    DECLARE @ROTC_OMA_Scholarship_3yr_avg AS NUMERIC(18, 2)
        = crunch.GetArmyBudgetSingleValue('ROTC_Scholarship', 'OMA', 'avg', @AmcosVersionId);

    DECLARE @ROTC_OMA_3yr_avg AS NUMERIC(18, 2)
        = crunch.GetArmyBudgetSingleValue('ROTC', 'OMA', 'avg', @AmcosVersionId);


    --Compute the share of OMA costs for scholarship/nonscholarship
    --non sholarships share is half the cost of the OMA budget
    --scholarships share is half the cost of the OMA budget + the oma scholarship cost
    DECLARE @ROTC_OMA_Scholarship NUMERIC(18, 2);
    DECLARE @ROTC_OMA_Non_Scholarship NUMERIC(18, 2);
    SET @ROTC_OMA_Non_Scholarship = (@ROTC_OMA_3yr_avg) / 2;
    SET @ROTC_OMA_Scholarship = ((@ROTC_OMA_3yr_avg) / 2) + @ROTC_OMA_Scholarship_3yr_avg;

    DECLARE @ROTC_MPA_Non_Scholarship AS NUMERIC(18, 2)
        = crunch.GetArmyBudgetSingleValue('ROTC_NonScholarship', 'MPA', 'avg', @AmcosVersionId);
    DECLARE @ROTC_MPA_Scholarship AS NUMERIC(18, 2)
        = crunch.GetArmyBudgetSingleValue('ROTC_Scholarship', 'MPA', 'avg', @AmcosVersionId);


    --Total students for  scholarship
    DECLARE @ROTC_Scholarship_TNoS NUMERIC(18, 2)
        = crunch.GetSingleValue('MO', 'ROTC_Scholarship_TNoS', @AmcosVersionId);


    --Total students for non scholarship
    DECLARE @ROTC_Non_Scholarship_TNoS NUMERIC(18, 2)
        = crunch.GetSingleValue('MO', 'ROTC_Non_Scholarship_TNoS', @AmcosVersionId);


    --get the avg number of military support staff
    DECLARE @ROTC_Enlisted INT = crunch.GetArmyBudgetSingleValue('Enlisted_ROTC', 'MPA', 'avg', @AmcosVersionId);
    DECLARE @ROTC_Warrant INT = crunch.GetArmyBudgetSingleValue('Warrant_ROTC', 'MPA', 'avg', @AmcosVersionId);
    DECLARE @ROTC_Officer INT = crunch.GetArmyBudgetSingleValue('Officer_ROTC', 'MPA', 'avg', @AmcosVersionId);

    DECLARE @ROTC_Enlisted_Cost NUMERIC(18, 2) = @E7_Composite_Standard * @ROTC_Enlisted;
    DECLARE @rotc_Officer_cost NUMERIC(18, 2) = @O5_Composite_Standard * @ROTC_Officer;
    DECLARE @rotc_Warrant_Cost NUMERIC(18, 2) = @W2_Composite_Standard * @ROTC_Warrant;

    --set up a ratio to divvy out the cost for military personnel to each ROTC program
    DECLARE @ROTC_Scholarship_TNoS_Ratio NUMERIC(18, 2),
            @ROTC_Non_Scholarship_TNoS_Ratio NUMERIC(18, 2);

    SET @ROTC_Scholarship_TNoS_Ratio = @ROTC_Scholarship_TNoS / (@ROTC_Scholarship_TNoS + @ROTC_Non_Scholarship_TNoS);
    SET @ROTC_Non_Scholarship_TNoS_Ratio
        = @ROTC_Non_Scholarship_TNoS / (@ROTC_Scholarship_TNoS + @ROTC_Non_Scholarship_TNoS);

    --because the JBooks don't tell us how many soldiers by what Grade level work in the ROTC program and we don't know how many support scholarship vs non scholarship we use some ratio math and estimates to divvy out the costs
    SET @ROTC_MPA_Scholarship
        = @ROTC_MPA_Scholarship
          + (@ROTC_Scholarship_TNoS_Ratio * (@ROTC_Enlisted_Cost + @rotc_Officer_cost + @rotc_Warrant_Cost));

    SET @ROTC_MPA_Non_Scholarship
        = @ROTC_MPA_Non_Scholarship
          + (@ROTC_Non_Scholarship_TNoS_Ratio * (@ROTC_Enlisted_Cost + @rotc_Officer_cost + @rotc_Warrant_Cost));


    UPDATE crunch_temp.SOCTransaction
    SET MPA_cost = @ROTC_MPA_Scholarship * mypercent,
        OMA_cost = @ROTC_OMA_Scholarship * mypercent
    WHERE SOC IN ( 'G' );

    UPDATE crunch_temp.SOCTransaction
    SET MPA_cost = @ROTC_MPA_Non_Scholarship * mypercent,
        OMA_cost = @ROTC_OMA_Non_Scholarship * mypercent
    WHERE SOC IN ( 'H' );

    IF @Debug = 1
    BEGIN
        SELECT CONCAT('ROTC Scholarship MPA: ', FORMAT(@ROTC_MPA_Scholarship, 'C', 'en-us'));
        SELECT CONCAT('ROTC Scholarship OMA: ', FORMAT(@ROTC_OMA_Scholarship, 'C', 'en-us'));

        SELECT CONCAT('ROTC Non-Scholarship MPA  ', FORMAT(@ROTC_MPA_Non_Scholarship, 'C', 'en-us'));
        SELECT CONCAT('ROTC Non-Scholarship OMA  ', FORMAT(@ROTC_OMA_Non_Scholarship, 'C', 'en-us'));

    END;

    -- =============================================
    --Compute the Average cost of Direct Commissioning 
    -- =============================================

    --We have TRADOC class costs for DCOCS

    --DCOCS per graduate Costs come directly from the TRADOC ATRM-159 report
    DECLARE @DCOCS_MPA_ACPG NUMERIC(18, 2) = crunch.GetSingleValue('AO', 'DOCS_MPA_Cost_Per_Grad', @AmcosVersionId);
    DECLARE @DCOCS_OMA_ACPG NUMERIC(18, 2) = crunch.GetSingleValue('AO', 'DOCS_OMA_Cost_Per_Grad', @AmcosVersionId);

    UPDATE crunch_temp.SOCTransaction
    SET MPA_cost = @DCOCS_MPA_ACPG * number,
        OMA_cost = @DCOCS_OMA_ACPG * number
    WHERE SOC IN ( 'M', 'N' );


    UPDATE crunch_temp.SOCTransaction
    SET PP_inventory = b.inv
    FROM crunch_temp.SOCTransaction AS a
        INNER JOIN
        (
            SELECT PayPlan,
                   SUM(Inventory) AS inv
            FROM data.Inventory
            WHERE AmcosVersionId = @AmcosVersionId
            GROUP BY PayPlan
        ) AS b
            ON a.PayPlan = b.PayPlan;


    UPDATE crunch_temp.SOCTransaction
    SET avg_MPA = MPA_cost / PP_inventory,
        avg_oma = OMA_cost / PP_inventory;

    --aggregate the costs up to the pay plan level and then do the PayPlan averaging
    TRUNCATE TABLE crunch_temp.CostOfOfficerAcquisitionTotal;
    INSERT INTO crunch_temp.CostOfOfficerAcquisitionTotal
    (
        PayPlan,
        mpa,
        oma
    )
    SELECT PayPlan,
           SUM(avg_MPA) AS mpa,
           SUM(avg_oma) AS oma
    FROM crunch_temp.SOCTransaction
    GROUP BY PayPlan;



    TRUNCATE TABLE crunch_temp.CostOfOfficerAcquisitionByAoc;
    INSERT INTO crunch_temp.CostOfOfficerAcquisitionByAoc
    (
        PayPlan,
        CategoryGroupCode,
        CategorySubGroupCode,
        GradeType,
        GradeLevel,
        inv,
        CGLAInventory,
        ofc_acq_mpa,
        ofc_acq_oma,
        bonus_mpa,
        CGLA_bonus_mpa
    )
    SELECT PayPlan,
           CategoryGroupCode,
           CategorySubgroupCode,
           GradeType,
           GradeLevel,
           SUM(Inventory) AS inv,
           @int AS CGLAInventory, --this is all the inventory at and above the pp, GL, AOC for bonus amounts
           0.0 AS ofc_acq_mpa,
           0.0 AS ofc_acq_oma,
           0.0 AS bonus_mpa,
           0.0 AS CGLA_bonus_mpa
    FROM data.KnownInventory
    WHERE GradeType IN ( 'O', 'W' )
          AND AmcosVersionId = @AmcosVersionId
    GROUP BY PayPlan,
             CategoryGroupCode,
             CategorySubgroupCode,
             GradeType,
             GradeLevel;

    --compute my CGLA inventory
    --cgla is the cummulative inventory at or above any one PayPlan & subgroup combination
    --it is later used to average bonus costs across later grades
    UPDATE crunch_temp.CostOfOfficerAcquisitionByAoc
    SET CGLAInventory = b.rev_cumulative
    FROM crunch_temp.CostOfOfficerAcquisitionByAoc AS a
        INNER JOIN
        (
            --compute the reverse sum which wil later be used to do Cross Grade Level Allocation (CGLA)
            SELECT PayPlan,
                   CategorySubGroupCode,
                   GradeType,
                   GradeLevel,
                   inventory,
                   SUM(inventory) OVER (PARTITION BY PayPlan,
                                                     CategorySubGroupCode
                                        ORDER BY PayPlan,
                                                 CategorySubGroupCode,
                                                 GradeLevel DESC
                                       ) + crunch.GetParentInventory(PayPlan, CategorySubGroupCode, @AmcosVersionId) AS rev_cumulative
            FROM
            (
                SELECT PayPlan,
                       CategorySubgroupCode,
                       GradeType,
                       GradeLevel,
                       SUM(Inventory) AS inventory
                FROM data.KnownInventory
                WHERE AmcosVersionId = @AmcosVersionId
                GROUP BY PayPlan,
                         CategorySubgroupCode,
                         GradeType,
                         GradeLevel
            ) AS a
            WHERE GradeType IN ( 'O', 'W' )
            GROUP BY PayPlan,
                     CategorySubGroupCode,
                     GradeType,
                     GradeLevel,
                     inventory
        ) AS b
            ON a.PayPlan = b.PayPlan
               AND a.CategorySubGroupCode = b.CategorySubGroupCode
               AND a.GradeLevel = b.GradeLevel;

    --add in the R&A cost which applies to everyone
    UPDATE crunch_temp.CostOfOfficerAcquisitionByAoc
    SET ofc_acq_oma = @Adv_OMA_OW_Per_soldier;

    --add in the accession move cost
    UPDATE crunch_temp.CostOfOfficerAcquisitionByAoc
    SET ofc_acq_mpa = ofc_acq_mpa + @Accession_cost_per_Officer
    WHERE PayPlan IN ( 'AO', 'AWO' );

    --add in the Reserve Recruiting per soldier
    UPDATE crunch_temp.CostOfOfficerAcquisitionByAoc
    SET ofc_acq_mpa = ofc_acq_mpa + @Recruiting_RPA_Non_FT_E_Per_soldier
    WHERE PayPlan IN ( 'RO', 'RWO' );

    --add in the Reserve Recruiting per soldier
    UPDATE crunch_temp.CostOfOfficerAcquisitionByAoc
    SET ofc_acq_mpa = ofc_acq_mpa + @Recruiting_NGPA_Non_FT_E_Per_soldier
    WHERE PayPlan IN ( 'NO', 'NWO' );


    --add in the computed PayPlan averages
    UPDATE crunch_temp.CostOfOfficerAcquisitionByAoc
    SET ofc_acq_oma = a.ofc_acq_oma + b.oma,
        ofc_acq_mpa = a.ofc_acq_mpa + b.mpa
    FROM crunch_temp.CostOfOfficerAcquisitionByAoc AS a
        INNER JOIN crunch_temp.CostOfOfficerAcquisitionTotal AS b
            ON a.PayPlan = b.PayPlan;




    IF @Debug = 1
    BEGIN
        SELECT 'crunch_temp.SOCTransactionGL';
        SELECT PayPlan,
               Grade,
               GradeLevel,
               SOC,
               SOC_Name,
               Total
        FROM crunch_temp.SOCTransactionGL
        ORDER BY PayPlan,
                 Grade,
                 GradeLevel,
                 SOC;

        SELECT 'crunch_temp.SOCTransaction';
        SELECT PayPlan,
               Grade,
               SOC,
               SOC_Name,
               number,
               mypercent,
               MPA_cost,
               OMA_cost,
               PP_inventory,
               avg_MPA,
               avg_oma
        FROM crunch_temp.SOCTransaction
        ORDER BY SOC,
                 PayPlan;

        SELECT 'TempOfc_Acq_Total';
        SELECT PayPlan,
               mpa,
               oma
        FROM crunch_temp.CostOfOfficerAcquisitionTotal
        ORDER BY PayPlan; --, categorysubgroupcode, GradeLevel
    END;


    /*


-- =============================================
--Compute the Average Cost of WOCS
-- =============================================
--Per meeting with Marsha on 5/23/2018, warrants will receive no commissioning costs, instead any costs to make them a warrant
-- like WOCS will be burdened against the applicable WOMOSes in the training CEs



-- =============================================
--# The following Sources of Commission purposely have no costs
-- SoC = B, C, D, E, F -> these are other service programs and thus have no cost to the Army
-- SOC = K -> This is apparently a defunct training program (ended in the 60s) which was run by the AF
-- =============================================

*/
    -- =============================================
    --Compute the Average Cost of Officer Accessions Bonus which only applies to the reserve components
    -- =============================================


    TRUNCATE TABLE crunch_temp.DMDCBonus;
    INSERT INTO crunch_temp.DMDCBonus
    (
        PayType,
        PayPlan,
        CMF,
        subgrp,
        GradeType,
        GradeLevel,
        avg_cost,
        AmcosVersionId,
        avg_annual_pay,
        avg_annual_payments,
        pay_cap,
        capped_avg_mpa_pay
    )
    SELECT PayType,
           PayPlan,
           CategoryGroupCode,
           CategorySubgroupCode,
           GradeType,
           GradeLevel,
           avg_cost,
           AmcosVersionId,
           avg_annual_pay,
           avg_annual_payments,
           0.0 AS pay_cap,
           0.0 AS capped_avg_mpa_pay
    FROM crunch.PayProcessed
    WHERE AmcosVersionId = @AmcosVersionId
          --if there is no pay then don't worry about the row
          AND avg_cost > 0
          AND
          (
              PayType IN ( 'Sel Res Officer Accession Bonus', 'Sel Res Officer Affiliation Bonus' )
              AND PayPlan IN ( 'NO', 'RO', 'RWO', 'NWO' )
          );


    --FMR Volume 7A Chapter 56 sets a maximum limit on reserve accession or affiliation bonus in the selected reserve
    --note that there are several maximums based on number of years but the annual maximum is all we are concerned about
    DECLARE @RAcB_Annual_Max AS NUMERIC(18, 2)
        = crunch.GetSingleValue('RC', 'AccessionBonus_Annual_Max', @AmcosVersionId);

    --FMR Volume 7A Chapter 56 sets a maximum limit on reserve accession or affiliation bonus in the selected reserve
    --note that there are several maximums based on number of years but the annual maximum is all we are concerned about
    DECLARE @RAfB_Annual_Max AS NUMERIC(18, 2)
        = crunch.GetSingleValue('RC', 'AffiliationBonus_Annual_Max', @AmcosVersionId);

    --bring in pay caps for reserves
    UPDATE crunch_temp.DMDCBonus
    SET pay_cap = @RAcB_Annual_Max
    WHERE PayType = 'Sel Res Officer Accession Bonus';

    UPDATE crunch_temp.DMDCBonus
    SET pay_cap = @RAfB_Annual_Max
    WHERE PayType = 'Sel Res Officer Affiliation Bonus';




    --copy the avg cost into the capped pay before we start adjusting by the cap
    UPDATE crunch_temp.DMDCBonus
    SET capped_avg_mpa_pay = avg_annual_pay;

    --implement pay caps
    UPDATE crunch_temp.DMDCBonus
    SET capped_avg_mpa_pay = pay_cap * avg_annual_payments
    WHERE capped_avg_mpa_pay > pay_cap * avg_annual_payments;



    --add the capped bonus pay to our master table
    UPDATE crunch_temp.CostOfOfficerAcquisitionByAoc
    SET bonus_mpa = b.capped_total
    FROM crunch_temp.CostOfOfficerAcquisitionByAoc AS a
        LEFT OUTER JOIN
        (
            SELECT PayPlan,
                   subgrp,
                   GradeLevel,
                   SUM(capped_avg_mpa_pay) AS capped_total
            FROM crunch_temp.DMDCBonus
            GROUP BY PayPlan,
                     subgrp,
                     GradeLevel
        ) AS b
            ON a.PayPlan = b.PayPlan
               AND a.CategorySubGroupCode = b.subgrp
               AND a.GradeLevel = CONVERT(INT, b.GradeLevel);


    --execute the CGLA math to spread a bonus cost in one Grade level across all later Grade levels within that subgroup based on inventory
    UPDATE crunch_temp.CostOfOfficerAcquisitionByAoc
    SET CGLA_bonus_mpa = b.CGLA_Bonus
    FROM crunch_temp.CostOfOfficerAcquisitionByAoc AS a
        INNER JOIN
        (
            SELECT *,
                   SUM(bonus_mpa / CGLAInventory) OVER (PARTITION BY PayPlan,
                                                                     CategorySubGroupCode
                                                        ORDER BY PayPlan,
                                                                 CategorySubGroupCode,
                                                                 GradeLevel ASC
                                                       )
                   + crunch.GetChildBonusRecursive(
                                                      PayPlan,
                                                      CategorySubGroupCode,
                                                      GradeType,
                                                      GradeLevel,
                                                      'OfficerAcquisition',
                                                      @AmcosVersionId
                                                  ) AS CGLA_Bonus
            FROM crunch_temp.CostOfOfficerAcquisitionByAoc
        ) AS b
            ON a.PayPlan = b.PayPlan
               AND a.CategorySubGroupCode = b.CategorySubGroupCode
               AND a.GradeLevel = b.GradeLevel;


    --because we are using DMDC transaction and pay data sometimes we can get data from those sources for a scenario we don't have inventory for
    --those cases should not be allowed in our data to begin with so we eliminate them here before doing an insert later



    DELETE FROM crunch_temp.CostOfOfficerAcquisitionByAoc
    WHERE PayPlan + CAST(GradeLevel AS NVARCHAR(2)) + CategorySubGroupCode NOT IN
          (
              SELECT DISTINCT
                     PayPlan + CAST(GradeLevel AS NVARCHAR(2)) + CategorySubgroupCode
              FROM data.KnownInventory
              WHERE AmcosVersionId = @AmcosVersionId
          );

    DELETE FROM crunch_temp.DMDCBonus
    WHERE PayPlan + CAST(GradeLevel AS NVARCHAR(2)) + subgrp NOT IN
          (
              SELECT DISTINCT
                     PayPlan + CAST(GradeLevel AS NVARCHAR(2)) + CategorySubgroupCode
              FROM data.KnownInventory
              WHERE AmcosVersionId = @AmcosVersionId
          );

    IF @Debug = 1
    BEGIN
        --SELECT '#Acq_Calc'
        --SELECT * from #Acq_Calc ORDER BY gradetype, CMF, aoc, PayPlan, GradeLevel, [source of commission]--where gradetype='W'-- and GradeLevel=1

        SELECT 'sel res accession bonus table';
        SELECT PayType,
               PayPlan,
               CMF,
               subgrp,
               GradeType,
               GradeLevel,
               avg_cost,
               AmcosVersionId,
               avg_annual_pay,
               avg_annual_payments,
               pay_cap,
               capped_avg_mpa_pay
        FROM crunch_temp.DMDCBonus
        ORDER BY avg_annual_pay DESC;

        SELECT 'TempOfc_Acq_by_AOC';
        SELECT PayPlan,
               CategoryGroupCode,
               CategorySubGroupCode,
               GradeType,
               GradeLevel,
               inv,
               CGLAInventory,
               ofc_acq_mpa,
               ofc_acq_oma,
               bonus_mpa,
               CGLA_bonus_mpa
        FROM crunch_temp.CostOfOfficerAcquisitionByAoc
        ORDER BY CGLA_bonus_mpa DESC,
                 PayPlan,
                 CategorySubGroupCode,
                 GradeLevel;
    END;

    IF @Debug = 0
    BEGIN
        -- clear out the existing cost table for all the CE IDs we are about to insert values for
        --note that all PPs have at least 2 CEs: Avg Cost (MPA, OMA); NG/R have one additional for actual cost of bonus (PA)
        DELETE FROM crunch.Costs_AO
        WHERE CostElementId IN ( 136, 177 )
              AND AmcosVersionId = @AmcosVersionId;

        DELETE FROM crunch.Costs_AWO
        WHERE CostElementId IN ( 210, 678 )
              AND AmcosVersionId = @AmcosVersionId;

        DELETE FROM crunch.Costs_NO
        WHERE CostElementId IN ( 389, 4197, 4200 )
              AND AmcosVersionId = @AmcosVersionId;

        DELETE FROM crunch.Costs_NWO
        WHERE CostElementId IN ( 4199, 4194, 4195 )
              AND AmcosVersionId = @AmcosVersionId;

        DELETE FROM crunch.Costs_RO
        WHERE CostElementId IN ( 553, 4196, 4201 )
              AND AmcosVersionId = @AmcosVersionId;

        DELETE FROM crunch.Costs_RWO
        WHERE CostElementId IN ( 4198, 4192, 4193 )
              AND AmcosVersionId = @AmcosVersionId;

        --Insert average cost elements, we only have two APPNs for each 
        --AO
        --MPA
        INSERT INTO crunch.Costs_AO
        (
            [PayPlan],
            [CMF],
            AOC,
            [CostElementId],
            [GradeType],
            [GradeLevel],
            [WeaponSystemId],
            [Amount],
            CrunchTime,
            AmcosVersionId,
            LocationId
        )
        SELECT PayPlan,
               CategoryGroupCode,
               CategorySubGroupCode,
               136,
               GradeType,
               GradeLevel,
               -1,
               ofc_acq_mpa + ISNULL(CGLA_bonus_mpa, 0),
               @CrunchTime,
               @AmcosVersionId,
               -1
        FROM crunch_temp.CostOfOfficerAcquisitionByAoc
        WHERE PayPlan = 'AO';
        --OMA
        INSERT INTO crunch.Costs_AO
        (
            [PayPlan],
            [CMF],
            AOC,
            [CostElementId],
            [GradeType],
            [GradeLevel],
            [WeaponSystemId],
            [Amount],
            CrunchTime,
            AmcosVersionId,
            LocationId
        )
        SELECT PayPlan,
               CategoryGroupCode,
               CategorySubGroupCode,
               177,
               GradeType,
               GradeLevel,
               -1,
               ofc_acq_oma,
               @CrunchTime,
               @AmcosVersionId,
               -1
        FROM crunch_temp.CostOfOfficerAcquisitionByAoc
        WHERE PayPlan = 'AO';

        --AWO
        --MPA
        INSERT INTO crunch.Costs_AWO
        (
            [PayPlan],
            Branch,
            WOMOS,
            [CostElementId],
            [GradeType],
            [GradeLevel],
            [WeaponSystemId],
            [Amount],
            CrunchTime,
            AmcosVersionId,
            LocationId
        )
        SELECT PayPlan,
               CategoryGroupCode,
               CategorySubGroupCode,
               210,
               GradeType,
               GradeLevel,
               -1,
               ofc_acq_mpa + ISNULL(CGLA_bonus_mpa, 0),
               @CrunchTime,
               @AmcosVersionId,
               -1
        FROM crunch_temp.CostOfOfficerAcquisitionByAoc
        WHERE PayPlan = 'AWO';
        --OMA
        INSERT INTO crunch.Costs_AWO
        (
            [PayPlan],
            Branch,
            WOMOS,
            [CostElementId],
            [GradeType],
            [GradeLevel],
            [WeaponSystemId],
            [Amount],
            CrunchTime,
            AmcosVersionId,
            LocationId
        )
        SELECT PayPlan,
               CategoryGroupCode,
               CategorySubGroupCode,
               678,
               GradeType,
               GradeLevel,
               -1,
               ofc_acq_oma,
               @CrunchTime,
               @AmcosVersionId,
               -1
        FROM crunch_temp.CostOfOfficerAcquisitionByAoc
        WHERE PayPlan = 'AWO';

        --RO
        --MPA
        INSERT INTO crunch.Costs_RO
        (
            [PayPlan],
            [CMF],
            AOC,
            [CostElementId],
            [GradeType],
            [GradeLevel],
            [WeaponSystemId],
            [Amount],
            CrunchTime,
            AmcosVersionId
        )
        SELECT PayPlan,
               CategoryGroupCode,
               CategorySubGroupCode,
               553,
               GradeType,
               GradeLevel,
               -1,
               ofc_acq_mpa + ISNULL(CGLA_bonus_mpa, 0),
               @CrunchTime,
               @AmcosVersionId
        FROM crunch_temp.CostOfOfficerAcquisitionByAoc
        WHERE PayPlan = 'RO';
        --OMA
        INSERT INTO crunch.Costs_RO
        (
            [PayPlan],
            [CMF],
            AOC,
            [CostElementId],
            [GradeType],
            [GradeLevel],
            [WeaponSystemId],
            [Amount],
            CrunchTime,
            AmcosVersionId
        )
        SELECT PayPlan,
               CategoryGroupCode,
               CategorySubGroupCode,
               4201,
               GradeType,
               GradeLevel,
               -1,
               ofc_acq_oma,
               @CrunchTime,
               @AmcosVersionId
        FROM crunch_temp.CostOfOfficerAcquisitionByAoc
        WHERE PayPlan = 'RO';

        --RWO
        --MPA
        INSERT INTO crunch.Costs_RWO
        (
            [PayPlan],
            Branch,
            WOMOS,
            [CostElementId],
            [GradeType],
            [GradeLevel],
            [WeaponSystemId],
            [Amount],
            CrunchTime,
            AmcosVersionId
        )
        SELECT PayPlan,
               CategoryGroupCode,
               CategorySubGroupCode,
               4192,
               GradeType,
               GradeLevel,
               -1,
               ofc_acq_mpa + ISNULL(CGLA_bonus_mpa, 0),
               @CrunchTime,
               @AmcosVersionId
        FROM crunch_temp.CostOfOfficerAcquisitionByAoc
        WHERE PayPlan = 'RWO';
        --OMA
        INSERT INTO crunch.Costs_RWO
        (
            [PayPlan],
            Branch,
            WOMOS,
            [CostElementId],
            [GradeType],
            [GradeLevel],
            [WeaponSystemId],
            [Amount],
            CrunchTime,
            AmcosVersionId
        )
        SELECT PayPlan,
               CategoryGroupCode,
               CategorySubGroupCode,
               4193,
               GradeType,
               GradeLevel,
               -1,
               ofc_acq_oma,
               @CrunchTime,
               @AmcosVersionId
        FROM crunch_temp.CostOfOfficerAcquisitionByAoc
        WHERE PayPlan = 'RWO';

        --NO
        --MPA
        INSERT INTO crunch.Costs_NO
        (
            [PayPlan],
            [CMF],
            AOC,
            [CostElementId],
            [GradeType],
            [GradeLevel],
            [WeaponSystemId],
            [Amount],
            CrunchTime,
            AmcosVersionId
        )
        SELECT PayPlan,
               CategoryGroupCode,
               CategorySubGroupCode,
               389,
               GradeType,
               GradeLevel,
               -1,
               ofc_acq_mpa + ISNULL(CGLA_bonus_mpa, 0),
               @CrunchTime,
               @AmcosVersionId
        FROM crunch_temp.CostOfOfficerAcquisitionByAoc
        WHERE PayPlan = 'NO';
        --OMA
        INSERT INTO crunch.Costs_NO
        (
            [PayPlan],
            [CMF],
            AOC,
            [CostElementId],
            [GradeType],
            [GradeLevel],
            [WeaponSystemId],
            [Amount],
            CrunchTime,
            AmcosVersionId
        )
        SELECT PayPlan,
               CategoryGroupCode,
               CategorySubGroupCode,
               4200,
               GradeType,
               GradeLevel,
               -1,
               ofc_acq_oma,
               @CrunchTime,
               @AmcosVersionId
        FROM crunch_temp.CostOfOfficerAcquisitionByAoc
        WHERE PayPlan = 'NO';

        --NWO
        --MPA
        INSERT INTO crunch.Costs_NWO
        (
            [PayPlan],
            Branch,
            WOMOS,
            [CostElementId],
            [GradeType],
            [GradeLevel],
            [WeaponSystemId],
            [Amount],
            CrunchTime,
            AmcosVersionId
        )
        SELECT PayPlan,
               CategoryGroupCode,
               CategorySubGroupCode,
               4194,
               GradeType,
               GradeLevel,
               -1,
               ofc_acq_mpa + ISNULL(CGLA_bonus_mpa, 0),
               @CrunchTime,
               @AmcosVersionId
        FROM crunch_temp.CostOfOfficerAcquisitionByAoc
        WHERE PayPlan = 'NWO';
        --OMA
        INSERT INTO crunch.Costs_NWO
        (
            [PayPlan],
            Branch,
            WOMOS,
            [CostElementId],
            [GradeType],
            [GradeLevel],
            [WeaponSystemId],
            [Amount],
            CrunchTime,
            AmcosVersionId
        )
        SELECT PayPlan,
               CategoryGroupCode,
               CategorySubGroupCode,
               4195,
               GradeType,
               GradeLevel,
               -1,
               ofc_acq_oma,
               @CrunchTime,
               @AmcosVersionId
        FROM crunch_temp.CostOfOfficerAcquisitionByAoc
        WHERE PayPlan = 'NWO';


        --Insert actual cost elements, we only have one APPN for each 

        --RO RPA
        INSERT INTO crunch.Costs_RO
        (
            [PayPlan],
            CMF,
            AOC,
            [CostElementId],
            [GradeType],
            [GradeLevel],
            [WeaponSystemId],
            [Amount],
            CrunchTime,
            AmcosVersionId
        )
        SELECT PayPlan,
               CMF,
               subgrp,
               4196,
               GradeType,
               GradeLevel,
               -1,
               SUM(avg_annual_pay) AS actual_pay,
               @CrunchTime,
               @AmcosVersionId
        FROM crunch_temp.DMDCBonus
        WHERE PayPlan = 'RO'
        GROUP BY PayPlan,
                 CMF,
                 subgrp,
                 GradeType,
                 GradeLevel;
        --NO NGPA
        INSERT INTO crunch.Costs_NO
        (
            [PayPlan],
            CMF,
            AOC,
            [CostElementId],
            [GradeType],
            [GradeLevel],
            [WeaponSystemId],
            [Amount],
            CrunchTime,
            AmcosVersionId
        )
        SELECT PayPlan,
               CMF,
               subgrp,
               4197,
               GradeType,
               GradeLevel,
               -1,
               SUM(avg_annual_pay) AS actual_pay,
               @CrunchTime,
               @AmcosVersionId
        FROM crunch_temp.DMDCBonus
        WHERE PayPlan = 'NO'
        GROUP BY PayPlan,
                 CMF,
                 subgrp,
                 GradeType,
                 GradeLevel;

        --RWO RPA
        INSERT INTO crunch.Costs_RWO
        (
            [PayPlan],
            Branch,
            WOMOS,
            [CostElementId],
            [GradeType],
            [GradeLevel],
            [WeaponSystemId],
            [Amount],
            CrunchTime,
            AmcosVersionId
        )
        SELECT PayPlan,
               CMF,
               subgrp,
               4198,
               GradeType,
               GradeLevel,
               -1,
               SUM(avg_annual_pay) AS actual_pay,
               @CrunchTime,
               @AmcosVersionId
        FROM crunch_temp.DMDCBonus
        WHERE PayPlan = 'RWO'
        GROUP BY PayPlan,
                 CMF,
                 subgrp,
                 GradeType,
                 GradeLevel;

        --NWO NGPA
        INSERT INTO crunch.Costs_NWO
        (
            [PayPlan],
            Branch,
            WOMOS,
            [CostElementId],
            [GradeType],
            [GradeLevel],
            [WeaponSystemId],
            [Amount],
            CrunchTime,
            AmcosVersionId
        )
        SELECT PayPlan,
               CMF,
               subgrp,
               4199,
               GradeType,
               GradeLevel,
               -1,
               SUM(avg_annual_pay) AS actual_pay,
               @CrunchTime,
               @AmcosVersionId
        FROM crunch_temp.DMDCBonus
        WHERE PayPlan = 'NWO'
        GROUP BY PayPlan,
                 CMF,
                 subgrp,
                 GradeType,
                 GradeLevel;
    END;


END;
GO
