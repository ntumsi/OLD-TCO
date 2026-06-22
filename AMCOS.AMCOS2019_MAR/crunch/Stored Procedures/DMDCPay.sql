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
        PayType NVARCHAR(100) NULL,
        PrimaryServiceOccupationCode NVARCHAR(20) NULL,
        [number_rcv] INT NULL,
        TotalPayAmount NUMERIC(18, 2) NULL,
        [inv_add] FLOAT NULL
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



    -- =============================================
    --Generate final table
    -- =============================================
    CREATE TABLE #DMDCPayFinal
    (
        PayType NVARCHAR(100) NULL,
        PayPlan NVARCHAR(3) NULL,
        CategoryGroupCode NVARCHAR(4) NULL,
        CategorySubgroupCode NVARCHAR(4) NULL,
        GradeType NVARCHAR(3) NULL,
        GradeLevel NVARCHAR(3) NULL,
        avg_3yr_pay FLOAT NULL,
        avg_3yr_payments FLOAT NULL,
        [Inventory] INT NULL,
        [avg_mpa_cost] FLOAT NULL
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
           AVG(avg_annual_pay) AS avg_3yr_pay,
           AVG(avg_annual_payments) AS avg_3yr_payments,
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
               AVG(number_rcv) AS avg_annual_payments,
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
    UPDATE #DMDCPayFinal
    SET Inventory = MilitaryInventory.Inventory
    FROM #DMDCPayFinal AS a
        INNER JOIN
        (
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   GradeType,
                   GradeLevel,
                   SUM(Inventory) AS Inventory
            FROM data.Inventory
            WHERE PayPlan IN ( 'AO', 'AWO', 'RO', 'RWO', 'NO', 'NWO', 'NE', 'AE', 'RE' )
            GROUP BY PayPlan,
                     CategoryGroupCode,
                     CategorySubGroupCode,
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

    --populate the crunch.DMDCPayProcessed table for use by individual cost element calculations later
    IF @Debug = 0
    BEGIN
        DELETE crunch.DMDCPayProcessed
        WHERE AmcosVersionId = @AmcosVersionId;
        INSERT INTO crunch.DMDCPayProcessed
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