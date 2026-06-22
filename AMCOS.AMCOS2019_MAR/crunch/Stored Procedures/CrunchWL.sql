
CREATE PROCEDURE [crunch].[CrunchWL]
    @WageArea NVARCHAR(3),
    @AmcosVersionId INT = -1
AS
/*
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
              AND PayPlan = 'WL'
    )
        RETURN 0;

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
        InvCount INT NULL,
        Rate_Annual FLOAT NULL
    );
    DECLARE @AverageAnnualSalaries TABLE
    (
        GradeType NVARCHAR(3) NOT NULL,
        GradeLevel TINYINT,
        AvgRateAnnual FLOAT
    );
    INSERT INTO @AnnualSalaries
    SELECT tblPay.GradeType,
           tblPay.GradeLevel,
           tblPay.Step_YOS,
           InvCount,
           tblPay.Rate * 2087.000 AS Rate_Annual
    FROM
    (
        SELECT Rate,
               GradeType,
               GradeLevel,
               Step_YOS
        FROM data.PaySchedules
        WHERE (PayPlan = 'WL')
              AND (WageArea = @WageArea)
    ) tblPay
        INNER JOIN
        (
            SELECT GradeType,
                   GradeLevel,
                   Step_YOS,
                   Inventory AS InvCount
            FROM data.Inventory
            WHERE (PayPlan = 'WL')
                  AND WageArea = @WageArea
        ) tblInv
            ON tblPay.GradeType = tblInv.GradeType
               AND tblPay.GradeLevel = tblInv.GradeLevel
               AND tblPay.Step_YOS = tblInv.Step_YOS;

    INSERT INTO @AverageAnnualSalaries
    SELECT GradeType,
           GradeLevel,
           SUM(InvCount * Rate_Annual) / SUM(InvCount) AS AvgRateAnnual
    FROM @AnnualSalaries
    GROUP BY GradeType,
             GradeLevel;


    DECLARE @Prem FLOAT;
    DECLARE @Misc FLOAT;
    DECLARE @FEGLI FLOAT;
    DECLARE @ArmyRet FLOAT;
    DECLARE @FEGHI FLOAT;
    DECLARE @Training FLOAT;
    DECLARE @CashAwards FLOAT;
    DECLARE @FormerEmp FLOAT;
    DECLARE @PostRetLifeIns FLOAT;
    DECLARE @PostRetHealthIns FLOAT;

    DECLARE @FICA FLOAT = crunch.GetSingleValue('AAw', 'FICA');
    DECLARE @SocialSecurityUpperLimit FLOAT = crunch.GetSingleValue('AA', 'SocialSecurityUpperLimit');


    SELECT @PostRetHealthIns = paramValue
    FROM dataload.SingleValues
    WHERE PayPlan = 'AA'
          AND paramName = 'PostRetHealthIns';

    SELECT @PostRetLifeIns = paramValue
    FROM dataload.SingleValues
    WHERE PayPlan = 'AA'
          AND paramName = 'PostRetLifeIns';

    SELECT @Training = paramValue
    FROM dataload.SingleValues
    WHERE PayPlan = 'AA'
          AND paramName = 'Training';

    SELECT @ArmyRet = paramValue
    FROM dataload.SingleValues
    WHERE PayPlan = 'AAw'
          AND paramName = 'ArmyRet';

    SELECT @CashAwards = paramValue
    FROM dataload.SingleValues
    WHERE PayPlan = 'AAw'
          AND paramName = 'CashAwards';

    SELECT @FEGLI = paramValue
    FROM dataload.SingleValues
    WHERE PayPlan = 'AAw'
          AND paramName = 'FEGLI';

    SELECT @FormerEmp = paramValue
    FROM dataload.SingleValues
    WHERE PayPlan = 'AAw'
          AND paramName = 'FormerEmp';

    SELECT @Misc = paramValue
    FROM dataload.SingleValues
    WHERE PayPlan = 'AAw'
          AND paramName = 'Misc';

    SELECT @Prem = paramValue
    FROM dataload.SingleValues
    WHERE PayPlan = 'AAw'
          AND paramName = 'Prem';

    SELECT @FEGHI = paramValue
    FROM dataload.SingleValues
    WHERE PayPlan = 'WL'
          AND paramName = 'FEGHI';

    -- Military Compensation 
    -- Avg Cost of Base Pay (Civilian)
    INSERT INTO @CrunchCosts
    (
        CostElementId,
        GradeType,
        GradeLevel,
        Amount
    )
    SELECT 635,
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
    SELECT 636,
           GradeType,
           GradeLevel,
           (AvgRateAnnual * @Prem) AS Prem
    FROM @AverageAnnualSalaries;

    -- Other Benefits 
    -- Average Cost of Federal Employees Gov't Life Insurance 
    INSERT INTO @CrunchCosts
    (
        CostElementId,
        GradeType,
        GradeLevel,
        Amount
    )
    SELECT 638,
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
    SELECT 637,
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
    SELECT 639,
           GradeType,
           GradeLevel,
           (AvgRateAnnual * @Misc) AS Misc
    FROM @AverageAnnualSalaries;

    -- Retired Pay Accurual 
    -- Government-Funded Retirement 
    --INSERT INTO @CrunchCosts (CostElementId, GradeType, GradeLevel, Amount ) 
    --   --SELECT 634, GradeType, GradeLevel, (AvgRateAnnual * @GovRet) AS GovRet  FROM @tbl_Avg_Annual_Salaries; -- 7/7/2014 changed below
    --     SELECT 634, GradeType, GradeLevel, @GovRet					AS GovRet  FROM @tbl_Avg_Annual_Salaries; -- 7/21/2014 replaced by the following 2 elements
    INSERT INTO @CrunchCosts
    (
        CostElementId,
        GradeType,
        GradeLevel,
        Amount
    )
    SELECT 986,
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
    SELECT 987,
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
    SELECT 981,
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
    SELECT 982,
           GradeType,
           GradeLevel,
           @FICA * (AvgRateAnnual + AvgRateAnnual * @CashAwards + AvgRateAnnual * @Prem)
    FROM @AverageAnnualSalaries;

    UPDATE @CrunchCosts
    SET Amount = @FICA * @SocialSecurityUpperLimit
    WHERE CostElementId = 982
          AND Amount > @FICA * @SocialSecurityUpperLimit;

    INSERT INTO @CrunchCosts
    (
        CostElementId,
        GradeType,
        GradeLevel,
        Amount
    )
    SELECT 983,
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
    SELECT 640,
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
    SELECT 763,
           GradeType,
           GradeLevel,
           @Training
    FROM @AverageAnnualSalaries;

    SELECT 'WL',
           @WageArea,
           CostElementId,
           GradeType,
           GradeLevel,
           Amount,
           CONVERT(SMALLDATETIME, GETDATE()) AS CrunchTime
    FROM @CrunchCosts
    WHERE CostElementId IS NOT NULL;

END;