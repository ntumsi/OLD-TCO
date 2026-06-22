
CREATE PROCEDURE [crunch].[CrunchWS]
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
              AND PayPlan = 'WS'
    )
        RETURN 0;

    CREATE TABLE #tblCosts
    (
        PayPlan NVARCHAR(3),
        WageArea NVARCHAR(3),
        CostElementId INT,
        GradeType VARCHAR(3),
        GradeLevel INT,
        Amount FLOAT,
        CrunchTime SMALLDATETIME NULL
    );

    --DECLARE @tbl_Annual_Salaries table (GradeType varchar(4), GradeLevel int, Step int, Rate_Annual float, PRIMARY KEY(GradeType,GradeLevel,Step))
    --INSERT INTO @tbl_Annual_Salaries
    --     SELECT  tblPay.GradeType, tblPay.GradeLevel, tblPay.Step_YOS, tblPay.Rate * 2087.000 AS Rate_Annual
    --       FROM (SELECT Rate, GradeType, GradeLevel, Step_YOS FROM data.PaySchedules WHERE (PayPlan = @PayPlan) AND (TableNumber_Area = @WageArea)) tblPay 
    -- INNER JOIN (SELECT GradeType, GradeLevel, YOS FROM data.Inventory WHERE (PayPlan = @PayPlan) AND [Group] = @WageArea GROUP BY GradeType, GradeLevel, YOS) tblInv 
    --         ON tblPay.GradeType = tblInv.GradeType
    --        AND tblPay.GradeLevel = tblInv.GradeLevel 
    --        AND tblPay.Step_YOS = tblInv.YOS;

    --DECLARE @tbl_Avg_Annual_Salaries table (GradeType varchar(4), GradeLevel int, AvgRateAnnual float, PRIMARY KEY(GradeType,GradeLevel))
    --INSERT INTO @tbl_Avg_Annual_Salaries
    --     SELECT GradeType, GradeLevel, AVG(Rate_Annual) AS AvgRateAnnual
    --       FROM @tbl_Annual_Salaries
    --   GROUP BY GradeType,GradeLevel;

    -- 4/25/2013 Change to calculate Weighted Average by Inventory values.
    DECLARE @tbl_Annual_Salaries TABLE
    (
        GradeType VARCHAR(4),
        GradeLevel INT,
        Step INT,
        InvCount INT,
        Rate_Annual FLOAT
    );
    DECLARE @tbl_Avg_Annual_Salaries TABLE
    (
        GradeType VARCHAR(4),
        GradeLevel INT,
        AvgRateAnnual FLOAT
    );
    INSERT INTO @tbl_Annual_Salaries
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
        WHERE (PayPlan = 'WS')
              AND (WageArea = @WageArea)
    ) tblPay
        INNER JOIN
        (
            SELECT GradeType,
                   GradeLevel,
                   Step_YOS,
                   Inventory AS InvCount
            FROM data.Inventory
            WHERE (PayPlan = 'WS')
                  AND WageArea = @WageArea
        ) tblInv
            ON tblPay.GradeType = tblInv.GradeType
               AND tblPay.GradeLevel = tblInv.GradeLevel
               AND tblPay.Step_YOS = tblInv.Step_YOS;

    INSERT INTO @tbl_Avg_Annual_Salaries
    SELECT GradeType,
           GradeLevel,
           SUM(InvCount * Rate_Annual) / SUM(InvCount) AS AvgRateAnnual
    FROM @tbl_Annual_Salaries
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
    WHERE PayPlan = 'WS'
          AND paramName = 'FEGHI';

    /* Insert Cost factors into table */

    -- Military Compensation 
    -- Avg Cost of Base Pay (Civilian)
    INSERT INTO #tblCosts
    (
        CostElementId,
        GradeType,
        GradeLevel,
        Amount
    )
    SELECT 642,
           GradeType,
           GradeLevel,
           AvgRateAnnual
    FROM @tbl_Avg_Annual_Salaries;

    -- Avg Cost of Premium Pay
    INSERT INTO #tblCosts
    (
        CostElementId,
        GradeType,
        GradeLevel,
        Amount
    )
    SELECT 643,
           GradeType,
           GradeLevel,
           (AvgRateAnnual * @Prem) AS Prem
    FROM @tbl_Avg_Annual_Salaries;

    -- No Average Cost of OverTime Pay 
    -- No Average Cost of Holiday Pay 

    -- Other Benefits 
    -- Average Cost of Federal Employees Gov't Life Insurance 
    INSERT INTO #tblCosts
    (
        CostElementId,
        GradeType,
        GradeLevel,
        Amount
    )
    SELECT 645,
           GradeType,
           GradeLevel,
           (AvgRateAnnual * @FEGLI) AS FEGLI
    FROM @tbl_Avg_Annual_Salaries;

    -- Average Cost of Federal Employees Gov't Health Insurance 
    INSERT INTO #tblCosts
    (
        CostElementId,
        GradeType,
        GradeLevel,
        Amount
    )
    SELECT 644,
           GradeType,
           GradeLevel,
           @FEGHI AS FEGHI
    FROM @tbl_Avg_Annual_Salaries;

    -- Average Cost of Miscellaneous Pay 
    INSERT INTO #tblCosts
    (
        CostElementId,
        GradeType,
        GradeLevel,
        Amount
    )
    SELECT 646,
           GradeType,
           GradeLevel,
           (AvgRateAnnual * @Misc) AS Misc
    FROM @tbl_Avg_Annual_Salaries;

    -- Retired Pay Accurual 
    -- Government-Funded Retirement 
    --INSERT INTO #tblCosts (CostElementId, GradeType, GradeLevel, Amount ) 
    --   --SELECT 634, GradeType, GradeLevel, (AvgRateAnnual * @GovRet) AS GovRet  FROM @tbl_Avg_Annual_Salaries; -- 7/7/2014 changed below
    --     SELECT 634, GradeType, GradeLevel, @GovRet					AS GovRet  FROM @tbl_Avg_Annual_Salaries; -- 7/21/2014 replaced by the following 2 elements
    INSERT INTO #tblCosts
    (
        CostElementId,
        GradeType,
        GradeLevel,
        Amount
    )
    SELECT 996,
           GradeType,
           GradeLevel,
           @PostRetLifeIns
    FROM @tbl_Avg_Annual_Salaries;
    INSERT INTO #tblCosts
    (
        CostElementId,
        GradeType,
        GradeLevel,
        Amount
    )
    SELECT 997,
           GradeType,
           GradeLevel,
           @PostRetHealthIns
    FROM @tbl_Avg_Annual_Salaries;

    INSERT INTO #tblCosts
    (
        CostElementId,
        GradeType,
        GradeLevel,
        Amount
    )
    SELECT 991,
           GradeType,
           GradeLevel,
           @CashAwards * AvgRateAnnual
    FROM @tbl_Avg_Annual_Salaries;

    INSERT INTO #tblCosts
    (
        CostElementId,
        GradeType,
        GradeLevel,
        Amount
    )
    SELECT 992,
           GradeType,
           GradeLevel,
           @FICA * (AvgRateAnnual + AvgRateAnnual * @CashAwards + AvgRateAnnual * @Prem)
    FROM @tbl_Avg_Annual_Salaries;

    UPDATE #tblCosts
    SET Amount = @FICA * @SocialSecurityUpperLimit
    WHERE CostElementId = 992
          AND Amount > @FICA * @SocialSecurityUpperLimit;

    INSERT INTO #tblCosts
    (
        CostElementId,
        GradeType,
        GradeLevel,
        Amount
    )
    SELECT 993,
           GradeType,
           GradeLevel,
           @FormerEmp * AvgRateAnnual
    FROM @tbl_Avg_Annual_Salaries;

    -- Average Cost of Army-Funded Retirement 
    INSERT INTO #tblCosts
    (
        CostElementId,
        GradeType,
        GradeLevel,
        Amount
    )
    SELECT 647,
           GradeType,
           GradeLevel,
           (AvgRateAnnual * @ArmyRet) AS ArmyRet
    FROM @tbl_Avg_Annual_Salaries;

    -- OSD CAPE DODI: Training @ $867.60
    INSERT INTO #tblCosts
    (
        CostElementId,
        GradeType,
        GradeLevel,
        Amount
    )
    SELECT 749,
           GradeType,
           GradeLevel,
           @Training --  7/7/2014
    FROM @tbl_Avg_Annual_Salaries;


    UPDATE #tblCosts
    SET PayPlan = 'WS',
        WageArea = @WageArea;

    SELECT PayPlan,
           WageArea,
           CostElementId,
           GradeType,
           GradeLevel,
           Amount,
           CONVERT(SMALLDATETIME, GETDATE()) AS CrunchTime
    FROM #tblCosts
    WHERE CostElementId IS NOT NULL;

    DROP TABLE #tblCosts;
END;