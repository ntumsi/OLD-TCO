

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
-- Parameters:
--     @AmcosVersionId:  
--     @Debug:  To see all of the intermediate calculations/tables set this variable to 1, otherwise set it to 0
-- =============================================
CREATE PROCEDURE [crunch].[CostOfOfficerAcquisition]
    @AmcosVersionId INT = -1,
    @Debug AS BIT = 0
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @IsValidAmcosVersion BIT = crunch.ValidateAmcosVersion(@AmcosVersionId);

    IF (@IsValidAmcosVersion = 0)
        RETURN 0;

    --drop our temp tables in case there weren't dropped in a previous run on this script
    --DROP TABLE IF EXISTS crunch.TempAcq_Calc;

    DROP TABLE IF EXISTS crunch.TempSOCTransaction; --aggregated without Grade level
    CREATE TABLE crunch.TempSOCTransaction
    (
        [PayPlan] NVARCHAR(3) NULL,
        [Grade] NVARCHAR(255) NULL,
        [SOC] NVARCHAR(255) NULL,
        [SOC_Name] NVARCHAR(255) NULL,
        [number] FLOAT NULL,
        [mypercent] FLOAT NULL,
        [MPA_cost] FLOAT NULL,
        [OMA_cost] FLOAT NULL,
        [PP_inventory] FLOAT NULL,
        [avg_MPA] FLOAT NULL,
        [avg_oma] FLOAT NULL
    );

    DROP TABLE IF EXISTS crunch.TempSOCTransactionGL; -- BY Grade level
    CREATE TABLE crunch.TempSOCTransactionGL
    (
        [PayPlan] NVARCHAR(3) NULL,
        [Grade] NVARCHAR(255) NULL,
        [GradeLevel] NVARCHAR(255) NULL,
        [SOC] NVARCHAR(255) NULL,
        [SOC_Name] NVARCHAR(255) NULL,
        [Total] FLOAT NULL
    );


    --pull data from the transaction file into a temp table
    --the DMDC transaction file shows Army gains by Source of Commission
    --note that the lookup for Acq Transaction types determines which transactions
    --are included/excluded in this process
    --included transactions are gains only new to the force, not from another services or prior service
    INSERT INTO crunch.TempSOCTransactionGL
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
              AND b.AmcosVersionId = @AmcosVersionId
        GROUP BY a.Component,
                 a.PayGrade,
                 a.SourceOfCommission
    ) AS a
        INNER JOIN lookup.MilitarySOC AS b
            ON a.SourceOfCommission = b.Code
    WHERE a.PayPlan IN ( 'AO', 'NO', 'RO' ); --we don't compute acq costs for warrants per Marsha, warrant acq costs come in for training through WOCS
    --note that we can have some Grade levels greater than 1 based on what the DMDC data says

    DECLARE @int AS INT = 0;

    INSERT INTO crunch.TempSOCTransaction
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
    FROM crunch.TempSOCTransactionGL
    GROUP BY PayPlan,
             Grade,
             SOC,
             SOC_Name;

    /*calculate the PayPlan's percent of the SOC Total
    we'll need this later to divy out some costs*/
    UPDATE crunch.TempSOCTransaction
    SET mypercent = b.calc_perc
    FROM crunch.TempSOCTransaction AS a
        INNER JOIN
        (
            SELECT *,
                   (number) / SUM(number) OVER (PARTITION BY SOC_Name) AS calc_perc
            FROM crunch.TempSOCTransaction
        ) AS b
            ON a.PayPlan = b.PayPlan
               AND a.Grade = b.Grade
               AND a.SOC = b.SOC;



    -- =============================================
    --Compute the Contribution of Active Accession move costs
    -- =============================================

    --an accession move cost is considered part of the acq cost for MPA
    DECLARE @Accession_Cost_3yr_avg AS FLOAT
        = crunch.GetArmyBudgetSingleValue('Accession_Travel_Officer', 'MPA', 'Avg', @AmcosVersionId);
    DECLARE @Inv_AOs AS FLOAT;
    DECLARE @Accession_cost_per_Officer AS FLOAT;

    SET @Inv_AOs =
    (
        SELECT SUM(Inventory) FROM data.Inventory WHERE PayPlan IN ( 'AO', 'AWO' )
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
    DECLARE @Adv_OMA_3yr_Avg FLOAT = crunch.GetArmyBudgetSingleValue('Advertising', 'OMA', 'Avg', @AmcosVersionId);

    DECLARE @Inv_OWs FLOAT;
    DECLARE @Inv_Total FLOAT;
    DECLARE @Adv_OMA_OW_Estimate FLOAT;
    DECLARE @Adv_OMA_OW_Per_soldier FLOAT;

    --get the inventory so we can make a ratio and divvy out R&A costs to officers, there's no precise way to do this so we do a simple ratio of Total inventory
    -- we assume that theR&A budget benefits the entire force (all 3 components) even though it is an MPA line item
    SET @Inv_OWs =
    (
        SELECT SUM(Inventory)
        FROM data.Inventory
        WHERE PayPlan IN ( 'AO', 'RO', 'NO', 'RWO', 'AWO', 'NWO' )
    );
    SET @Inv_Total =
    (
        SELECT SUM(Inventory) FROM data.Inventory
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

    DECLARE @Recruiting_RPA_Non_FT_3yr_avg FLOAT
        = crunch.GetArmyBudgetSingleValue('Recruiting', 'RPA', 'avg', @AmcosVersionId);
    DECLARE @Recruiting_RPA_Non_FT_E_Per_soldier FLOAT;

    DECLARE @Inv_R_Os FLOAT;
    SET @Inv_R_Os =
    (
        SELECT SUM(Inventory) FROM data.Inventory WHERE PayPlan IN ( 'RO' )
    );
    DECLARE @Inv_R FLOAT;
    SET @Inv_R =
    (
        SELECT SUM(Inventory)
        FROM data.Inventory
        WHERE PayPlan IN ( 'RO', 'RWO', 'RE' )
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

    DECLARE @Recruiting_NGPA_Non_FT_3yr_avg FLOAT
        = crunch.GetArmyBudgetSingleValue('Recruiting_Retention', 'NGPA', 'avg', @AmcosVersionId);
    DECLARE @Recruiting_NGPA_Non_FT_E_Per_soldier FLOAT;

    DECLARE @Inv_NG_Os FLOAT;
    SET @Inv_NG_Os =
    (
        SELECT SUM(Inventory) FROM data.Inventory WHERE PayPlan IN ( 'NO' )
    );
    DECLARE @Inv_NG FLOAT;
    SET @Inv_NG =
    (
        SELECT SUM(Inventory)
        FROM data.Inventory
        WHERE PayPlan IN ( 'NO', 'NWO', 'NE' )
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
    DECLARE @USMA_MPA_est AS FLOAT = crunch.GetArmyBudgetSingleValue('USMA', 'MPA', 'avg', @AmcosVersionId);
    DECLARE @USMA_OMA_est AS FLOAT = crunch.GetArmyBudgetSingleValue('USMA', 'OMA', 'avg', @AmcosVersionId);

    --number of military personnel who support the school
    DECLARE @USMA_MPA_Officers INT = crunch.GetArmyBudgetSingleValue('Officer_USMA', 'MPA', 'avg', @AmcosVersionId);
    DECLARE @USMA_MPA_Enlisted INT = crunch.GetArmyBudgetSingleValue('Enlisted_USMA', 'MPA', 'avg', @AmcosVersionId);
    DECLARE @USMA_MPA_Warrant INT = crunch.GetArmyBudgetSingleValue('Warrant_USMA', 'MPA', 'avg', @AmcosVersionId);

    --pay for the above soldiers, we assume 
    DECLARE @E7_Composite_Standard FLOAT = crunch.GetSingleValue('AA', 'E7_Composite_Standard_Rate');
    DECLARE @O5_Composite_Standard FLOAT = crunch.GetSingleValue('AA', 'O5_Composite_Standard_Rate');
    DECLARE @W2_Composite_Standard FLOAT = crunch.GetSingleValue('AA', 'W2_Composite_Standard_Rate');

    --compute MPA and OMA costs
    SET @USMA_MPA_est
        = @USMA_MPA_est + (@USMA_MPA_Officers * @O5_Composite_Standard) + (@USMA_MPA_Enlisted * @E7_Composite_Standard)
          + (@USMA_MPA_Warrant * @W2_Composite_Standard);

    UPDATE crunch.TempSOCTransaction
    SET MPA_cost = @USMA_MPA_est * mypercent
    WHERE SOC = 'A';

    UPDATE crunch.TempSOCTransaction
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
    DECLARE @OCS_MPA_ACPG FLOAT = crunch.GetSingleValue('AO', 'OCS_MPA_Cost_Per_Grad');
    DECLARE @OCS_OMA_ACPG FLOAT = crunch.GetSingleValue('AO', 'OCS_OMA_Cost_Per_Grad');

    UPDATE crunch.TempSOCTransaction
    SET MPA_cost = @OCS_MPA_ACPG * number
    WHERE SOC IN ( 'J', 'X', 'Z' );

    UPDATE crunch.TempSOCTransaction
    SET OMA_cost = @OCS_OMA_ACPG * number
    WHERE SOC IN ( 'J', 'X', 'Z' );

    -- =============================================
    --Compute the Average Cost of National Guard state OCS
    -- =============================================


    --Get Single Values
    --Total Annual Program Cost (TAPC)
    DECLARE @NGOCS_MPA_3YR_Avg AS FLOAT = crunch.GetArmyBudgetSingleValue('NGOCS', 'NGPA', 'avg', @AmcosVersionId);
    --OMNG JBook lumps OMA costs with other programs, assume the same ratio of OMA to (MPA + OMA) ACPG costs as Army OCS
    DECLARE @NGOCS_OMNG_3YR_Avg AS FLOAT = crunch.GetArmyBudgetSingleValue('NGOCS', 'OMNG', 'avg', @AmcosVersionId);

    IF @Debug = 1
    BEGIN
        SELECT CONCAT('NGOCS MPA 3 yr avg: ', FORMAT(@NGOCS_MPA_3YR_Avg, 'C', 'en-us'));
        SELECT CONCAT('NGOCS OMA 3 year avg: ', FORMAT(@NGOCS_OMNG_3YR_Avg, 'C', 'en-us'));
    END;

    UPDATE crunch.TempSOCTransaction
    SET MPA_cost = @NGOCS_MPA_3YR_Avg * mypercent
    WHERE SOC IN ( 'L' );

    UPDATE crunch.TempSOCTransaction
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
    DECLARE @ROTC_OMA_Scholarship_3yr_avg AS FLOAT
        = crunch.GetArmyBudgetSingleValue('ROTC_Scholarship', 'OMA', 'avg', @AmcosVersionId);

    DECLARE @ROTC_OMA_3yr_avg AS FLOAT = crunch.GetArmyBudgetSingleValue('ROTC', 'OMA', 'avg', @AmcosVersionId);


    --Compute the share of OMA costs for scholarship/nonscholarship
    --non sholarships share is half the cost of the OMA budget
    --scholarships share is half the cost of the OMA budget + the oma scholarship cost
    DECLARE @ROTC_OMA_Scholarship FLOAT;
    DECLARE @ROTC_OMA_Non_Scholarship FLOAT;
    SET @ROTC_OMA_Non_Scholarship = (@ROTC_OMA_3yr_avg) / 2;
    SET @ROTC_OMA_Scholarship = ((@ROTC_OMA_3yr_avg) / 2) + @ROTC_OMA_Scholarship_3yr_avg;

    DECLARE @ROTC_MPA_Non_Scholarship AS FLOAT
        = crunch.GetArmyBudgetSingleValue('ROTC_NonScholarship', 'MPA', 'avg', @AmcosVersionId);
    DECLARE @ROTC_MPA_Scholarship AS FLOAT
        = crunch.GetArmyBudgetSingleValue('ROTC_Scholarship', 'MPA', 'avg', @AmcosVersionId);





    --Total students for  scholarship
    DECLARE @ROTC_Scholarship_TNoS FLOAT;
    SELECT @ROTC_Scholarship_TNoS = paramValue
    FROM dataload.SingleValues
    WHERE PayPlan = 'MO'
          AND paramName = 'ROTC_Scholarship_TNoS';

    --Total students for non scholarship
    DECLARE @ROTC_Non_Scholarship_TNoS FLOAT;
    SELECT @ROTC_Non_Scholarship_TNoS = paramValue
    FROM dataload.SingleValues
    WHERE PayPlan = 'MO'
          AND paramName = 'ROTC_Non_Scholarship_TNoS';

    --get the avg number of military support staff
    DECLARE @ROTC_Enlisted INT = crunch.GetArmyBudgetSingleValue('Enlisted_ROTC', 'MPA', 'avg', @AmcosVersionId);
    DECLARE @ROTC_Warrant INT = crunch.GetArmyBudgetSingleValue('Warrant_ROTC', 'MPA', 'avg', @AmcosVersionId);
    DECLARE @ROTC_Officer INT = crunch.GetArmyBudgetSingleValue('Officer_ROTC', 'MPA', 'avg', @AmcosVersionId);

    DECLARE @ROTC_Enlisted_Cost FLOAT = @E7_Composite_Standard * @ROTC_Enlisted;
    DECLARE @rotc_Officer_cost FLOAT = @O5_Composite_Standard * @ROTC_Officer;
    DECLARE @rotc_Warrant_Cost FLOAT = @W2_Composite_Standard * @ROTC_Warrant;

    --set up a ratio to divvy out the cost for military personnel to each ROTC program
    DECLARE @ROTC_Scholarship_TNoS_Ratio FLOAT,
            @ROTC_Non_Scholarship_TNoS_Ratio FLOAT;

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


    UPDATE crunch.TempSOCTransaction
    SET MPA_cost = @ROTC_MPA_Scholarship * mypercent,
        OMA_cost = @ROTC_OMA_Scholarship * mypercent
    WHERE SOC IN ( 'G' );

    UPDATE crunch.TempSOCTransaction
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
    DECLARE @DCOCS_MPA_ACPG FLOAT;
    SELECT @DCOCS_MPA_ACPG = paramValue
    FROM dataload.SingleValues
    WHERE PayPlan = 'AO'
          AND paramName = 'DOCS_MPA_Cost_Per_Grad';

    DECLARE @DCOCS_OMA_ACPG FLOAT;
    SELECT @DCOCS_OMA_ACPG = paramValue
    FROM dataload.SingleValues
    WHERE PayPlan = 'AO'
          AND paramName = 'DOCS_OMA_Cost_Per_Grad';

    UPDATE crunch.TempSOCTransaction
    SET MPA_cost = @DCOCS_MPA_ACPG * number,
        OMA_cost = @DCOCS_OMA_ACPG * number
    WHERE SOC IN ( 'M', 'N' );


    UPDATE crunch.TempSOCTransaction
    SET PP_inventory = b.inv
    FROM crunch.TempSOCTransaction AS a
        INNER JOIN
        (
            SELECT PayPlan,
                   SUM(Inventory) AS inv
            FROM data.Inventory
            GROUP BY PayPlan
        ) AS b
            ON a.PayPlan = b.PayPlan;

    UPDATE crunch.TempSOCTransaction
    SET avg_MPA = MPA_cost / PP_inventory,
        avg_oma = OMA_cost / PP_inventory;

    --aggregate the costs up to the pay plan level and then do the PayPlan averaging
    DROP TABLE IF EXISTS crunch.TempOfc_Acq_Total;
    CREATE TABLE crunch.TempOfc_Acq_Total
    (
        [PayPlan] NVARCHAR(3) NULL,
        [mpa] FLOAT NULL,
        [oma] FLOAT NULL
    );

    INSERT INTO crunch.TempOfc_Acq_Total
    (
        PayPlan,
        mpa,
        oma
    )
    SELECT PayPlan,
           SUM(avg_MPA) AS mpa,
           SUM(avg_oma) AS oma
    FROM crunch.TempSOCTransaction
    GROUP BY PayPlan;



    DROP TABLE IF EXISTS crunch.TempOfc_Acq_by_AOC;
    CREATE TABLE crunch.TempOfc_Acq_by_AOC
    (
        [PayPlan] NVARCHAR(3) NOT NULL,
        [CategoryGroupCode] NVARCHAR(4) NOT NULL,
        [CategorySubGroupCode] NVARCHAR(4) NOT NULL,
        [GradeType] NVARCHAR(3) NOT NULL,
        [GradeLevel] TINYINT NOT NULL,
        [inv] INT NULL,
        [CGLA_inv] FLOAT NULL,
        [ofc_acq_mpa] FLOAT NULL,
        [ofc_acq_oma] FLOAT NULL,
        [bonus_mpa] FLOAT NULL,
        [CGLA_bonus_mpa] FLOAT NULL
    );

    INSERT INTO crunch.TempOfc_Acq_by_AOC
    (
        PayPlan,
        CategoryGroupCode,
        CategorySubGroupCode,
        GradeType,
        GradeLevel,
        inv,
        CGLA_inv,
        ofc_acq_mpa,
        ofc_acq_oma,
        bonus_mpa,
        CGLA_bonus_mpa
    )
    SELECT PayPlan,
           CategoryGroupCode,
           CategorySubGroupCode,
           GradeType,
           GradeLevel,
           SUM(Inventory) AS inv,
           @int AS CGLA_inv, --this is all the inventory at and above the pp, GL, AOC for bonus amounts
           0.0 AS ofc_acq_mpa,
           0.0 AS ofc_acq_oma,
           0.0 AS bonus_mpa,
           0.0 AS CGLA_bonus_mpa
    FROM data.Inventory
    WHERE GradeType IN ( 'O', 'W' )
    GROUP BY PayPlan,
             CategoryGroupCode,
             CategorySubGroupCode,
             GradeType,
             GradeLevel;

    --compute my CGLA inventory
    --cgla is the cummulative inventory at or above any one PayPlan & subgroup combination
    --it is later used to average bonus costs across later grades
    UPDATE crunch.TempOfc_Acq_by_AOC
    SET CGLA_inv = b.rev_cumulative
    FROM crunch.TempOfc_Acq_by_AOC AS a
        INNER JOIN
        (
            --compute the reverse sum which wil later be used to do Cross Grade Level Averaging (CGLA)
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
                                       )
                   + crunch.GetParentInventoryRecursive(PayPlan, CategorySubGroupCode, GradeType, GradeLevel) AS rev_cumulative
            FROM
            (
                SELECT PayPlan,
                       CategorySubGroupCode,
                       GradeType,
                       GradeLevel,
                       SUM(Inventory) AS inventory
                FROM data.Inventory
                GROUP BY PayPlan,
                         CategorySubGroupCode,
                         GradeType,
                         GradeLevel
            ) AS A
            WHERE GradeType IN ( 'O', 'W' )
            GROUP BY PayPlan,
                     CategorySubGroupCode,
                     GradeType,
                     GradeLevel,
                     inventory
        ) AS B
            ON A.PayPlan = B.PayPlan
               AND A.CategorySubGroupCode = B.CategorySubGroupCode
               AND A.GradeLevel = B.GradeLevel;

    --add in the R&A cost which applies to everyone
    UPDATE crunch.TempOfc_Acq_by_AOC
    SET ofc_acq_oma = @Adv_OMA_OW_Per_soldier;

    --add in the accession move cost
    UPDATE crunch.TempOfc_Acq_by_AOC
    SET ofc_acq_mpa = ofc_acq_mpa + @Accession_cost_per_Officer
    WHERE PayPlan IN ( 'AO', 'AWO' );

    --add in the Reserve Recruiting per soldier
    UPDATE crunch.TempOfc_Acq_by_AOC
    SET ofc_acq_mpa = ofc_acq_mpa + @Recruiting_RPA_Non_FT_E_Per_soldier
    WHERE PayPlan IN ( 'RO', 'RWO' );

    --add in the Reserve Recruiting per soldier
    UPDATE crunch.TempOfc_Acq_by_AOC
    SET ofc_acq_mpa = ofc_acq_mpa + @Recruiting_NGPA_Non_FT_E_Per_soldier
    WHERE PayPlan IN ( 'NO', 'NWO' );


    --add in the computed PayPlan averages
    UPDATE crunch.TempOfc_Acq_by_AOC
    SET ofc_acq_oma = A.ofc_acq_oma + B.oma,
        ofc_acq_mpa = A.ofc_acq_mpa + B.mpa
    FROM crunch.TempOfc_Acq_by_AOC AS A
        INNER JOIN crunch.TempOfc_Acq_Total AS B
            ON A.PayPlan = B.PayPlan;




    IF @Debug = 1
    BEGIN
        SELECT 'TempSOCTransactionGL';
        SELECT PayPlan,
               Grade,
               GradeLevel,
               SOC,
               SOC_Name,
               Total
        FROM crunch.TempSOCTransactionGL
        ORDER BY PayPlan,
                 Grade,
                 GradeLevel,
                 SOC;

        SELECT 'TempSOCTransaction';
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
        FROM crunch.TempSOCTransaction
        ORDER BY SOC,
                 PayPlan;

        SELECT 'TempOfc_Acq_Total';
        SELECT PayPlan,
               mpa,
               oma
        FROM crunch.TempOfc_Acq_Total
        ORDER BY PayPlan; --, categorysubgroupcode, GradeLevel
    END;


    /*


-- =============================================
--Compute the Average Cost of WOCS
-- =============================================
--Per meeting with Marsha on 5/23/2018, warrants will receive no commissioning costs, instead any costs to make them a warrant
-- like WOCS will be burdened against the applicable WOMOSes in the training CEs



-- =============================================
--The following Sources of Commission purposely have no costs
-- SoC = B, C, D, E, F -> these are other service programs and thus have no cost to the Army
-- SOC = K -> This is apparently a defunct training program (ended in the 60s) which was run by the AF
-- =============================================

*/
    -- =============================================
    --Compute the Average Cost of Officer Accessions Bonus which only applies to the reserve components
    -- =============================================


    DROP TABLE IF EXISTS crunch.TempDMDCBonus;
    CREATE TABLE crunch.TempDMDCBonus
    (
        [PayType] NVARCHAR(50) NULL,
        [PayPlan] NVARCHAR(3) NULL,
        [CMF] NVARCHAR(2) NULL,
        [subgrp] NVARCHAR(4) NULL,
        [GradeType] NVARCHAR(2) NULL,
        [GradeLevel] NVARCHAR(2) NULL,
        [avg_cost] FLOAT NULL,
        [AmcosVersionId] INT NULL,
        [avg_annual_pay] FLOAT NULL,
        [avg_annual_payments] FLOAT NULL,
        pay_cap FLOAT NULL,
        capped_avg_mpa_pay FLOAT NULL
    );

    INSERT INTO crunch.TempDMDCBonus
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
    FROM crunch.DMDCPayProcessed
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
    DECLARE @RAcB_Annual_Max AS FLOAT;
    SELECT @RAcB_Annual_Max = paramValue
    FROM dataload.SingleValues
    WHERE PayPlan = 'RC'
          AND paramName = 'AccessionBonus_Annual_Max';

    --FMR Volume 7A Chapter 56 sets a maximum limit on reserve accession or affiliation bonus in the selected reserve
    --note that there are several maximums based on number of years but the annual maximum is all we are concerned about
    DECLARE @RAfB_Annual_Max AS FLOAT;
    SELECT @RAfB_Annual_Max = paramValue
    FROM dataload.SingleValues
    WHERE PayPlan = 'RC'
          AND paramName = 'AffiliationBonus_Annual_Max';

    --bring in pay caps for reserves
    UPDATE crunch.TempDMDCBonus
    SET pay_cap = @RAcB_Annual_Max
    WHERE PayType = 'Sel Res Officer Accession Bonus';

    UPDATE crunch.TempDMDCBonus
    SET pay_cap = @RAfB_Annual_Max
    WHERE PayType = 'Sel Res Officer Affiliation Bonus';




    --copy the avg cost into the capped pay before we start adjusting by the cap
    UPDATE crunch.TempDMDCBonus
    SET capped_avg_mpa_pay = avg_annual_pay;

    --implement pay caps
    UPDATE crunch.TempDMDCBonus
    SET capped_avg_mpa_pay = pay_cap * avg_annual_payments
    WHERE capped_avg_mpa_pay > pay_cap * avg_annual_payments;



    --add the capped bonus pay to our master table
    UPDATE crunch.TempOfc_Acq_by_AOC
    SET bonus_mpa = B.capped_total
    FROM crunch.TempOfc_Acq_by_AOC AS A
        LEFT OUTER JOIN
        (
            SELECT PayPlan,
                   subgrp,
                   GradeLevel,
                   SUM(capped_avg_mpa_pay) AS capped_total
            FROM crunch.TempDMDCBonus
            GROUP BY PayPlan,
                     subgrp,
                     GradeLevel
        ) AS B
            ON A.PayPlan = B.PayPlan
               AND A.CategorySubGroupCode = B.subgrp
               AND A.GradeLevel = CONVERT(INT, B.GradeLevel);


    --execute the CGLA math to spread a bonus cost in one Grade level across all later Grade levels within that subgroup based on inventory
    UPDATE crunch.TempOfc_Acq_by_AOC
    SET CGLA_bonus_mpa = B.CGLA_Bonus
    FROM crunch.TempOfc_Acq_by_AOC AS A
        INNER JOIN
        (
            SELECT *,
                   SUM(bonus_mpa / CGLA_inv) OVER (PARTITION BY PayPlan,
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
                                                      'OfficerAcquisition'
                                                  ) AS CGLA_Bonus
            FROM crunch.TempOfc_Acq_by_AOC
        ) AS B
            ON A.PayPlan = B.PayPlan
               AND A.CategorySubGroupCode = B.CategorySubGroupCode
               AND A.GradeLevel = B.GradeLevel;

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
        FROM crunch.TempDMDCBonus
        ORDER BY avg_annual_pay DESC;

        SELECT 'TempOfc_Acq_by_AOC';
        SELECT PayPlan,
               CategoryGroupCode,
               CategorySubGroupCode,
               GradeType,
               GradeLevel,
               inv,
               CGLA_inv,
               ofc_acq_mpa,
               ofc_acq_oma,
               bonus_mpa,
               CGLA_bonus_mpa
        FROM crunch.TempOfc_Acq_by_AOC
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
        WHERE CostElementId IN ( 136, 177 );

        DELETE FROM crunch.Costs_AWO
        WHERE CostElementId IN ( 210, 678 );

        DELETE FROM crunch.Costs_NO
        WHERE CostElementId IN ( 389, 4197, 4200 );

        DELETE FROM crunch.Costs_NWO
        WHERE CostElementId IN ( 4199, 4194, 4195 );

        DELETE FROM crunch.Costs_RO
        WHERE CostElementId IN ( 553, 4196, 4201 );

        DELETE FROM crunch.Costs_RWO
        WHERE CostElementId IN ( 4198, 4192, 4193 );

        DECLARE @CrunchTime SMALLDATETIME = CONVERT(SMALLDATETIME, GETDATE());

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
            CrunchTime
        )
        SELECT PayPlan,
               CategoryGroupCode,
               CategorySubGroupCode,
               136,
               GradeType,
               GradeLevel,
               -1,
               ofc_acq_mpa + ISNULL(CGLA_bonus_mpa, 0),
               @CrunchTime
        FROM crunch.TempOfc_Acq_by_AOC
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
            CrunchTime
        )
        SELECT PayPlan,
               CategoryGroupCode,
               CategorySubGroupCode,
               177,
               GradeType,
               GradeLevel,
               -1,
               ofc_acq_oma,
               @CrunchTime
        FROM crunch.TempOfc_Acq_by_AOC
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
            CrunchTime
        )
        SELECT PayPlan,
               CategoryGroupCode,
               CategorySubGroupCode,
               210,
               GradeType,
               GradeLevel,
               -1,
               ofc_acq_mpa + ISNULL(CGLA_bonus_mpa, 0),
               @CrunchTime
        FROM crunch.TempOfc_Acq_by_AOC
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
            CrunchTime
        )
        SELECT PayPlan,
               CategoryGroupCode,
               CategorySubGroupCode,
               678,
               GradeType,
               GradeLevel,
               -1,
               ofc_acq_oma,
               @CrunchTime
        FROM crunch.TempOfc_Acq_by_AOC
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
            CrunchTime
        )
        SELECT PayPlan,
               CategoryGroupCode,
               CategorySubGroupCode,
               553,
               GradeType,
               GradeLevel,
               -1,
               ofc_acq_mpa + ISNULL(CGLA_bonus_mpa, 0),
               @CrunchTime
        FROM crunch.TempOfc_Acq_by_AOC
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
            CrunchTime
        )
        SELECT PayPlan,
               CategoryGroupCode,
               CategorySubGroupCode,
               4201,
               GradeType,
               GradeLevel,
               -1,
               ofc_acq_oma,
               @CrunchTime
        FROM crunch.TempOfc_Acq_by_AOC
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
            CrunchTime
        )
        SELECT PayPlan,
               CategoryGroupCode,
               CategorySubGroupCode,
               4192,
               GradeType,
               GradeLevel,
               -1,
               ofc_acq_mpa + ISNULL(CGLA_bonus_mpa, 0),
               @CrunchTime
        FROM crunch.TempOfc_Acq_by_AOC
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
            CrunchTime
        )
        SELECT PayPlan,
               CategoryGroupCode,
               CategorySubGroupCode,
               4193,
               GradeType,
               GradeLevel,
               -1,
               ofc_acq_oma,
               @CrunchTime
        FROM crunch.TempOfc_Acq_by_AOC
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
            CrunchTime
        )
        SELECT PayPlan,
               CategoryGroupCode,
               CategorySubGroupCode,
               389,
               GradeType,
               GradeLevel,
               -1,
               ofc_acq_mpa + ISNULL(CGLA_bonus_mpa, 0),
               @CrunchTime
        FROM crunch.TempOfc_Acq_by_AOC
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
            CrunchTime
        )
        SELECT PayPlan,
               CategoryGroupCode,
               CategorySubGroupCode,
               4200,
               GradeType,
               GradeLevel,
               -1,
               ofc_acq_oma,
               @CrunchTime
        FROM crunch.TempOfc_Acq_by_AOC
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
            CrunchTime
        )
        SELECT PayPlan,
               CategoryGroupCode,
               CategorySubGroupCode,
               4194,
               GradeType,
               GradeLevel,
               -1,
               ofc_acq_mpa + ISNULL(CGLA_bonus_mpa, 0),
               @CrunchTime
        FROM crunch.TempOfc_Acq_by_AOC
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
            CrunchTime
        )
        SELECT PayPlan,
               CategoryGroupCode,
               CategorySubGroupCode,
               4195,
               GradeType,
               GradeLevel,
               -1,
               ofc_acq_oma,
               @CrunchTime
        FROM crunch.TempOfc_Acq_by_AOC
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
            CrunchTime
        )
        SELECT PayPlan,
               CMF,
               subgrp,
               4196,
               GradeType,
               GradeLevel,
               -1,
               SUM(avg_annual_pay) AS actual_pay,
               @CrunchTime
        FROM crunch.TempDMDCBonus
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
            CrunchTime
        )
        SELECT PayPlan,
               CMF,
               subgrp,
               4197,
               GradeType,
               GradeLevel,
               -1,
               SUM(avg_annual_pay) AS actual_pay,
               @CrunchTime
        FROM crunch.TempDMDCBonus
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
            CrunchTime
        )
        SELECT PayPlan,
               CMF,
               subgrp,
               4198,
               GradeType,
               GradeLevel,
               -1,
               SUM(avg_annual_pay) AS actual_pay,
               @CrunchTime
        FROM crunch.TempDMDCBonus
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
            CrunchTime
        )
        SELECT PayPlan,
               CMF,
               subgrp,
               4199,
               GradeType,
               GradeLevel,
               -1,
               SUM(avg_annual_pay) AS actual_pay,
               @CrunchTime
        FROM crunch.TempDMDCBonus
        WHERE PayPlan = 'NWO'
        GROUP BY PayPlan,
                 CMF,
                 subgrp,
                 GradeType,
                 GradeLevel;
    END;

--this is a relic, leaving it in here just for reference as we finalize the SP

--	DELETE FROM dbo. PreCrunchCosts WHERE costelementcategory LIKE '%Officer Acquisition Costs%' 

--INSERT INTO dbo.PreCrunchCosts
--SELECT * 
--FROM
--(

--select 'ALL COST' as bin, PayPlan,CategoryGroupCode,CategorySubGroupCode, 'MPA' as 'Appropriation', 'Officer Acquisition Costs' as category, 'Actual Cost of Accession Bonus' as 'CEname', 
--gradetype, GradeLevel , bonus_mpa as Amount from #Ofc_Acq_by_AOC
--WHERE bonus_mpa>0
--UNION
--select 'proposed' as bin, PayPlan,CategoryGroupCode,CategorySubGroupCode, 'MPA' as 'Appropriation', 'Officer Acquisition Costs' as category, 'Avg Cost of Officer Acquisition' as 'CEname', 
--gradetype, GradeLevel , ofc_acq_mpa + ISNULL(cgla_bonus_mpa,0) as Amount from #Ofc_Acq_by_AOC

--union
--select 'proposed' as bin, PayPlan,CategoryGroupCode,CategorySubGroupCode, 'OMA' as 'Appropriation', 'Officer Acquisition Costs' as category, 'Avg Cost of Officer Acquisition' as 'CEname', 
--gradetype, GradeLevel , ofc_acq_oma  as Amount from #Ofc_Acq_by_AOC



--) AS a
END;