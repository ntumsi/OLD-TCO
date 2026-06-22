
/*
Description:	
Dependencies:  Inventory
               PaySchedule
               SingleValues
*/
CREATE PROCEDURE [crunch].[CrunchGL]
    @OccupationalGroupNumber NVARCHAR(4),
    @OccupationalSeriesNumber NVARCHAR(4),
    @AmcosVersionId INT = -1
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @IsValidAmcosVersion BIT = crunch.ValidateAmcosVersion(@AmcosVersionId);

    IF (@IsValidAmcosVersion = 0)
        RETURN 0;

    IF NOT EXISTS
    (
        SELECT CategorySubGroupCode
        FROM data.Inventory
        WHERE CategorySubGroupCode = @OccupationalSeriesNumber
              AND PayPlan = 'GL'
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

    DECLARE @AnnualBasePay TABLE
    (
        GradeLevel TINYINT NOT NULL,
        Step INT NOT NULL,
        Inventory INT NOT NULL,
        BasePay NUMERIC(10, 2) NULL
    );
    INSERT INTO @AnnualBasePay
    SELECT Pay.GradeLevel,
           Pay.Step_YOS,
           Inventory.Inventory,
           Pay.Rate
    FROM
    (
        SELECT Rate,
               GradeLevel,
               Step_YOS
        FROM data.PaySchedules
        WHERE PayPlan = 'GL'
              AND RateType = 'Annual'
    ) Pay
        INNER JOIN
        (
            SELECT GradeLevel,
                   Step_YOS,
                   Inventory AS Inventory
            FROM data.Inventory
            WHERE PayPlan = 'GL'
                  AND CategorySubGroupCode = @OccupationalSeriesNumber
        ) Inventory
            ON Pay.GradeLevel = Inventory.GradeLevel
               AND Pay.Step_YOS = Inventory.Step_YOS;

    DECLARE @AverageAnnualBasePay TABLE
    (
        GradeType VARCHAR(3) NOT NULL,
        GradeLevel TINYINT NOT NULL,
        Salary NUMERIC(10, 2) NOT NULL
    );
    INSERT INTO @AverageAnnualBasePay
    SELECT 'GL',
           GradeLevel,
           SUM(Inventory * BasePay) / SUM(Inventory)
    FROM @AnnualBasePay
    GROUP BY GradeLevel;

    DECLARE @PostRetHealthIns FLOAT = crunch.GetSingleValue('AA', 'PostRetHealthIns');
    DECLARE @PostRetLifeIns FLOAT = crunch.GetSingleValue('AA', 'PostRetLifeIns');
    DECLARE @Training FLOAT = crunch.GetSingleValue('AA', 'Training');
    DECLARE @BenefitsRet FLOAT = crunch.GetSingleValue('GL', 'BenefitsRet');
    DECLARE @CashAwards FLOAT = crunch.GetSingleValue('GL', 'CashAwards');
    DECLARE @FormerEmp FLOAT = crunch.GetSingleValue('GL', 'FormerEmp');
    DECLARE @Holiday FLOAT = crunch.GetSingleValue('GL', 'Holiday');
    DECLARE @OtherComp FLOAT = crunch.GetSingleValue('GL', 'OtherComp');
    DECLARE @Ovrt FLOAT = crunch.GetSingleValue('GL', 'Ovrt');

    /* Army CivPay; Compensation - Basic; Avg Cost of Base Pay (Civilian) */
    INSERT INTO @CrunchCosts
    (
        CostElementId,
        GradeType,
        GradeLevel,
        Amount
    )
    SELECT 3492,
           GradeType,
           GradeLevel,
           Salary
    FROM @AverageAnnualBasePay;

    /* Army CivPay; Compensation - Other; Avg Cost of Other Compensation */
    INSERT INTO @CrunchCosts
    (
        CostElementId,
        GradeType,
        GradeLevel,
        Amount
    )
    SELECT 3493,
           GradeType,
           GradeLevel,
           (Salary * @OtherComp) AS OtherComp
    FROM @AverageAnnualBasePay;

    /* Army CivPay; Benefits; Avg Cost of Benefits */
    INSERT INTO @CrunchCosts
    (
        CostElementId,
        GradeType,
        GradeLevel,
        Amount
    )
    SELECT 3487,
           GradeType,
           GradeLevel,
           (Salary * @BenefitsRet) AS BenefitsRet
    FROM @AverageAnnualBasePay;

    /* Army CivPay; Benefits; Avg Cost of Former Employee Compensation */
    INSERT INTO @CrunchCosts
    (
        CostElementId,
        GradeType,
        GradeLevel,
        Amount
    )
    SELECT 3490,
           GradeType,
           GradeLevel,
           (Salary * @FormerEmp) AS FormerEmp
    FROM @AverageAnnualBasePay;

    /* Army CivPay; Cash Awards; Avg Cost of Cash Awards */
    INSERT INTO @CrunchCosts
    (
        CostElementId,
        GradeType,
        GradeLevel,
        Amount
    )
    SELECT 3491,
           GradeType,
           GradeLevel,
           (Salary * @CashAwards) AS CashAwards
    FROM @AverageAnnualBasePay;

    /* Army CivPay; Holiday Pay; Avg Cost of Holiday Pay */
    INSERT INTO @CrunchCosts
    (
        CostElementId,
        GradeType,
        GradeLevel,
        Amount
    )
    SELECT 3494,
           GradeType,
           GradeLevel,
           (Salary * @Holiday) AS Holiday
    FROM @AverageAnnualBasePay;

    /* Army CivPay; Overtime Pay; Avg Cost of Overtime Pay */
    INSERT INTO @CrunchCosts
    (
        CostElementId,
        GradeType,
        GradeLevel,
        Amount
    )
    SELECT 3495,
           GradeType,
           GradeLevel,
           (Salary * @Ovrt) AS Ovrt
    FROM @AverageAnnualBasePay;

    /* Federal OM; Retired Pay Accrual; Avg Cost of Post Retirement Life Insurance */
    INSERT INTO @CrunchCosts
    (
        CostElementId,
        GradeType,
        GradeLevel,
        Amount
    )
    SELECT 3498,
           GradeType,
           GradeLevel,
           @PostRetLifeIns
    FROM @AverageAnnualBasePay;

    /* Federal OM; Retired Pay Accrual; Avg Cost of Post Retirement Health Insurance */
    INSERT INTO @CrunchCosts
    (
        CostElementId,
        GradeType,
        GradeLevel,
        Amount
    )
    SELECT 3497,
           GradeType,
           GradeLevel,
           @PostRetHealthIns
    FROM @AverageAnnualBasePay;

    /* OMA; Training Costs; Training */
    INSERT INTO @CrunchCosts
    (
        CostElementId,
        GradeType,
        GradeLevel,
        Amount
    )
    SELECT 3499,
           GradeType,
           GradeLevel,
           @Training
    FROM @AverageAnnualBasePay;

    SELECT 'GL',
           @OccupationalGroupNumber,
           @OccupationalSeriesNumber,
           CostElementId,
           GradeType,
           GradeLevel,
           Amount,
           CONVERT(SMALLDATETIME, GETDATE()) AS CrunchTime
    FROM @CrunchCosts;

END;