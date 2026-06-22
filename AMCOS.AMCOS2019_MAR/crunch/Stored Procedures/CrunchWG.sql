
CREATE PROCEDURE [crunch].[CrunchWG]
    @WageArea NVARCHAR(3),
    @AmcosVersionId INT = -1
AS /*
Description: Calculate Average Cost factors for the Civilian Wage Board (WG,WL,WS) Employees
      Input: PayPlan, Area, Type of Summary(Default, Pay Allowance, CMORE), Type of Display (Costs, Summary, Totals)
      Ouput: Recordset
    Created: 03/20/2003
 Created By: RBP III  
    Revised:
*/
BEGIN

    SET NOCOUNT ON;

    DECLARE @IsValidAmcosVersion BIT = crunch.ValidateAmcosVersion(@AmcosVersionId);

    IF (@IsValidAmcosVersion = 0)
        RETURN 0;

    IF NOT EXISTS
    (
        SELECT WageArea
        FROM data.Inventory
        WHERE WageArea = @WageArea
              AND PayPlan = 'WG'
    )
    BEGIN
        RETURN 0;
    END;

    DECLARE @CrunchCosts TABLE
    (
        CostElementId INT NOT NULL,
        GradeType NVARCHAR(3) NOT NULL,
        GradeLevel TINYINT NOT NULL,
        Amount FLOAT NULL,
        CrunchTime SMALLDATETIME NULL
    );

    -- 4/25/2013 Change to calculate Weighted Average by Inventory values.
    DECLARE @AnnualSalaries TABLE
    (
        GradeType NVARCHAR(3) NOT NULL,
        GradeLevel TINYINT NOT NULL,
        Step INT NOT NULL,
        InvCount INT NOT NULL,
        Rate_Annual FLOAT NULL
    );
    INSERT INTO @AnnualSalaries
    SELECT tblPay.GradeType,
           tblPay.GradeLevel,
           tblPay.Step_YOS,
           Inventory.InvCount,
           tblPay.Rate * 2087.000 AS Rate_Annual
    FROM
    (
        SELECT Rate,
               GradeType,
               GradeLevel,
               Step_YOS
        FROM data.PaySchedules
        WHERE (PayPlan = 'WG')
              AND (WageArea = @WageArea)
    ) tblPay
        INNER JOIN
        (
            SELECT GradeType,
                   GradeLevel,
                   Step_YOS,
                   Inventory AS InvCount
            FROM data.Inventory
            WHERE (PayPlan = 'WG')
                  AND WageArea = @WageArea
        ) Inventory
            ON tblPay.GradeType = Inventory.GradeType
               AND tblPay.GradeLevel = Inventory.GradeLevel
               AND tblPay.Step_YOS = Inventory.Step_YOS;

    DECLARE @AverageAnnualSalaries TABLE
    (
        GradeType VARCHAR(4) NOT NULL,
        GradeLevel INT NOT NULL,
        AvgRateAnnual FLOAT NULL
    );
    INSERT INTO @AverageAnnualSalaries
    SELECT GradeType,
           GradeLevel,
           SUM(InvCount * Rate_Annual) / SUM(InvCount) AS AvgRateAnnual
    FROM @AnnualSalaries
    GROUP BY GradeType,
             GradeLevel;

    DECLARE @FICA FLOAT = crunch.GetSingleValue('AAw', 'FICA');
    DECLARE @SocialSecurityUpperLimit FLOAT = crunch.GetSingleValue('AA', 'SocialSecurityUpperLimit');
    DECLARE @PostRetHealthIns FLOAT = crunch.GetSingleValue('AA', 'PostRetHealthIns');
    DECLARE @PostRetLifeIns FLOAT = crunch.GetSingleValue('AA', 'PostRetLifeIns');
    DECLARE @Training FLOAT = crunch.GetSingleValue('AA', 'Training');
    DECLARE @ArmyRet FLOAT = crunch.GetSingleValue('AAw', 'ArmyRet');
    DECLARE @CashAwards FLOAT = crunch.GetSingleValue('AAw', 'CashAwards');
    DECLARE @FEGLI FLOAT = crunch.GetSingleValue('AAw', 'FEGLI');
    DECLARE @FormerEmp FLOAT = crunch.GetSingleValue('AAw', 'FormerEmp');
    DECLARE @Misc FLOAT = crunch.GetSingleValue('AAw', 'Misc');
    DECLARE @Prem FLOAT = crunch.GetSingleValue('AAw', 'Prem');
    DECLARE @FEGHI FLOAT = crunch.GetSingleValue('WG', 'FEGHI');

    -- Military Compensation 
    -- Avg Cost of Base Pay (Civilian)
    INSERT INTO @CrunchCosts
    (
        CostElementId,
        GradeType,
        GradeLevel,
        Amount
    )
    SELECT 628,
           GradeType,
           GradeLevel,
           AvgRateAnnual
    FROM @AverageAnnualSalaries;

    -- Avg Cost of Premium Pay
    INSERT INTO @CrunchCosts
    (
        CostElementId,
        GradeType,
        GradeLevel,
        Amount
    )
    SELECT 629,
           GradeType,
           GradeLevel,
           (AvgRateAnnual * @Prem) AS Prem
    FROM @AverageAnnualSalaries;

    -- No Average Cost of OverTime Pay 
    -- No Average Cost of Holiday Pay 

    -- Other Benefits 
    -- Average Cost of Federal Employees Gov't Life Insurance 
    INSERT INTO @CrunchCosts
    (
        CostElementId,
        GradeType,
        GradeLevel,
        Amount
    )
    SELECT 631,
           GradeType,
           GradeLevel,
           (AvgRateAnnual * @FEGLI) AS FEGLI
    FROM @AverageAnnualSalaries;

    -- Average Cost of Federal Employees Gov't Health Insurance 
    INSERT INTO @CrunchCosts
    (
        CostElementId,
        GradeType,
        GradeLevel,
        Amount
    )
    SELECT 630,
           GradeType,
           GradeLevel,
           @FEGHI AS FEGHI
    FROM @AverageAnnualSalaries;

    -- Average Cost of Miscellaneous Pay 
    INSERT INTO @CrunchCosts
    (
        CostElementId,
        GradeType,
        GradeLevel,
        Amount
    )
    SELECT 632,
           GradeType,
           GradeLevel,
           (AvgRateAnnual * @Misc) AS Misc
    FROM @AverageAnnualSalaries;

    -- Retired Pay Accurual 
    -- Government-Funded Retirement 
    --INSERT INTO @CrunchCosts (CostElementId, GradeType, GradeLevel, Amount ) 
    --   --SELECT 634, GradeType, GradeLevel, (AvgRateAnnual * @GovRet) AS GovRet  FROM @AverageAnnualSalaries; -- 7/7/2014 changed below
    --     SELECT 634, GradeType, GradeLevel, @GovRet					AS GovRet  FROM @AverageAnnualSalaries; -- 7/21/2014 replaced by the following 2 elements
    INSERT INTO @CrunchCosts
    (
        CostElementId,
        GradeType,
        GradeLevel,
        Amount
    )
    SELECT 976,
           GradeType,
           GradeLevel,
           @PostRetLifeIns
    FROM @AverageAnnualSalaries;
    INSERT INTO @CrunchCosts
    (
        CostElementId,
        GradeType,
        GradeLevel,
        Amount
    )
    SELECT 977,
           GradeType,
           GradeLevel,
           @PostRetHealthIns
    FROM @AverageAnnualSalaries;

    INSERT INTO @CrunchCosts
    (
        CostElementId,
        GradeType,
        GradeLevel,
        Amount
    )
    SELECT 971,
           GradeType,
           GradeLevel,
           @CashAwards * AvgRateAnnual
    FROM @AverageAnnualSalaries;

    INSERT INTO @CrunchCosts
    (
        CostElementId,
        GradeType,
        GradeLevel,
        Amount
    )
    SELECT 972,
           GradeType,
           GradeLevel,
           @FICA * (AvgRateAnnual + AvgRateAnnual * @CashAwards + AvgRateAnnual * @Prem)
    FROM @AverageAnnualSalaries;

    UPDATE @CrunchCosts
    SET Amount = @SocialSecurityUpperLimit * @FICA
    WHERE CostElementId = 972
          AND Amount > @SocialSecurityUpperLimit * @FICA;

    INSERT INTO @CrunchCosts
    (
        CostElementId,
        GradeType,
        GradeLevel,
        Amount
    )
    SELECT 973,
           GradeType,
           GradeLevel,
           @FormerEmp * AvgRateAnnual
    FROM @AverageAnnualSalaries;

    -- Average Cost of Army-Funded Retirement 
    INSERT INTO @CrunchCosts
    (
        CostElementId,
        GradeType,
        GradeLevel,
        Amount
    )
    SELECT 633,
           GradeType,
           GradeLevel,
           (AvgRateAnnual * @ArmyRet) AS ArmyRet
    FROM @AverageAnnualSalaries;

    -- OSD CAPE DODI: Training @ $867.60
    INSERT INTO @CrunchCosts
    (
        CostElementId,
        GradeType,
        GradeLevel,
        Amount
    )
    SELECT 756,
           GradeType,
           GradeLevel,
           @Training --  7/7/2014
    FROM @AverageAnnualSalaries;


    SELECT 'WG',
           @WageArea,
           CostElementId,
           GradeType,
           GradeLevel,
           Amount,
           CONVERT(SMALLDATETIME, GETDATE()) AS CrunchTime
    FROM @CrunchCosts
    WHERE CostElementId IS NOT NULL;

END;