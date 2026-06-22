


-- =============================================
-- Author:Dan Hogan
-- Create date: 10/18/2018
-- Description:	Process data from a POM lock file into single values to be used by crunches
-- Considerations: the keys used to identify specific POM  values may change over the years so we'll have to be mindful of potential adjustments needed for this
-- Dependencies
--      - Army Budget
--      - 
--      - to see all of the intermediate calculations/tables set this variable to 1, otherwise set it to 0
-- =============================================

CREATE PROCEDURE [crunch].[ArmyBudget]
    @AmcosVersionId INT = -1,
    @Debug AS BIT = 1
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @IsValidAmcosVersion BIT = crunch.ValidateAmcosVersion(@AmcosVersionId);
    IF (@IsValidAmcosVersion = 0)
        RETURN 0;

    DROP TABLE IF EXISTS #POMData;
    CREATE TABLE #POMData
    (
        ParameterName NVARCHAR(50) NOT NULL,
        Appropriation NVARCHAR(10) NOT NULL,
        FY NVARCHAR(4) NOT NULL,
        AmcosVersionId INT NOT NULL,
        Amount FLOAT NULL,
    );
    DROP TABLE IF EXISTS #ArmyBudget;
    CREATE TABLE #ArmyBudget
    (
        FY SMALLINT NULL,
        AMOUNT NUMERIC(18, 0) NULL,
        BO NVARCHAR(1) NULL,
        APPN NVARCHAR(5) NULL,
        TC NVARCHAR(50) NULL,
        RC NVARCHAR(5) NULL,
        APE NVARCHAR(10) NULL,
        APE_PT_DESC NVARCHAR(255) NULL,
        AMSCO NVARCHAR(255) NULL,
        SAG NVARCHAR(255) NULL,
        BA NVARCHAR(50) NULL,
        MDEP NVARCHAR(255) NULL,
        ROC NVARCHAR(4) NULL,
        CMD NVARCHAR(2) NULL,
        FSC NVARCHAR(255) NULL,
        OSDPE NVARCHAR(255) NULL,
        RIC NVARCHAR(5) NULL,
        MHC NVARCHAR(50) NULL,
        DOLLAR_TYPE NVARCHAR(255) NULL,
        DOLLAR_TYPE_DESC NVARCHAR(255) NULL,
        AmcosVersionId INT NULL
    );

    -- for dollars we only want Army TOA (BO=1) and base budget money; for BO=4 (people counts) the base budget criteria doesn't matter
    INSERT INTO #ArmyBudget
    (
        FY,
        AMOUNT,
        BO,
        APPN,
        TC,
        RC,
        APE,
        APE_PT_DESC,
        AMSCO,
        SAG,
        BA,
        MDEP,
        ROC,
        CMD,
        FSC,
        OSDPE,
        RIC,
        MHC,
        DOLLAR_TYPE,
        DOLLAR_TYPE_DESC,
        AmcosVersionId
    )
    SELECT FY,
           AMOUNT,
           BO,
           APPN,
           TC,
           RC,
           APE,
           APE_PT_DESC,
           AMSCO,
           SAG,
           BA,
           MDEP,
           ROC,
           CMD,
           FSC,
           OSDPE,
           RIC,
           MHC,
           DOLLAR_TYPE,
           DOLLAR_TYPE_DESC,
           AmcosVersionId
    FROM dataload.ArmyBudget
    WHERE AmcosVersionId = @AmcosVersionId
          AND
          (
              BO = '1'
              OR BO = '4'
          );

    /* Advertising budget */
    INSERT INTO #POMData
    (
        ParameterName,
        Appropriation,
        FY,
        AmcosVersionId,
        Amount
    )
    SELECT 'Advertising',
           APPN,
           FY,
           @AmcosVersionId,
           SUM(AMOUNT * 1000) AS Amount
    FROM #ArmyBudget
    WHERE DOLLAR_TYPE LIKE 'BASE%'
          AND APPN = 'OMA'
          AND APE = '331712000'
          AND BO = '1'
          AND MDEP = 'VAMP'
    GROUP BY APPN,
             FY;

    /* Active Recruiting OMA budget */
    INSERT INTO #POMData
    (
        ParameterName,
        Appropriation,
        FY,
        AmcosVersionId,
        Amount
    )
    SELECT 'Recruiting',
           APPN,
           FY,
           @AmcosVersionId,
           SUM(AMOUNT) * 1000
    FROM #ArmyBudget
    WHERE DOLLAR_TYPE LIKE 'BASE%'
          AND SAG = '331'
          AND BO = '1'
          AND MDEP <> 'VAMP'
          AND APPN = 'OMA'
    GROUP BY APPN,
             FY;

    /* Active Accession Travel Budget */
    INSERT INTO #POMData
    (
        ParameterName,
        Appropriation,
        FY,
        AmcosVersionId,
        Amount
    )
    SELECT 'Accession_Travel_Enlisted',
           APPN,
           FY,
           @AmcosVersionId,
           SUM(AMOUNT) * 1000
    FROM #ArmyBudget
    WHERE DOLLAR_TYPE LIKE 'BASE%'
          AND APE_PT_DESC LIKE '%Accession Tvl, Enlisted%'
          AND BO = '1'
          AND APPN = 'MPA'
    GROUP BY APPN,
             FY;
    INSERT INTO #POMData
    (
        ParameterName,
        Appropriation,
        FY,
        AmcosVersionId,
        Amount
    )
    SELECT 'Accession_Travel_Officer',
           APPN,
           FY,
           @AmcosVersionId,
           SUM(AMOUNT) * 1000
    FROM #ArmyBudget
    WHERE DOLLAR_TYPE LIKE 'BASE%'
          AND APE_PT_DESC LIKE '%Accession Tvl, Officer%'
          AND BO = '1'
          AND APPN = 'MPA'
    GROUP BY APPN,
             FY;

    /* Active recruiting MPA budget
    --Discussion-there is no POM entry for this so we calculate based on manpower
    --Concerns-FY17 is just slightly off, the others are perfect */
    INSERT INTO #POMData
    (
        ParameterName,
        Appropriation,
        FY,
        AmcosVersionId,
        Amount
    )
    SELECT 'Enlisted_Recruiters',
           APPN,
           FY,
           @AmcosVersionId,
           SUM(AMOUNT)
    FROM #ArmyBudget
    WHERE RC IN ( 'AAEN' )
          AND MDEP IN ( 'FAAC', 'FARC', 'MS5Z' )
          AND BO = '4'
          AND OSDPE NOT IN ( '0902498A', '0808610A' )
    GROUP BY FY,
             APPN;
    INSERT INTO #POMData
    (
        ParameterName,
        Appropriation,
        FY,
        AmcosVersionId,
        Amount
    )
    SELECT 'Officer_Recruiters',
           APPN,
           FY,
           @AmcosVersionId,
           SUM(AMOUNT) AS Amount
    FROM #ArmyBudget
    WHERE RC IN ( 'AAOF' )
          AND MDEP IN ( 'FAAC', 'FARC', 'MS5Z' )
          AND BO = '4'
          AND OSDPE NOT IN ( '0902498A', '0808610A' )
    GROUP BY FY,
             APPN;
    INSERT INTO #POMData
    (
        ParameterName,
        Appropriation,
        FY,
        AmcosVersionId,
        Amount
    )
    SELECT 'Warrant_Recruiters',
           APPN,
           FY,
           @AmcosVersionId,
           SUM(AMOUNT)
    FROM #ArmyBudget
    WHERE RC IN ( 'AAWO' )
          AND MDEP IN ( 'FAAC', 'FARC', 'MS5Z' )
          AND BO = '4'
          AND OSDPE NOT IN ( '0902498A', '0808610A' )
    GROUP BY FY,
             APPN;

    -- =============================================
    --NG recruiting NGPA budget
    -- Concerns: NGPA doesn't have recruiting broken out, both RPA and NGPA are a little off from PB19
    -- =============================================
    INSERT INTO #POMData
    (
        ParameterName,
        Appropriation,
        FY,
        AmcosVersionId,
        Amount
    )
    SELECT 'Recruiting',
           APPN,
           FY,
           @AmcosVersionId,
           SUM(AMOUNT) * 1000
    FROM #ArmyBudget
    WHERE DOLLAR_TYPE LIKE 'BASE%'
          AND SAG = '1GN'
          AND BO = '1'
          AND APPN = 'RPA'
    GROUP BY FY,
             APPN;
    INSERT INTO #POMData
    (
        ParameterName,
        Appropriation,
        FY,
        AmcosVersionId,
        Amount
    )
    SELECT 'Retention',
           APPN,
           FY,
           @AmcosVersionId,
           SUM(AMOUNT) * 1000
    FROM #ArmyBudget
    WHERE DOLLAR_TYPE LIKE 'BASE%'
          AND SAG = '1GP'
          AND BO = '1'
          AND APPN = 'RPA'
    GROUP BY FY,
             APPN;

    --NGPA doesn't split out into retention and recruiting, they are one in the same
    INSERT INTO #POMData
    (
        ParameterName,
        Appropriation,
        FY,
        AmcosVersionId,
        Amount
    )
    SELECT 'Recruiting_Retention',
           APPN,
           FY,
           @AmcosVersionId,
           SUM(AMOUNT) * 1000
    FROM #ArmyBudget
    WHERE DOLLAR_TYPE LIKE 'BASE%'
          AND SAG = '1J0'
          AND BO = '1'
          AND APPN = 'NGPA'
    GROUP BY FY,
             APPN;

    -- =============================================
    -- Reserve Recruiting OMAR/OMNG budget
    -- =============================================
    INSERT INTO #POMData
    (
        ParameterName,
        Appropriation,
        FY,
        AmcosVersionId,
        Amount
    )
    --not sure why but the cast statement was necessary to get this query to work
    SELECT 'Recruiting',
           APPN,
           FY,
           @AmcosVersionId,
           SUM(AMOUNT) * 1000
    FROM #ArmyBudget
    WHERE DOLLAR_TYPE LIKE 'BASE%'
          AND CAST(SAG AS NVARCHAR(MAX)) = 434
          AND OSDPE IN ( '0508891A', '0508991A' )
          AND BO = '1'
          AND MDEP IN ( 'FARC', 'FAAC', 'VAMP' )
          AND APPN IN ( 'OMAR', 'OMNG' )
    GROUP BY FY,
             APPN;

    -- =============================================
    --USMA Military Staff
    --Discussion-there is no POM entry for this so we calculate based on manpower
    --Concerns-FY17 is just slightly off, the others are perfect
    -- =============================================
    INSERT INTO #POMData
    (
        ParameterName,
        Appropriation,
        FY,
        AmcosVersionId,
        Amount
    )
    SELECT 'Enlisted_USMA',
           APPN,
           FY,
           @AmcosVersionId,
           SUM(AMOUNT)
    FROM #ArmyBudget
    WHERE ROC = '171'
          AND MDEP NOT IN ( 'VPUB', 'QSEC' )
          AND RC = 'AAEN'
          AND BO = '4'
    GROUP BY FY,
             APPN;
    INSERT INTO #POMData
    (
        ParameterName,
        Appropriation,
        FY,
        AmcosVersionId,
        Amount
    )
    SELECT 'Officer_USMA',
           APPN,
           FY,
           @AmcosVersionId,
           SUM(AMOUNT)
    FROM #ArmyBudget
    WHERE ROC = '171'
          AND MDEP NOT IN ( 'VPUB', 'QSEC' )
          AND RC = 'AAOF'
          AND BO = '4'
    GROUP BY FY,
             APPN;
    INSERT INTO #POMData
    (
        ParameterName,
        Appropriation,
        FY,
        AmcosVersionId,
        Amount
    )
    SELECT 'Warrant_USMA',
           APPN,
           FY,
           @AmcosVersionId,
           SUM(AMOUNT)
    FROM #ArmyBudget
    WHERE ROC = '171'
          AND MDEP NOT IN ( 'VPUB', 'QSEC' )
          AND RC = 'AAWO'
          AND BO = '4'
    GROUP BY FY,
             APPN;

    -- =============================================
    --USMA OMA
    -- =============================================
    INSERT INTO #POMData
    (
        ParameterName,
        Appropriation,
        FY,
        AmcosVersionId,
        Amount
    )
    SELECT 'USMA',
           APPN,
           FY,
           @AmcosVersionId,
           SUM(AMOUNT) * 1000
    FROM #ArmyBudget
    WHERE DOLLAR_TYPE LIKE 'BASE%'
          AND MDEP IN ( 'USMA' )
          AND BO = '1'
          AND APPN = 'OMA'
    GROUP BY FY,
             APPN;

    -- =============================================
    --USMA MPA
    -- =============================================
    INSERT INTO #POMData
    (
        ParameterName,
        Appropriation,
        FY,
        AmcosVersionId,
        Amount
    )
    SELECT 'USMA',
           APPN,
           FY,
           @AmcosVersionId,
           SUM(AMOUNT) * 1000
    FROM #ArmyBudget
    WHERE DOLLAR_TYPE LIKE 'BASE%'
          AND BA = '03'
          AND BO = '1'
          AND APPN = 'MPA'
    GROUP BY FY,
             APPN;

    -- =============================================
    --NGOCS NGPA
    -- =============================================
    INSERT INTO #POMData
    (
        ParameterName,
        Appropriation,
        FY,
        AmcosVersionId,
        Amount
    )
    SELECT 'NGOCS',
           APPN,
           FY,
           @AmcosVersionId,
           SUM(AMOUNT) * 1000
    FROM #ArmyBudget
    WHERE DOLLAR_TYPE LIKE 'BASE%'
          AND SAG = '1F5'
          AND BO = '1'
          AND APPN = 'NGPA'
    GROUP BY FY,
             APPN;

    -- =============================================
    --NGOCS OMNG
    -- =============================================
    INSERT INTO #POMData
    (
        ParameterName,
        Appropriation,
        FY,
        AmcosVersionId,
        Amount
    )
    SELECT 'NGOCS',
           APPN,
           FY,
           @AmcosVersionId,
           SUM(AMOUNT) * 1000
    FROM #ArmyBudget
    WHERE DOLLAR_TYPE LIKE 'BASE%'
          AND MDEP IN ( 'TAOC', 'TROC' )
          --3/15/2023 TAOC was eliminated and all funds moved to TROC
          --TROC and TAOC did not overlap so no need to differentiate this by versionid
          AND BO = '1'
          AND APPN = 'OMNG'
    GROUP BY FY,
             APPN;

    -- =============================================
    --ROTC Scholarship MPA
    -- =============================================
    INSERT INTO #POMData
    (
        ParameterName,
        Appropriation,
        FY,
        AmcosVersionId,
        Amount
    )
    SELECT 'ROTC_Scholarship',
           APPN,
           FY,
           @AmcosVersionId,
           SUM(AMOUNT) * 1000
    FROM #ArmyBudget
    WHERE DOLLAR_TYPE LIKE 'BASE%'
          AND SAG = '6PB'
          AND BO = '1'
          AND APPN = 'MPA'
    GROUP BY FY,
             APPN;

    -- =============================================
    --ROTC NonScholarship MPA
    -- =============================================
    INSERT INTO #POMData
    (
        ParameterName,
        Appropriation,
        FY,
        AmcosVersionId,
        Amount
    )
    SELECT 'ROTC_NonScholarship',
           APPN,
           FY,
           @AmcosVersionId,
           SUM(AMOUNT) * 1000
    FROM #ArmyBudget
    WHERE DOLLAR_TYPE LIKE 'BASE%'
          AND SAG = '6PA'
          AND BO = '1'
          AND APPN = 'MPA'
    GROUP BY FY,
             APPN;

    -- =============================================
    --ROTC OMA
    -- =============================================
    INSERT INTO #POMData
    (
        ParameterName,
        Appropriation,
        FY,
        AmcosVersionId,
        Amount
    )
    SELECT 'ROTC',
           APPN,
           FY,
           @AmcosVersionId,
           SUM(AMOUNT) * 1000
    FROM #ArmyBudget
    WHERE DOLLAR_TYPE LIKE 'BASE%'
          AND MDEP = 'TROT'
          AND BO = '1'
          AND APPN = 'OMA'
    GROUP BY FY,
             APPN;

    -- =============================================
    --ROTC Scholarship OMA
    -- =============================================
    INSERT INTO #POMData
    (
        ParameterName,
        Appropriation,
        FY,
        AmcosVersionId,
        Amount
    )
    SELECT 'ROTC_Scholarship',
           APPN,
           FY,
           @AmcosVersionId,
           SUM(AMOUNT) * 1000
    FROM #ArmyBudget
    WHERE DOLLAR_TYPE LIKE 'BASE%'
          AND MDEP = 'TRRS'
          AND BO = '1'
          AND APPN = 'OMA'
    GROUP BY FY,
             APPN;

    -- =============================================
    --ROTC Military Staff
    --Discussion-there is no POM entry for this so we calculate based on manpower
    --Concerns-FY17 is just slightly off, the others are perfect
    -- =============================================
    INSERT INTO #POMData
    (
        ParameterName,
        Appropriation,
        FY,
        AmcosVersionId,
        Amount
    )
    SELECT 'Enlisted_ROTC',
           APPN,
           FY,
           @AmcosVersionId,
           SUM(AMOUNT)
    FROM #ArmyBudget
    WHERE MDEP IN ( 'TROT' )
          AND RC = 'AAEN'
          AND BO = '4'
    GROUP BY FY,
             APPN;
    INSERT INTO #POMData
    (
        ParameterName,
        Appropriation,
        FY,
        AmcosVersionId,
        Amount
    )
    SELECT 'Officer_ROTC',
           APPN,
           FY,
           @AmcosVersionId,
           SUM(AMOUNT)
    FROM #ArmyBudget
    WHERE MDEP IN ( 'TROT' )
          AND RC = 'AAOF'
          AND BO = '4'
    GROUP BY FY,
             APPN;
    INSERT INTO #POMData
    (
        ParameterName,
        Appropriation,
        FY,
        AmcosVersionId,
        Amount
    )
    SELECT 'Warrant_ROTC',
           APPN,
           FY,
           @AmcosVersionId,
           SUM(AMOUNT)
    FROM #ArmyBudget
    WHERE MDEP IN ( 'TROT' )
          AND RC = 'AAWO'
          AND BO = '4'
    GROUP BY FY,
             APPN;

    -- =============================================
    --Active Training Costs
    --SAGs based on what FCoM is pulling less the ofc acq ones
    -- =============================================
    INSERT INTO #POMData
    (
        ParameterName,
        Appropriation,
        FY,
        AmcosVersionId,
        Amount
    )
    SELECT 'Training-OSUT',
           APPN,
           FY,
           @AmcosVersionId,
           SUM(AMOUNT) * 1000
    FROM #ArmyBudget
    WHERE DOLLAR_TYPE LIKE 'BASE%'
          AND SAG IN ( '313' )
          AND BO = '1'
    GROUP BY FY,
             APPN;
    INSERT INTO #POMData
    (
        ParameterName,
        Appropriation,
        FY,
        AmcosVersionId,
        Amount
    )
    SELECT 'Training-Recruit',
           APPN,
           FY,
           @AmcosVersionId,
           SUM(AMOUNT) * 1000
    FROM #ArmyBudget
    WHERE DOLLAR_TYPE LIKE 'BASE%'
          AND SAG IN ( '312' )
          AND BO = '1'
    GROUP BY FY,
             APPN;
    INSERT INTO #POMData
    (
        ParameterName,
        Appropriation,
        FY,
        AmcosVersionId,
        Amount
    )
    SELECT 'Training-Specialized Skill',
           APPN,
           FY,
           @AmcosVersionId,
           SUM(AMOUNT) * 1000
    FROM #ArmyBudget
    WHERE DOLLAR_TYPE LIKE 'BASE%'
          AND SAG IN ( '321' )
          AND BO = '1'
    GROUP BY FY,
             APPN;
    INSERT INTO #POMData
    (
        ParameterName,
        Appropriation,
        FY,
        AmcosVersionId,
        Amount
    )
    SELECT 'Training-Professional Development Education',
           APPN,
           FY,
           @AmcosVersionId,
           SUM(AMOUNT) * 1000
    FROM #ArmyBudget
    WHERE DOLLAR_TYPE LIKE 'BASE%'
          AND SAG IN ( '323' )
          AND BO = '1'
    GROUP BY FY,
             APPN;
    INSERT INTO #POMData
    (
        ParameterName,
        Appropriation,
        FY,
        AmcosVersionId,
        Amount
    )
    SELECT 'Training-Flight',
           APPN,
           FY,
           @AmcosVersionId,
           SUM(AMOUNT) * 1000
    FROM #ArmyBudget
    WHERE DOLLAR_TYPE LIKE 'BASE%'
          AND SAG IN ( '322' )
          AND BO = '1'
    GROUP BY FY,
             APPN;
    INSERT INTO #POMData
    (
        ParameterName,
        Appropriation,
        FY,
        AmcosVersionId,
        Amount
    )
    SELECT 'Training-Support',
           APPN,
           FY,
           @AmcosVersionId,
           SUM(AMOUNT) * 1000
    FROM #ArmyBudget
    WHERE DOLLAR_TYPE LIKE 'BASE%'
          AND SAG IN ( '324' )
          AND BO = '1'
    GROUP BY FY,
             APPN;

    -- =============================================
    --Reserve & NG OM & PA Training Costs
    --SAGs based on what FCoM is pulling less the ofc acq ones
    -- =============================================
    INSERT INTO #POMData
    (
        ParameterName,
        Appropriation,
        FY,
        AmcosVersionId,
        Amount
    )
    SELECT 'Training-IET',
           APPN,
           FY,
           @AmcosVersionId,
           SUM(AMOUNT) * 1000
    FROM #ArmyBudget
    WHERE DOLLAR_TYPE LIKE 'BASE%'
          AND MDEP IN ( 'PRTF' )
          AND APPN IN ( 'OMAR', 'OMNG', 'NGPA', 'RPA' )
          AND BO = '1'
          AND @AmcosVersionId < 202301 -- some training specific mdeps were collapsed in 2023 so switching to a generalized mdep approach
    GROUP BY FY,
             APPN;
    INSERT INTO #POMData
    (
        ParameterName,
        Appropriation,
        FY,
        AmcosVersionId,
        Amount
    )
    SELECT 'Training-Professional',
           APPN,
           FY,
           @AmcosVersionId,
           SUM(AMOUNT) * 1000
    FROM #ArmyBudget
    WHERE DOLLAR_TYPE LIKE 'BASE%'
          AND MDEP IN ( 'TRNC', 'TRPD' )
          AND APPN IN ( 'OMAR', 'OMNG', 'NGPA', 'RPA' )
          AND BO = '1'
          AND @AmcosVersionId < 202301 -- some training specific mdeps were collapsed in 2023 so switching to a generalized mdep approach
    GROUP BY FY,
             APPN;
    INSERT INTO #POMData
    (
        ParameterName,
        Appropriation,
        FY,
        AmcosVersionId,
        Amount
    )
    SELECT 'Training-Special Skills Training',
           APPN,
           FY,
           @AmcosVersionId,
           SUM(AMOUNT) * 1000
    FROM #ArmyBudget
    WHERE DOLLAR_TYPE LIKE 'BASE%'
          AND MDEP IN ( 'TFNC' )
          AND APPN IN ( 'OMAR', 'OMNG', 'NGPA', 'RPA' )
          AND BO = '1'
          AND @AmcosVersionId < 202301 -- some training specific mdeps were collapsed in 2023 so switching to a generalized mdep approach
    GROUP BY FY,
             APPN;
    INSERT INTO #POMData
    (
        ParameterName,
        Appropriation,
        FY,
        AmcosVersionId,
        Amount
    )
    SELECT 'Training-Support',
           APPN,
           FY,
           @AmcosVersionId,
           SUM(AMOUNT) * 1000
    FROM #ArmyBudget
    WHERE DOLLAR_TYPE LIKE 'BASE%'
          AND MDEP IN ( 'TAVI', 'TSPU', 'TRCS' )
          AND APPN IN ( 'OMAR', 'OMNG', 'NGPA', 'RPA' )
          AND BO = '1'
          AND @AmcosVersionId < 202301 -- some training specific mdeps were collapsed in 2023 so switching to a generalized mdep approach
    GROUP BY FY,
             APPN;
    INSERT INTO #POMData
    (
        ParameterName,
        Appropriation,
        FY,
        AmcosVersionId,
        Amount
    )
    SELECT 'Training-Initial SKills',
           APPN,
           FY,
           @AmcosVersionId,
           SUM(AMOUNT) * 1000
    FROM #ArmyBudget
    WHERE DOLLAR_TYPE LIKE 'BASE%'
          AND MDEP IN ( 'TRIT' )
          AND APPN IN ( 'OMAR', 'OMNG', 'NGPA', 'RPA' )
          AND BO = '1'
          AND @AmcosVersionId < 202301 -- some training specific mdeps were collapsed in 2023 so switching to a generalized mdep approach
    GROUP BY FY,
             APPN;
    INSERT INTO #POMData
    (
        ParameterName,
        Appropriation,
        FY,
        AmcosVersionId,
        Amount
    )
    SELECT 'Training-MOS Qualification',
           APPN,
           FY,
           @AmcosVersionId,
           SUM(AMOUNT) * 1000
    FROM #ArmyBudget
    WHERE DOLLAR_TYPE LIKE 'BASE%'
          AND MDEP IN ( 'TRNM' )
          AND APPN IN ( 'OMAR', 'OMNG', 'NGPA', 'RPA' )
          AND BO = '1'
          AND @AmcosVersionId < 202301 -- some training specific mdeps were collapsed in 2023 so switching to a generalized mdep approach
    GROUP BY FY,
             APPN;

    -- TRNM mdep was collapsed into TROC in 2023 so we added the new SV below
    INSERT INTO #POMData
    (
        ParameterName,
        Appropriation,
        FY,
        AmcosVersionId,
        Amount
    )
    SELECT 'General Training',
           APPN,
           FY,
           @AmcosVersionId,
           SUM(AMOUNT) * 1000
    FROM #ArmyBudget
    WHERE DOLLAR_TYPE LIKE 'BASE%'
          AND MDEP IN ( 'TROC', 'TRIT', 'PRTF', 'PRSA' )
          AND APPN IN ( 'OMAR', 'OMNG', 'NGPA', 'RPA' )
          AND BO = '1'
          AND @AmcosVersionId >= 202301
    GROUP BY FY,
             APPN;

    -- =============================================
    --Avg O & E end strength
    -- =============================================
    INSERT INTO #POMData
    (
        ParameterName,
        Appropriation,
        FY,
        AmcosVersionId,
        Amount
    )
    SELECT 'Avg_OE_End_Strength',
           APPN,
           FY,
           @AmcosVersionId,
           SUM(AMOUNT)
    FROM #ArmyBudget
    WHERE BO = '4'
          AND APPN = 'MPA'
    GROUP BY FY,
             APPN;

    -- =============================================
    --Avg AO end strength
    -- =============================================
    INSERT INTO #POMData
    (
        ParameterName,
        Appropriation,
        FY,
        AmcosVersionId,
        Amount
    )
    SELECT 'Avg_AO_End_Strength',
           APPN,
           FY,
           @AmcosVersionId,
           SUM(AMOUNT)
    FROM #ArmyBudget
    WHERE BO = '4'
          AND APPN = 'MPA'
          AND RC = 'AAOF'
    GROUP BY FY,
             APPN;

    -- =============================================
    --Avg AE end strength
    -- =============================================
    INSERT INTO #POMData
    (
        ParameterName,
        Appropriation,
        FY,
        AmcosVersionId,
        Amount
    )
    SELECT 'Avg_AE_End_Strength',
           APPN,
           FY,
           @AmcosVersionId,
           SUM(AMOUNT)
    FROM #ArmyBudget
    WHERE BO = '4'
          AND APPN = 'MPA'
          AND RC = 'AAEN'
    GROUP BY FY,
             APPN;


    -- =============================================
    --Avg AWO end strength
    -- =============================================
    INSERT INTO #POMData
    (
        ParameterName,
        Appropriation,
        FY,
        AmcosVersionId,
        Amount
    )
    SELECT 'Avg_AWO_End_Strength',
           APPN,
           FY,
           @AmcosVersionId,
           SUM(AMOUNT)
    FROM #ArmyBudget
    WHERE BO = '4'
          AND APPN = 'MPA'
          AND RC = 'AAWO'
    GROUP BY FY,
             APPN;


    -- =============================================
    --Tot_MWR_Cost
    -- =============================================
    INSERT INTO #POMData
    (
        ParameterName,
        Appropriation,
        FY,
        AmcosVersionId,
        Amount
    )
    SELECT 'MoraleWelfareRecreation',
           APPN,
           FY,
           @AmcosVersionId,
           SUM(AMOUNT) * 1000
    FROM #ArmyBudget
    WHERE DOLLAR_TYPE LIKE 'BASE%'
          AND SAG = '131'
          AND BO = '1'
          AND APPN = 'OMA'
          AND OSDPE = '0208530A'
    GROUP BY FY,
             APPN;

    -- =============================================
    --PCS_ConusOverseas_30_Dep_Not_Auth
    -- =============================================
    INSERT INTO #POMData
    (
        ParameterName,
        Appropriation,
        FY,
        AmcosVersionId,
        Amount
    )
    SELECT 'PCS_ConusOverseas_30_Dep_Not_Auth',
           APPN,
           FY,
           @AmcosVersionId,
           SUM(AMOUNT) * 1000
    FROM #ArmyBudget
    WHERE DOLLAR_TYPE LIKE 'BASE%'
          AND SAG IN ( '2RB', '1RB' )
          AND BO = '1'
          AND APPN = 'MPA'
    GROUP BY FY,
             APPN;

    -- =============================================
    --PCS_Operational_Move_Budget
    -- =============================================
    INSERT INTO #POMData
    (
        ParameterName,
        Appropriation,
        FY,
        AmcosVersionId,
        Amount
    )
    SELECT 'Enlisted_PCS_Operational_Move_Budget',
           APPN,
           FY,
           @AmcosVersionId,
           SUM(AMOUNT) * 1000
    FROM #ArmyBudget
    WHERE DOLLAR_TYPE LIKE 'BASE%'
          AND SAG LIKE '5C%'
          AND APE_PT_DESC LIKE '%Enlisted%'
          AND BO = '1'
          AND APPN = 'MPA'
    GROUP BY FY,
             APPN;
    INSERT INTO #POMData
    (
        ParameterName,
        Appropriation,
        FY,
        AmcosVersionId,
        Amount
    )
    SELECT 'Officer_PCS_Operational_Move_Budget',
           APPN,
           FY,
           @AmcosVersionId,
           SUM(AMOUNT) * 1000
    FROM #ArmyBudget
    WHERE DOLLAR_TYPE LIKE 'BASE%'
          AND SAG LIKE '5C%'
          AND APE_PT_DESC LIKE '%Officer%'
          AND BO = '1'
          AND APPN = 'MPA'
    GROUP BY FY,
             APPN;
    -- =============================================
    --PCS_Rotational_Move_Budget
    -- =============================================
    INSERT INTO #POMData
    (
        ParameterName,
        Appropriation,
        FY,
        AmcosVersionId,
        Amount
    )
    SELECT 'Enlisted_PCS_Rotational_Move_Budget',
           APPN,
           FY,
           @AmcosVersionId,
           SUM(AMOUNT) * 1000
    FROM #ArmyBudget
    WHERE DOLLAR_TYPE LIKE 'BASE%'
          AND APE_PT_DESC LIKE '%Enlisted%'
          AND SAG LIKE '5D%'
          AND BO = '1'
          AND APPN = 'MPA'
    GROUP BY FY,
             APPN;
    INSERT INTO #POMData
    (
        ParameterName,
        Appropriation,
        FY,
        AmcosVersionId,
        Amount
    )
    SELECT 'Officer_PCS_Rotational_Move_Budget',
           APPN,
           FY,
           @AmcosVersionId,
           SUM(AMOUNT) * 1000
    FROM #ArmyBudget
    WHERE DOLLAR_TYPE LIKE 'BASE%'
          AND SAG LIKE '5D%'
          AND APE_PT_DESC LIKE '%Officer%'
          AND BO = '1'
          AND APPN = 'MPA'
    GROUP BY FY,
             APPN;
    -- =============================================
    --PCS_Separation_Move_Budget
    -- =============================================
    INSERT INTO #POMData
    (
        ParameterName,
        Appropriation,
        FY,
        AmcosVersionId,
        Amount
    )
    SELECT 'Enlisted_PCS_Separation_Move_Budget',
           APPN,
           FY,
           @AmcosVersionId,
           SUM(AMOUNT) * 1000
    FROM #ArmyBudget
    WHERE DOLLAR_TYPE LIKE 'BASE%'
          AND SAG LIKE '5E%'
          AND APE_PT_DESC LIKE '%Enlisted%'
          AND BO = '1'
          AND APPN = 'MPA'
    GROUP BY FY,
             APPN;
    INSERT INTO #POMData
    (
        ParameterName,
        Appropriation,
        FY,
        AmcosVersionId,
        Amount
    )
    SELECT 'Officer_PCS_Separation_Move_Budget',
           APPN,
           FY,
           @AmcosVersionId,
           SUM(AMOUNT) * 1000
    FROM #ArmyBudget
    WHERE DOLLAR_TYPE LIKE 'BASE%'
          AND SAG LIKE '5E%'
          AND APE_PT_DESC LIKE '%Officer%'
          AND BO = '1'
          AND APPN = 'MPA'
    GROUP BY FY,
             APPN;


    -- =============================================
    --Family Separation Budget
    -- =============================================
    INSERT INTO #POMData
    (
        ParameterName,
        Appropriation,
        FY,
        AmcosVersionId,
        Amount
    )
    SELECT 'Enlisted_Family_Separation',
           APPN,
           FY,
           @AmcosVersionId,
           SUM(AMOUNT) * 1000
    FROM #ArmyBudget
    WHERE DOLLAR_TYPE LIKE 'BASE%'
          AND SAG IN ( '2RD', '2RB' )
          AND BO = '1'
          AND APPN = 'MPA'
    GROUP BY FY,
             APPN;

    INSERT INTO #POMData
    (
        ParameterName,
        Appropriation,
        FY,
        AmcosVersionId,
        Amount
    )
    SELECT 'Officer_Warrant_Family_Separation',
           APPN,
           FY,
           @AmcosVersionId,
           SUM(AMOUNT) * 1000
    FROM #ArmyBudget
    WHERE DOLLAR_TYPE LIKE 'BASE%'
          AND SAG IN ( '1RB', '1RD' )
          AND BO = '1'
          AND APPN = 'MPA'
    GROUP BY FY,
             APPN;


    -- =============================================
    -- Terminal Leave Pay Budget
    -- =============================================
    INSERT INTO #POMData
    (
        ParameterName,
        Appropriation,
        FY,
        AmcosVersionId,
        Amount
    )
    SELECT 'Officer_Warrant_Leave_pay',
           APPN,
           FY,
           @AmcosVersionId,
           SUM(AMOUNT) * 1000
    FROM #ArmyBudget
    WHERE DOLLAR_TYPE LIKE 'BASE%'
          AND SAG IN ( '1SA' )
          AND BO = '1'
          AND APPN = 'MPA'
    GROUP BY FY,
             APPN;

    INSERT INTO #POMData
    (
        ParameterName,
        Appropriation,
        FY,
        AmcosVersionId,
        Amount
    )
    SELECT 'Enlisted_Leave_Pay',
           APPN,
           FY,
           @AmcosVersionId,
           SUM(AMOUNT) * 1000
    FROM #ArmyBudget
    WHERE DOLLAR_TYPE LIKE 'BASE%'
          AND SAG IN ( '2SA' )
          AND BO = '1'
          AND APPN = 'MPA'
    GROUP BY FY,
             APPN;

    -- =============================================
    -- Voluntary Separation Budget
    -- =============================================
    INSERT INTO #POMData
    (
        ParameterName,
        Appropriation,
        FY,
        AmcosVersionId,
        Amount
    )
    SELECT 'Officer_Warrant_Voluntary_Separation',
           APPN,
           FY,
           @AmcosVersionId,
           SUM(AMOUNT) * 1000
    FROM #ArmyBudget
    WHERE DOLLAR_TYPE LIKE 'BASE%'
          AND SAG IN ( '1SJ' )
          AND BO = '1'
          AND APPN = 'MPA'
    GROUP BY FY,
             APPN;

    INSERT INTO #POMData
    (
        ParameterName,
        Appropriation,
        FY,
        AmcosVersionId,
        Amount
    )
    SELECT 'Enlisted_Voluntary_Separation',
           APPN,
           FY,
           @AmcosVersionId,
           SUM(AMOUNT) * 1000
    FROM #ArmyBudget
    WHERE DOLLAR_TYPE LIKE 'BASE%'
          AND SAG IN ( '2SJ' )
          AND BO = '1'
          AND APPN = 'MPA'
    GROUP BY FY,
             APPN;


    -- =============================================
    --Involuntary Separation Budget
    -- =============================================
    INSERT INTO #POMData
    (
        ParameterName,
        Appropriation,
        FY,
        AmcosVersionId,
        Amount
    )
    SELECT 'Officer_Warrant_Involuntary_Separation',
           APPN,
           FY,
           @AmcosVersionId,
           SUM(AMOUNT) * 1000
    FROM #ArmyBudget
    WHERE DOLLAR_TYPE LIKE 'BASE%'
          AND SAG IN ( '1SH' )
          AND BO = '1'
          AND APPN = 'MPA'
    GROUP BY FY,
             APPN;

    INSERT INTO #POMData
    (
        ParameterName,
        Appropriation,
        FY,
        AmcosVersionId,
        Amount
    )
    SELECT 'Enlisted_Involuntary_Separation',
           APPN,
           FY,
           @AmcosVersionId,
           SUM(AMOUNT) * 1000
    FROM #ArmyBudget
    WHERE DOLLAR_TYPE LIKE 'BASE%'
          AND SAG IN ( '2SH', '2SG' )
          AND BO = '1'
          AND APPN = 'MPA'
    GROUP BY FY,
             APPN;

    -- =============================================
    --PCS_Training_Move_Budget
    -- =============================================
    INSERT INTO #POMData
    (
        ParameterName,
        Appropriation,
        FY,
        AmcosVersionId,
        Amount
    )
    SELECT 'Enlisted_PCS_Training_Move_Budget',
           APPN,
           FY,
           @AmcosVersionId,
           SUM(AMOUNT) * 1000
    FROM #ArmyBudget
    WHERE DOLLAR_TYPE LIKE 'BASE%'
          AND SAG LIKE '5B%'
          AND APE_PT_DESC LIKE '%Enlisted%'
          AND APPN = 'MPA'
          AND BO = '1'
    GROUP BY FY,
             APPN;
    INSERT INTO #POMData
    (
        ParameterName,
        Appropriation,
        FY,
        AmcosVersionId,
        Amount
    )
    SELECT 'Officer_PCS_Training_Move_Budget',
           APPN,
           FY,
           @AmcosVersionId,
           SUM(AMOUNT) * 1000
    FROM #ArmyBudget
    WHERE DOLLAR_TYPE LIKE 'BASE%'
          AND SAG LIKE '5B%'
          AND APE_PT_DESC LIKE '%Officer%'
          AND APPN = 'MPA'
          AND BO = '1'
    GROUP BY FY,
             APPN;

    -- =============================================
    --PCS_Unit_Move_Budget
    -- =============================================
    INSERT INTO #POMData
    (
        ParameterName,
        Appropriation,
        FY,
        AmcosVersionId,
        Amount
    )
    SELECT 'Enlisted_PCS_Unit_Move_Budget',
           APPN,
           FY,
           @AmcosVersionId,
           SUM(AMOUNT) * 1000
    FROM #ArmyBudget
    WHERE DOLLAR_TYPE LIKE 'BASE%'
          AND SAG LIKE '5F%'
          AND APE_PT_DESC LIKE '%Enlisted%'
          AND APPN = 'MPA'
          AND BO = '1'
    GROUP BY FY,
             APPN;
    INSERT INTO #POMData
    (
        ParameterName,
        Appropriation,
        FY,
        AmcosVersionId,
        Amount
    )
    SELECT 'Officer_PCS_Unit_Move_Budget',
           APPN,
           FY,
           @AmcosVersionId,
           SUM(AMOUNT) * 1000
    FROM #ArmyBudget
    WHERE DOLLAR_TYPE LIKE 'BASE%'
          AND SAG LIKE '5F%'
          AND APE_PT_DESC LIKE '%Officer%'
          AND APPN = 'MPA'
          AND BO = '1'
    GROUP BY FY,
             APPN;

    -- =============================================
    --Severence_Pay
    -- =============================================
    INSERT INTO #POMData
    (
        ParameterName,
        Appropriation,
        FY,
        AmcosVersionId,
        Amount
    )
    SELECT 'Enlisted_Severence_Pay',
           APPN,
           FY,
           @AmcosVersionId,
           SUM(AMOUNT) * 1000
    FROM #ArmyBudget
    WHERE DOLLAR_TYPE LIKE 'BASE%'
          AND APE = '2S2E00000'
          AND BO = '1'
          AND APPN = 'MPA'
    GROUP BY FY,
             APPN;
    INSERT INTO #POMData
    (
        ParameterName,
        Appropriation,
        FY,
        AmcosVersionId,
        Amount
    )
    SELECT 'Officer_Severence_Pay',
           APPN,
           FY,
           @AmcosVersionId,
           SUM(AMOUNT) * 1000
    FROM #ArmyBudget
    WHERE DOLLAR_TYPE LIKE 'BASE%'
          AND SAG = '1SE'
          AND BO = '1'
          AND APPN = 'MPA'
    GROUP BY FY,
             APPN;

    -- =============================================
    --TDY_ConusOverseas_30_Dep_Not_Nearby
    -- =============================================
    INSERT INTO #POMData
    (
        ParameterName,
        Appropriation,
        FY,
        AmcosVersionId,
        Amount
    )
    SELECT 'TDY_ConusOverseas_30_Dep_Not_Nearby',
           APPN,
           FY,
           @AmcosVersionId,
           SUM(AMOUNT) * 1000
    FROM #ArmyBudget
    WHERE DOLLAR_TYPE IN ( 'BASE', 'MSUP' )
          AND APE = '2R2D00000'
          AND BO = '1'
          AND APPN = 'MPA'
    GROUP BY FY,
             APPN;

    -- =============================================
    --Tot_Bdgt_For_Overseas_Station_Allowance
    -- =============================================
    INSERT INTO #POMData
    (
        ParameterName,
        Appropriation,
        FY,
        AmcosVersionId,
        Amount
    )
    SELECT 'Tot_Bdgt_For_Overseas_Station_Allowance',
           APPN,
           FY,
           @AmcosVersionId,
           SUM(AMOUNT) * 1000
    FROM #ArmyBudget
    WHERE DOLLAR_TYPE LIKE 'BASE%'
          AND APE IN ( '2P2C00000', '2P2A00000' )
          AND BO = '1'
          AND APPN = 'MPA'
    GROUP BY FY,
             APPN;

    -- =============================================
    --Enl_Bdgt_For OCONUS COLA OHA
    -- =============================================
    INSERT INTO #POMData
    (
        ParameterName,
        Appropriation,
        FY,
        AmcosVersionId,
        Amount
    )
    SELECT 'Enl_Bdgt_OCONUS_COLA_OHA',
           APPN,
           FY,
           @AmcosVersionId,
           SUM(AMOUNT) * 1000
    FROM #ArmyBudget
    WHERE DOLLAR_TYPE LIKE 'BASE%'
          AND APE IN ( '2H2F00000', '2H2G00000', '2P2A00000', '2P2C00000' )
          AND BO = '1'
          AND APPN = 'MPA'
    GROUP BY FY,
             APPN;

    -- =============================================
    --Officer & Warrant Bdgt_For_OCONUS COLA OHA
    -- =============================================

    INSERT INTO #POMData
    (
        ParameterName,
        Appropriation,
        FY,
        AmcosVersionId,
        Amount
    )
    SELECT 'AO_AWO_Bdgt_OCONUS_COLA_OHA',
           APPN,
           FY,
           @AmcosVersionId,
           SUM(AMOUNT) * 1000
    FROM #ArmyBudget
    WHERE DOLLAR_TYPE LIKE 'BASE%'
          AND APE IN ( '1H1F00000', '1H1G00000', '1P1A00000', '1P1C00000' )
          AND BO = '1'
          AND APPN = 'MPA'
    GROUP BY FY,
             APPN;

    -- =============================================
    --Officer & Warrant Bdgt_For_CONUS COLA OHA
    -- =============================================

    INSERT INTO #POMData
    (
        ParameterName,
        Appropriation,
        FY,
        AmcosVersionId,
        Amount
    )
    SELECT 'AO_AWO_Bdgt_CONUS_COLA',
           APPN,
           FY,
           @AmcosVersionId,
           SUM(AMOUNT) * 1000
    FROM #ArmyBudget
    WHERE DOLLAR_TYPE LIKE 'BASE%'
          AND APE IN ( '1U1000000' )
          AND BO = '1'
          AND APPN = 'MPA'
    GROUP BY FY,
             APPN;

    -- =============================================
    --Enlisted & Warrant Bdgt_For_CONUS COLA OHA
    -- =============================================

    INSERT INTO #POMData
    (
        ParameterName,
        Appropriation,
        FY,
        AmcosVersionId,
        Amount
    )
    SELECT 'AE_Bdgt_CONUS_COLA',
           APPN,
           FY,
           @AmcosVersionId,
           SUM(AMOUNT) * 1000
    FROM #ArmyBudget
    WHERE DOLLAR_TYPE LIKE 'BASE%'
          AND APE IN ( '2U2000000' )
          AND BO = '1'
          AND APPN = 'MPA'
    GROUP BY FY,
             APPN;
    -- =============================================
    --Separation Pay, Non-Disability, Active Officer
    -- =============================================
    INSERT INTO #POMData
    (
        ParameterName,
        Appropriation,
        FY,
        AmcosVersionId,
        Amount
    )
    SELECT 'Officer_Sep_Pay_NonDis',
           APPN,
           FY,
           @AmcosVersionId,
           SUM(AMOUNT) * 1000
    FROM #ArmyBudget
    WHERE DOLLAR_TYPE LIKE 'BASE%'
          AND APE IN ( '1S1J00000', '1S1N00000', '1S1A00000', '1S1H00000', '1S1L00000' )
          AND BO = '1'
          AND BA = '01'
          AND APPN = 'MPA'
    GROUP BY FY,
             APPN;

    -- =============================================
    --Temp Duty > 30 Days w/Dep Not Near TD Station, Active Officers
    -- =============================================
    INSERT INTO #POMData
    (
        ParameterName,
        Appropriation,
        FY,
        AmcosVersionId,
        Amount
    )
    SELECT 'Officer_TDY_30_Plus_Days_wDeps_Not_Near_Stn',
           APPN,
           FY,
           @AmcosVersionId,
           SUM(AMOUNT) * 1000
    FROM #ArmyBudget
    WHERE DOLLAR_TYPE IN ( 'BASE', 'MSUP' )
          AND SAG = '1RD'
          AND BO = '1'
          AND APPN = 'MPA'
    GROUP BY FY,
             APPN;

    -- =============================================
    --Basic Benefit Chapters 1606 + 1607
    -- =============================================
    INSERT INTO #POMData
    (
        ParameterName,
        Appropriation,
        FY,
        AmcosVersionId,
        Amount
    )
    SELECT 'NE_Basic_Benefit',
           APPN,
           FY,
           @AmcosVersionId,
           SUM(AMOUNT) * 1000
    FROM #ArmyBudget
    WHERE DOLLAR_TYPE LIKE 'BASE%'
          AND APE = '1K33A2000'
          AND BO = '1'
          AND APPN = 'NGPA'
    GROUP BY FY,
             APPN;
    INSERT INTO #POMData
    (
        ParameterName,
        Appropriation,
        FY,
        AmcosVersionId,
        Amount
    )
    SELECT 'RE_Basic_Benefit',
           APPN,
           FY,
           @AmcosVersionId,
           SUM(AMOUNT) * 1000
    FROM #ArmyBudget
    WHERE DOLLAR_TYPE LIKE 'BASE%'
          AND APE = '1S3300000'
          AND BO = '1'
          AND APPN = 'RPA'
    GROUP BY FY,
             APPN;

    -- =============================================
    --Clothing 
    -- =============================================








    INSERT INTO #POMData
    (
        ParameterName,
        Appropriation,
        FY,
        AmcosVersionId,
        Amount
    )
    SELECT 'NE_Clothing',
           APPN,
           FY,
           @AmcosVersionId,
           SUM(AMOUNT) * 1000
    FROM #ArmyBudget
    WHERE DOLLAR_TYPE LIKE 'BASE%'
          AND
          (
              APE_PT_DESC LIKE '%clothing%'
              AND APE_PT_DESC LIKE '%enl%'
          )
          AND BO = '1'
          AND APPN = 'NGPA'
    GROUP BY FY,
             APPN;

    INSERT INTO #POMData
    (
        ParameterName,
        Appropriation,
        FY,
        AmcosVersionId,
        Amount
    )
    SELECT 'RE_Clothing',
           APPN,
           FY,
           @AmcosVersionId,
           SUM(AMOUNT) * 1000
    FROM #ArmyBudget
    WHERE DOLLAR_TYPE LIKE 'BASE%'
          AND
          (
              APE_PT_DESC LIKE '%clothing%'
              AND APE_PT_DESC LIKE '%enlisted%'
              AND APE_PT_DESC NOT LIKE '%agr%'
          )
          AND BO = '1'
          AND APPN = 'RPA'
    GROUP BY FY,
             APPN;

    INSERT INTO #POMData
    (
        ParameterName,
        Appropriation,
        FY,
        AmcosVersionId,
        Amount
    )
    SELECT 'RO_RWO_Clothing',
           APPN,
           FY,
           @AmcosVersionId,
           SUM(AMOUNT) * 1000
    FROM #ArmyBudget
    WHERE DOLLAR_TYPE LIKE 'BASE%'
          AND
          (
              APE_PT_DESC LIKE '%clothing%'
              AND APE_PT_DESC LIKE '%officer%'
          )
          AND APE_PT_DESC NOT LIKE '%AGR%'
          AND BO = '1'
          AND APPN = 'RPA'
    GROUP BY FY,
             APPN;

    INSERT INTO #POMData
    (
        ParameterName,
        Appropriation,
        FY,
        AmcosVersionId,
        Amount
    )
    SELECT 'NO_NWO_Clothing',
           APPN,
           FY,
           @AmcosVersionId,
           SUM(AMOUNT) * 1000
    FROM #ArmyBudget
    WHERE DOLLAR_TYPE LIKE 'BASE%'
          AND
          (
              APE_PT_DESC LIKE '%clothing%'
              AND APE_PT_DESC LIKE '%off%'
          )
          AND BO = '1'
          AND APPN = 'NGPA'
    GROUP BY FY,
             APPN;


    INSERT INTO #POMData
    (
        ParameterName,
        Appropriation,
        FY,
        AmcosVersionId,
        Amount
    )
    SELECT 'AE_Clothing',
           APPN,
           FY,
           @AmcosVersionId,
           SUM(AMOUNT) * 1000
    FROM #ArmyBudget
    WHERE DOLLAR_TYPE LIKE 'BASE%'
          AND APE IN ( '2Q2A10A20', '2Q2A10A10', '2Q2B10200', '2Q2B20100', '2Q2B20200', '2Q2B10100', '2Q2C00000',
                       '2Q2Z20000', '2Q2Z40000', '2Q2Z30000'
                     )
          AND BO = '1'
          AND APPN = 'MPA'
    GROUP BY FY,
             APPN;


    INSERT INTO #POMData
    (
        ParameterName,
        Appropriation,
        FY,
        AmcosVersionId,
        Amount
    )
    SELECT 'AO_AWO_Clothing',
           APPN,
           FY,
           @AmcosVersionId,
           SUM(AMOUNT) * 1000
    FROM #ArmyBudget
    WHERE DOLLAR_TYPE LIKE 'BASE%'
          AND APE IN ( '1Q1A10000', '1Q1B10000' )
          AND BO = '1'
          AND APPN = 'MPA'
    GROUP BY FY,
             APPN;



    -- =============================================
    --Eductional Benefit, Kicker (Ch 160
    -- =============================================
    INSERT INTO #POMData
    (
        ParameterName,
        Appropriation,
        FY,
        AmcosVersionId,
        Amount
    )
    SELECT 'NE_Edu_Kicker',
           APPN,
           FY,
           @AmcosVersionId,
           SUM(AMOUNT) * 1000
    FROM #ArmyBudget
    WHERE DOLLAR_TYPE LIKE 'BASE%'
          AND SAG = '1K3'
          AND BO = '1'
          AND APPN = 'NGPA'
    GROUP BY FY,
             APPN;
    INSERT INTO #POMData
    (
        ParameterName,
        Appropriation,
        FY,
        AmcosVersionId,
        Amount
    )
    SELECT 'RE_Edu_Kicker',
           APPN,
           FY,
           @AmcosVersionId,
           SUM(AMOUNT) * 1000
    FROM #ArmyBudget
    WHERE DOLLAR_TYPE LIKE 'BASE%'
          AND SAG = '1S7'
          AND BO = '1'
          AND APPN = 'RPA'
    GROUP BY FY,
             APPN;

    -- =============================================
    --Student Loan Repayment
    -- =============================================
    INSERT INTO #POMData
    (
        ParameterName,
        Appropriation,
        FY,
        AmcosVersionId,
        Amount
    )
    SELECT 'NE_Student_Loan_Repayment',
           APPN,
           FY,
           @AmcosVersionId,
           SUM(AMOUNT) * 1000
    FROM #ArmyBudget
    WHERE DOLLAR_TYPE LIKE 'BASE%'
          AND APE = '1R33A2000'
          AND BO = '1'
          AND APPN = 'NGPA'
    GROUP BY FY,
             APPN;
    INSERT INTO #POMData
    (
        ParameterName,
        Appropriation,
        FY,
        AmcosVersionId,
        Amount
    )
    SELECT 'RE_Student_Loan_Repayment',
           APPN,
           FY,
           @AmcosVersionId,
           SUM(AMOUNT) * 1000
    FROM #ArmyBudget
    WHERE DOLLAR_TYPE LIKE 'BASE%'
          AND APE = '1R33V0000'
          AND BO = '1'
          AND APPN = 'RPA'
    GROUP BY FY,
             APPN;

    -- =============================================
    --Disability & Hospitilization, Death Gratuities (DHDG), NE
    -- =============================================
    INSERT INTO #POMData
    (
        ParameterName,
        Appropriation,
        FY,
        AmcosVersionId,
        Amount
    )
    SELECT 'NE_DHDG',
           APPN,
           FY,
           @AmcosVersionId,
           SUM(AMOUNT) * 1000
    FROM #ArmyBudget
    WHERE DOLLAR_TYPE LIKE 'BASE%'
          AND APE IN ( '1T3102000', '1U3112000' )
          AND BO = '1'
          AND APPN = 'NGPA'
    GROUP BY FY,
             APPN;
    INSERT INTO #POMData
    (
        ParameterName,
        Appropriation,
        FY,
        AmcosVersionId,
        Amount
    )
    SELECT 'RE_DHDG',
           APPN,
           FY,
           @AmcosVersionId,
           SUM(AMOUNT) * 1000
    FROM #ArmyBudget
    WHERE DOLLAR_TYPE LIKE 'BASE%'
          AND APE IN ( '1T3300000', '1U3300000' )
          AND APPN = 'RPA'
          AND BO = '1'
    GROUP BY FY,
             APPN;
    INSERT INTO #POMData
    (
        ParameterName,
        Appropriation,
        FY,
        AmcosVersionId,
        Amount
    )
    SELECT 'NO_NWO_DHDG',
           APPN,
           FY,
           @AmcosVersionId,
           SUM(AMOUNT) * 1000
    FROM #ArmyBudget
    WHERE DOLLAR_TYPE LIKE 'BASE%'
          AND APE IN ( '1T1102000', '1U1112000' )
          AND BO = '1'
          AND APPN = 'NGPA'
    GROUP BY FY,
             APPN;
    INSERT INTO #POMData
    (
        ParameterName,
        Appropriation,
        FY,
        AmcosVersionId,
        Amount
    )
    SELECT 'RO_RWO_DHDG',
           APPN,
           FY,
           @AmcosVersionId,
           SUM(AMOUNT) * 1000
    FROM #ArmyBudget
    WHERE DOLLAR_TYPE LIKE 'BASE%'
          AND APE IN ( '1U1300000', '1T1300000' )
          AND BO = '1'
          AND APPN = 'RPA'
    GROUP BY FY,
             APPN;

    -- =============================================
    --End Strength
    -- =============================================
    INSERT INTO #POMData
    (
        ParameterName,
        Appropriation,
        FY,
        AmcosVersionId,
        Amount
    )
    SELECT 'NE_Endstrength',
           APPN,
           FY,
           @AmcosVersionId,
           SUM(AMOUNT)
    FROM #ArmyBudget
    WHERE BO = '4'
          AND APPN = 'NGPA'
          AND RC IN ( 'GEPD', 'GEPP', 'GEST', 'GPGF' )
    GROUP BY FY,
             APPN;
    INSERT INTO #POMData
    (
        ParameterName,
        Appropriation,
        FY,
        AmcosVersionId,
        Amount
    )
    SELECT 'RE_Endstrength',
           APPN,
           FY,
           @AmcosVersionId,
           SUM(AMOUNT)
    FROM #ArmyBudget
    WHERE BO = '4'
          AND APPN = 'RPA'
          AND RC LIKE 'RE%'
    GROUP BY FY,
             APPN;
    INSERT INTO #POMData
    (
        ParameterName,
        Appropriation,
        FY,
        AmcosVersionId,
        Amount
    )
    SELECT 'NO_NWO_Endstrength',
           APPN,
           FY,
           @AmcosVersionId,
           SUM(AMOUNT)
    FROM #ArmyBudget
    WHERE BO = '4'
          AND APPN = 'NGPA'
          AND RC IN ( 'GOPD', 'GOST', 'GWPD', 'GWST' )
    GROUP BY FY,
             APPN;
    INSERT INTO #POMData
    (
        ParameterName,
        Appropriation,
        FY,
        AmcosVersionId,
        Amount
    )
    SELECT 'RO_RWO_Endstrength',
           APPN,
           FY,
           @AmcosVersionId,
           SUM(AMOUNT)
    FROM #ArmyBudget
    WHERE BO = '4'
          AND APPN = 'RPA'
          AND RC IN ( 'ROMA', 'RODP', 'ROST', 'RWMA', 'RWPD', 'RWST' )
    GROUP BY FY,
             APPN;

    -- =============================================
    --Misc Benefits (Apprehension of MIL Deserters, AWOL, Prisoners + Interest on Savings, Enlisted + Death Gratuities, Enlisted + Unemployment Compensation Benefits)
    -- =============================================
    INSERT INTO #POMData
    (
        ParameterName,
        Appropriation,
        FY,
        AmcosVersionId,
        Amount
    )
    SELECT 'AE_Misc',
           APPN,
           FY,
           @AmcosVersionId,
           SUM(AMOUNT) * 1000
    FROM #ArmyBudget
    WHERE DOLLAR_TYPE LIKE 'BASE%'
          AND APE IN ( '6A0000000', '6B2000000', '6C2000000', '6D0000000' )
          AND BO = '1'
          AND APPN = 'MPA'
    GROUP BY FY,
             APPN;

    -- =============================================
    --Total Other Military Personnel Costs

    -- =============================================
    INSERT INTO #POMData
    (
        ParameterName,
        Appropriation,
        FY,
        AmcosVersionId,
        Amount
    )
    SELECT 'AO_Misc',
           APPN,
           FY,
           @AmcosVersionId,
           SUM(AMOUNT) * 1000
    FROM #ArmyBudget
    WHERE DOLLAR_TYPE LIKE 'BASE%'
          AND SAG IN ( '6DA', '6QA', '6KA', '6CA', '6HA', '6AA', '6GA', '6BA', '6JA' )
          AND BO = '1'
          AND APPN = 'MPA'
          AND APE_PT_DESC NOT LIKE '%enl%'
    GROUP BY FY,
             APPN;



    --Amort of Education Benefits
    --3/17/2023 discovered this single value is no longer being used so we just comment it out
    /*
    INSERT INTO #POMData
    (
        ParameterName,
        Appropriation,
        FY,
        AmcosVersionId,
        Amount
    )
    SELECT 'Edu_Benefits_amort',
           APPN,
           FY,
           @AmcosVersionId,
           SUM(AMOUNT) * 1000
    FROM #ArmyBudget
    WHERE DOLLAR_TYPE LIKE 'BASE%'
          AND SAG = '6HA'
          AND BO = '1'
          AND APPN = 'MPA'
    GROUP BY FY,
             APPN;
             */

    /* Officer Domestic Basic Allowance for Housing Budget */
    INSERT INTO #POMData
    (
        ParameterName,
        Appropriation,
        FY,
        AmcosVersionId,
        Amount
    )
    SELECT 'BAH_Domestic_AO_AWO',
           APPN,
           FY,
           @AmcosVersionId,
           SUM(AMOUNT * 1000) AS Amount
    FROM #ArmyBudget
    WHERE DOLLAR_TYPE LIKE 'BASE%'
          AND APPN = 'MPA'
          AND SAG IN ( '1HE', '1HC', '1HA', '1HB' )
          AND BO = '1'
    GROUP BY APPN,
             FY;

    /* Officer Overseas Basic Allowance for Housing Budget */
    INSERT INTO #POMData
    (
        ParameterName,
        Appropriation,
        FY,
        AmcosVersionId,
        Amount
    )
    SELECT 'BAH_Overseas_AO_AWO',
           APPN,
           FY,
           @AmcosVersionId,
           SUM(AMOUNT * 1000) AS Amount
    FROM #ArmyBudget
    WHERE DOLLAR_TYPE LIKE 'BASE%'
          AND APPN = 'MPA'
          AND SAG IN ( '1HF', '1HG' )
          AND BO = '1'
    GROUP BY APPN,
             FY;

    /* Enlisted Domestic Basic Allowance for Housing Budget */
    INSERT INTO #POMData
    (
        ParameterName,
        Appropriation,
        FY,
        AmcosVersionId,
        Amount
    )
    SELECT 'BAH_Domestic_AE',
           APPN,
           FY,
           @AmcosVersionId,
           SUM(AMOUNT * 1000) AS Amount
    FROM #ArmyBudget
    WHERE DOLLAR_TYPE LIKE 'BASE%'
          AND APPN = 'MPA'
          AND SAG IN ( '2HE', '2HC', '2HA', '2HB' )
          AND BO = '1'
    GROUP BY APPN,
             FY;

    -- =============================================
    --Enlisted Overseas Basic Allowance for Housing Budget
    -- =============================================
    INSERT INTO #POMData
    (
        ParameterName,
        Appropriation,
        FY,
        AmcosVersionId,
        Amount
    )
    SELECT 'BAH_Oveseas_AE',
           APPN,
           FY,
           @AmcosVersionId,
           SUM(AMOUNT * 1000) AS Amount
    FROM #ArmyBudget
    WHERE DOLLAR_TYPE LIKE 'BASE%'
          AND APPN = 'MPA'
          AND SAG IN ( '2HF', '2HG' )
          AND BO = '1'
    GROUP BY APPN,
             FY;

    -- =============================================
    --Officer Domestic Basic Allowance for Subsistence Budget
    -- =============================================
    INSERT INTO #POMData
    (
        ParameterName,
        Appropriation,
        FY,
        AmcosVersionId,
        Amount
    )
    SELECT 'BAS_Domestic_AO_AWO',
           APPN,
           FY,
           @AmcosVersionId,
           SUM(AMOUNT * 1000) AS Amount
    FROM #ArmyBudget
    WHERE DOLLAR_TYPE LIKE 'BASE%'
          AND APPN = 'MPA'
          AND SAG IN ( '1KA' )
          AND BO = '1'
    GROUP BY APPN,
             FY;

    -- =============================================
    --Enlisted Domestic Basic Allowance for Subsistence Budget
    -- =============================================
    INSERT INTO #POMData
    (
        ParameterName,
        Appropriation,
        FY,
        AmcosVersionId,
        Amount
    )
    SELECT 'BAS_Domestic_AE',
           APPN,
           FY,
           @AmcosVersionId,
           SUM(AMOUNT * 1000) AS Amount
    FROM #ArmyBudget
    WHERE DOLLAR_TYPE LIKE 'BASE%'
          AND APPN = 'MPA'
          AND BA = '04'
          AND BO = '1'
    GROUP BY APPN,
             FY;

    /* Compute average values */
    INSERT INTO #POMData
    (
        ParameterName,
        Appropriation,
        FY,
        AmcosVersionId,
        Amount
    )
    SELECT ParameterName,
           Appropriation,
           'Avg' AS FY,
           AmcosVersionId,
           AVG(Amount)
    FROM #POMData
    GROUP BY ParameterName,
             Appropriation,
             AmcosVersionId;
    IF @Debug = 1
    BEGIN
        SELECT ParameterName,
               Appropriation,
               FY,
               AmcosVersionId,
               Amount
        FROM #POMData
        ORDER BY ParameterName,
                 Appropriation,
                 FY,
                 AmcosVersionId;
    END;
    IF @Debug = 0
    BEGIN
        DELETE FROM crunch.ArmyBudgetSingleValues
        WHERE AmcosVersionId = @AmcosVersionId;
        INSERT INTO crunch.ArmyBudgetSingleValues
        (
            ParameterName,
            Appropriation,
            FY,
            AmcosVersionId,
            Amount
        )
        SELECT ParameterName,
               Appropriation,
               FY,
               AmcosVersionId,
               Amount
        FROM #POMData;
    END;
END;