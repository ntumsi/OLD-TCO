
CREATE PROCEDURE [crunch].[CrunchSES]
    @OccupationalGroupNumber NVARCHAR(4),
    @OccupationalSeriesNumber NVARCHAR(4),
    @AmcosVersionId INT = -1

/*
Description: Calculate Average Cost factors for the Civilian Supervisor General Schedule (SES)
    Created: 03/20/2003
 Created By: RBP III  
    Revised: 
*/
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @IsValidAmcosVersion BIT = crunch.ValidateAmcosVersion(@AmcosVersionId);

    IF (@IsValidAmcosVersion = 0)
        RETURN 0;

    DECLARE @CrunchCosts TABLE
    (
        CostElementId INT NOT NULL,
        GradeType NVARCHAR(3) NOT NULL,
        GradeLevel TINYINT NOT NULL,
        Amount FLOAT NULL,
        CrunchTime SMALLDATETIME NULL
    );

    DECLARE @tbl_Base_Pay TABLE
    (
        GradeType VARCHAR(4) NULL,
        GradeLevel INT NULL,
        BaseAnnual FLOAT NULL
    );
    -- Group and Collect Annual Salary by Grade 
    INSERT INTO @tbl_Base_Pay
    SELECT GradeType,
           GradeLevel,
           Rate
    FROM data.PaySchedules
    WHERE (OccupationalSeriesNumber = @OccupationalSeriesNumber)
          AND PayPlan = 'SES';

    DECLARE @FEGLI FLOAT = crunch.GetSingleValue('SES', 'FEGLI');
    DECLARE @ArmyRet FLOAT = crunch.GetSingleValue('SES', 'ArmyRet');
    DECLARE @CashAwards FLOAT = crunch.GetSingleValue('SES', 'CashAwards');
    DECLARE @FEGHI FLOAT = crunch.GetSingleValue('SES', 'FEGHI');
    DECLARE @Training FLOAT = crunch.GetSingleValue('AA', 'Training');
    DECLARE @FICA FLOAT = crunch.GetSingleValue('SES', 'FICA');
    DECLARE @PostRetLifeIns FLOAT = crunch.GetSingleValue('AA', 'PostRetLifeIns');
    DECLARE @PostRetHealthIns FLOAT = crunch.GetSingleValue('AA', 'PostRetHealthIns');

    /* Insert Cost factors into table */
    -- Military Compensation 
    -- Avg Cost of Base Pay (Civilian) 
    INSERT INTO @CrunchCosts
    (
        CostElementId,
        GradeType,
        GradeLevel,
        Amount
    )
    SELECT 616,
           GradeType,
           GradeLevel,
           BaseAnnual
    FROM @tbl_Base_Pay;

    -- Other Benefits 
    -- Average Cost of Federal Employees Gov't Life Insurance 
    INSERT INTO @CrunchCosts
    (
        CostElementId,
        GradeType,
        GradeLevel,
        Amount
    )
    SELECT 621,
           GradeType,
           GradeLevel,
           (BaseAnnual * @FEGLI) AS FEGLI
    FROM @tbl_Base_Pay;

    -- Average Cost of Federal Employees Gov't Health Insurance 
    INSERT INTO @CrunchCosts
    (
        CostElementId,
        GradeType,
        GradeLevel,
        Amount
    )
    SELECT 620,
           GradeType,
           GradeLevel,
           @FEGHI AS FEGHI
    FROM @tbl_Base_Pay;

    -- Adverage Cost of Cash Awards
    INSERT INTO @CrunchCosts
    (
        CostElementId,
        GradeType,
        GradeLevel,
        Amount
    )
    SELECT 619,
           GradeType,
           GradeLevel,
           (BaseAnnual * @CashAwards) AS CashAwards
    FROM @tbl_Base_Pay;

    -- Average Cost of Army-Funded Retirement 
    INSERT INTO @CrunchCosts
    (
        CostElementId,
        GradeType,
        GradeLevel,
        Amount
    )
    SELECT 625,
           GradeType,
           GradeLevel,
           (BaseAnnual * @ArmyRet) AS ArmyRet
    FROM @tbl_Base_Pay;

    -- New element: 902: SES, ARMY OMA	Training	Training.  10/3/2013
    INSERT INTO @CrunchCosts
    (
        CostElementId,
        GradeType,
        GradeLevel,
        Amount
    )
    SELECT 902,
           GradeType,
           GradeLevel,
           @Training
    FROM @tbl_Base_Pay;

    INSERT INTO @CrunchCosts
    (
        CostElementId,
        GradeType,
        GradeLevel,
        Amount
    )
    SELECT 961,
           GradeType,
           GradeLevel,
           @FICA * BaseAnnual * (1 + @CashAwards) AS Amount
    FROM @tbl_Base_Pay;
    UPDATE @CrunchCosts
    SET Amount = 9065.25
    WHERE CostElementId = 961
          AND Amount > 9065.25; --  capped at $9,065.25 for Maximum Wage Cap of $118,500

    INSERT INTO @CrunchCosts
    (
        CostElementId,
        GradeType,
        GradeLevel,
        Amount
    )
    SELECT 962,
           GradeType,
           GradeLevel,
           @PostRetLifeIns
    FROM @tbl_Base_Pay;
    INSERT INTO @CrunchCosts
    (
        CostElementId,
        GradeType,
        GradeLevel,
        Amount
    )
    SELECT 963,
           GradeType,
           GradeLevel,
           @PostRetHealthIns
    FROM @tbl_Base_Pay;


    SELECT 'SES',
           @OccupationalGroupNumber,
           @OccupationalSeriesNumber,
           CostElementId,
           GradeType,
           GradeLevel,
           Amount,
           CONVERT(SMALLDATETIME, GETDATE()) AS CrunchTime
    FROM @CrunchCosts;

END;