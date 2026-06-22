
-- =============================================
-- Author:Dan Hogan  
-- Create date: Oct 2018
-- Updates: 
--     Jan 2019 – moves conversions and payplan handling to ETL
-- Description:      Computes the average of DMDC pay data across the most recent 3 years
-- Dependencies: 
--      dmdc_pay
--      relies on ETL to properly process military conversions, see rejected table before running this crunch
-- =============================================
CREATE PROCEDURE [crunch].[DMDCPay]
    @AmcosVersionId INT = -1,
    @Debug AS BIT = 0
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @IsValidAmcosVersion BIT = crunch.ValidateAmcosVersion(@AmcosVersionId);

    IF (@IsValidAmcosVersion = 0)
        RETURN 0;

    CREATE TABLE #DMDCPayRaw
    (
        AmcosVersionId INT NOT NULL,
        FileDate NVARCHAR(10) NULL,
        PayPlan NVARCHAR(3) NULL,
        GradeType NVARCHAR(3) NULL,
        GradeLevel TINYINT NOT NULL,
        PayType NVARCHAR(300) NULL,
        PrimaryServiceOccupationCode NVARCHAR(20) NULL,
        [number_rcv] INT NULL,
        TotalPayAmount NUMERIC(18, 2) NULL,
        [inv_add] FLOAT NULL

    --,outlier BIT NOT NULL DEFAULT 0
    );


    INSERT INTO #DMDCPayRaw
    (
        AmcosVersionId,
        FileDate,
        PayPlan,
        GradeType,
        GradeLevel,
        PayType,
        PrimaryServiceOccupationCode,
        number_rcv,
        TotalPayAmount
    )
    SELECT AmcosVersionId,
           FileDate,
           PayPlan,
           GradeType,
           GradeLevel,
           PayType,
           PrimaryServiceOccupationCode,
           [Count] AS number_rcv,
           TotalPayAmount
    FROM DMDC.Pay
    WHERE AmcosVersionId IN
          (
              --get the most recent 3 years for a 3 year average
              --this was suggested by Mr Barth 10/2018 durign a review of the methodology
              --he wanted consistency/stability from year to year which a moving average should help with
              --note that we use AmcosVersionId parameter as this is a versioned SP and the dmdc_processed_pay table is versioned , e.g. you could call this SP to generate a prior AMCOS verison pay
              SELECT TOP (3)
                     AmcosVersionId
              FROM DMDC.Pay
              WHERE AmcosVersionId <= @AmcosVersionId
              GROUP BY AmcosVersionId
              ORDER BY AmcosVersionId DESC
          )
          AND
          (
              [Count] <> 0
              AND TotalPayAmount <> 0
          );
    /*
        --03/03/2022 - couldn't get this to work right so moved the code to the 
        --03/2/2022 in the 2022 update we found that 35A AO7 BAH has an unbelieveably high number of payments and amount thus requiring an outlier detection model
        --the below does just that based on a single value and is for now just for BAH
        --it works by computing an outlier over the payplan, GL, pay type and inventory; inventory is important because an outlier for 3 people is not the same as an outlier for say 1,000 people
        UPDATE #DMDCPayRaw SET outlier=1 FROM  #DMDCPayRaw AS a INNER JOIN 
    
    
        (
            SELECT * FROM 
            (
                SELECT a.*,b.inventory, PERCENTILE_cont(.99) WITHIN GROUP (ORDER BY TotalPayAmount) OVER (PARTITION BY a.payplan,a. gradelevel,a.PayType,b.inventory) AS pay_cap 
                FROM #DMDCPayRaw AS a inner JOIN 
                (
                    SELECT  payplan, CategorySubgroupCode,gradelevel, AmcosVersionId,SUM(inventory) AS inventory 
                    FROM data.inventory 
                    GROUP BY payplan, CategorySubgroupCode,gradelevel, AmcosVersionId
    
                ) AS b ON b.AmcosVersionId = a.AmcosVersionId AND b.GradeLevel = a.GradeLevel AND b.PayPlan = a.PayPlan AND a.PrimaryServiceOccupationCode=b.CategorySubgroupCode
                WHERE a.PayType IN ( 'Basic Allowance for Housing', 'Family Separation Housing BAH')
            ) AS A   WHERE pay_cap<TotalPayAmount
        ) AS B
        ON b.AmcosVersionId = a.AmcosVersionId AND b.GradeLevel = a.GradeLevel AND b.PayPlan = a.PayPlan 
        AND A.PrimaryServiceOccupationCode=B.PrimaryServiceOccupationCode AND A.PayType=B.PayType AND A.FileDate=B.FileDate
        */
    --IF @debug=1 
    --begin
    --	SELECT 'outliers being removed'
    --	SELECT * FROM #DMDCPayRaw WHERE outlier=1

    --end


    -- =============================================
    --Generate final table
    -- =============================================
    CREATE TABLE #DMDCPayFinal
    (
        PayType NVARCHAR(300) NULL,
        PayPlan NVARCHAR(3) NULL,
        CategoryGroupCode NVARCHAR(4) NULL,
        CategorySubgroupCode NVARCHAR(4) NULL,
        GradeType NVARCHAR(3) NULL,
        GradeLevel NVARCHAR(3) NULL,
        avg_3yr_pay NUMERIC(18, 2) NULL,
        avg_3yr_payments NUMERIC(18, 2) NULL,
        [Inventory] INT NULL,
        [avg_mpa_cost] NUMERIC(18, 2) NULL,
    );

    INSERT INTO #DMDCPayFinal
    (
        PayType,
        PayPlan,
        CategoryGroupCode,
        CategorySubgroupCode,
        GradeType,
        GradeLevel,
        avg_3yr_pay,
        avg_3yr_payments,
        Inventory,
        avg_mpa_cost
    )
    SELECT PayType,
           PayPlan,
           NULL AS CategoryGroupCode,
           PrimaryServiceOccupationCode,
           GradeType,
           GradeLevel,
           /* --2020 02 04 changed this from averaging 3 years of data to a sum / 3, this is to 'handle' years where no pay came in thus skewing a 3 year average
           AVG(avg_annual_pay) AS avg_3yr_pay,
           AVG(avg_annual_payments) AS avg_3yr_payments,
           */
           SUM(avg_annual_pay) / 3 AS avg_3yr_pay,
           SUM(avg_annual_payments * 1.0) / 3 AS avg_3yr_payments,
           NULL AS Inventory,
           0.0 AS avg_mpa_cost
    FROM
    (
        --aggregate up to annual figures before we average across years

        SELECT AmcosVersionId,
               PayType,
               PayPlan,
               NULL AS CategoryGroupCode,
               PrimaryServiceOccupationCode,
               GradeType,
               GradeLevel,
               SUM(TotalPayAmount) AS avg_annual_pay,
               SUM(number_rcv) AS avg_annual_payments,
               NULL AS Inventory,
               0.0 AS avg_mpa_cost
        FROM #DMDCPayRaw
        GROUP BY AmcosVersionId,
                 PayType,
                 PayPlan,
                 PrimaryServiceOccupationCode,
                 GradeType,
                 GradeLevel
    ) AS a
    GROUP BY PayType,
             PayPlan,
             PrimaryServiceOccupationCode,
             GradeType,
             GradeLevel;

    -- =============================================
    --Generate CMF
    -- =============================================
    --CMF is just the left two of sub group
    UPDATE #DMDCPayFinal
    SET CategoryGroupCode = LEFT(CategorySubgroupCode, 2);

    -- =============================================
    --bring in inventory
    -- =============================================
    --Bring in inventory for the subgroup matches
    --3/11/2021 - the following updated to bring in a 3 year moving inventory average per COR Marsha Popp to help stabalized the denominator to compliment our 3 year avg for the numerator
    UPDATE #DMDCPayFinal
    SET Inventory = MilitaryInventory.Inventory
    FROM #DMDCPayFinal AS a
        INNER JOIN
        (
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   GradeType,
                   GradeLevel,
                   AVG(Inventory * 1.00) AS Inventory
            FROM
            (
                SELECT PayPlan,
                       CategoryGroupCode,
                       CategorySubgroupCode,
                       GradeType,
                       GradeLevel,
                       SUM(Inventory) AS Inventory,
                       AmcosVersionId
                FROM data.Inventory
                WHERE PayPlan IN ( 'AE', 'AO', 'AWO', 'NE', 'NO', 'NWO', 'RE', 'RO', 'RWO' )
                      AND AmcosVersionId
                      BETWEEN @AmcosVersionId - 200 AND @AmcosVersionId
                GROUP BY PayPlan,
                         CategoryGroupCode,
                         CategorySubgroupCode,
                         GradeType,
                         GradeLevel,
                         AmcosVersionId
            ) AS a
            GROUP BY PayPlan,
                     CategoryGroupCode,
                     CategorySubgroupCode,
                     GradeType,
                     GradeLevel
        ) AS MilitaryInventory
            ON a.CategorySubgroupCode = MilitaryInventory.CategorySubgroupCode
               AND a.GradeLevel = MilitaryInventory.GradeLevel
               AND a.PayPlan = MilitaryInventory.PayPlan;

    --when there is no inventory the value shows up as null, we want to change those to 0
    UPDATE #DMDCPayFinal
    SET Inventory = 0
    WHERE Inventory IS NULL;

    --when the number receiving is greater than inventory then use rcv as demoninator so we aren't inflating costs
    UPDATE #DMDCPayFinal
    SET avg_mpa_cost = avg_3yr_pay / NULLIF(avg_3yr_payments, 0)
    WHERE (Inventory) < avg_3yr_payments
          AND Inventory > 0;

    --when inventory is greater than  number receiving then use inv as demoninator
    UPDATE #DMDCPayFinal
    SET avg_mpa_cost = avg_3yr_pay / NULLIF(Inventory, 0)
    WHERE (Inventory) >= avg_3yr_payments
          AND Inventory > 0;

    --we don't allow negative costs so make those zero
    UPDATE #DMDCPayFinal
    SET avg_mpa_cost = 0
    WHERE avg_mpa_cost < 0;

    IF @Debug = 1
    BEGIN
        SELECT 'test scenario';
        SELECT *
        FROM #DMDCPayRaw
        WHERE PayPlan = 'NO'
              AND PrimaryServiceOccupationCode = '73A'
              AND GradeLevel = 1;
        SELECT *
        FROM #DMDCPayFinal
        WHERE PayPlan = 'NO'
              AND CategorySubgroupCode = '73A'
              AND GradeLevel = 1;
        SELECT 'here is the average by amcosversion';
        SELECT AmcosVersionId,
               PayType,
               PayPlan,
               NULL AS CategoryGroupCode,
               PrimaryServiceOccupationCode,
               GradeType,
               GradeLevel,
               SUM(TotalPayAmount) AS avg_annual_pay,
               AVG(number_rcv) AS avg_annual_payments,
               NULL AS Inventory,
               0.0 AS avg_mpa_cost
        FROM #DMDCPayRaw
        GROUP BY AmcosVersionId,
                 PayType,
                 PayPlan,
                 PrimaryServiceOccupationCode,
                 GradeType,
                 GradeLevel;

        SELECT 'here is the final processed table #DMDCPayFinal';
        SELECT PayType,
               PayPlan,
               CategoryGroupCode,
               CategorySubgroupCode,
               GradeType,
               GradeLevel,
               avg_3yr_pay,
               avg_3yr_payments,
               Inventory,
               avg_mpa_cost
        FROM #DMDCPayFinal
        ORDER BY avg_3yr_pay DESC;
    END;

    --populate the crunch.PayProcessed table for use by individual cost element calculations later
    IF @Debug = 0
    BEGIN
        DELETE crunch.PayProcessed
        WHERE AmcosVersionId = @AmcosVersionId;
        INSERT INTO crunch.PayProcessed
        (
            PayType,
            PayPlan,
            CategoryGroupCode,
            CategorySubgroupCode,
            GradeType,
            GradeLevel,
            avg_cost,
            AmcosVersionId,
            avg_annual_pay,
            avg_annual_payments
        )
        SELECT PayType,
               PayPlan,
               CategoryGroupCode,
               CategorySubgroupCode,
               GradeType AS GradeType,
               GradeLevel,
               avg_mpa_cost AS [avg_cost],
               @AmcosVersionId AS AmcosVersionId,
               avg_3yr_pay,
               avg_3yr_payments
        FROM #DMDCPayFinal;
    END;
END;