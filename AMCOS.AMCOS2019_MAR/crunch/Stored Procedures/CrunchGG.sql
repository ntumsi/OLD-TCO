
/*
Description:	
Dependencies:  Inventory
               PaySchedule
               SingleValues
*/
CREATE PROCEDURE [crunch].[CrunchGG]
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
              AND PayPlan = 'GG'
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
        WHERE PayPlan = 'GG'
              AND RateType = 'Annual'
    ) Pay
        INNER JOIN
        (
            SELECT GradeLevel,
                   Step_YOS,
                   Inventory AS Inventory
            FROM data.Inventory
            WHERE PayPlan = 'GG'
                  AND CategorySubGroupCode = @OccupationalSeriesNumber
        ) Inventory
            ON Pay.GradeLevel = Inventory.GradeLevel
               AND Pay.Step_YOS = Inventory.Step_YOS;

    DECLARE @AverageAnnualBasePay TABLE
    (
        GradeType VARCHAR(3) NOT NULL,
        GradeLevel TINYINT NOT NULL,
        Salary NUMERIC(10, 2) NULL
    );
    INSERT INTO @AverageAnnualBasePay
    SELECT 'GG',
           GradeLevel,
           SUM(Inventory * BasePay) / SUM(Inventory)
    FROM @AnnualBasePay
    GROUP BY GradeLevel;

    DECLARE @PostRetHealthIns FLOAT = crunch.GetSingleValue('AA', 'PostRetHealthIns');
    DECLARE @PostRetLifeIns FLOAT = crunch.GetSingleValue('AA', 'PostRetLifeIns');
    DECLARE @Training FLOAT = crunch.GetSingleValue('AA', 'Training');
    DECLARE @BenefitsRet FLOAT = crunch.GetSingleValue('GG', 'BenefitsRet');
    DECLARE @CashAwards FLOAT = crunch.GetSingleValue('GG', 'CashAwards');
    DECLARE @FormerEmp FLOAT = crunch.GetSingleValue('GG', 'FormerEmp');
    DECLARE @Holiday FLOAT = crunch.GetSingleValue('GG', 'Holiday');
    DECLARE @OtherComp FLOAT = crunch.GetSingleValue('GG', 'OtherComp');
    DECLARE @Ovrt FLOAT = crunch.GetSingleValue('GG', 'Ovrt');

    /* Army CivPay; Compensation - Basic; Avg Cost of Base Pay (Civilian) */
    INSERT INTO @CrunchCosts
    (
        CostElementId,
        GradeType,
        GradeLevel,
        Amount
    )
    SELECT 3505,
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
    SELECT 3506,
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
    SELECT 3500,
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
    SELECT 3503,
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
    SELECT 3504,
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
    SELECT 3507,
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
    SELECT 3508,
           GradeType,
           GradeLevel,
           (Salary * @Ovrt) AS Ovrt
    FROM @AverageAnnualBasePay;

    /* OMA; Training Costs; Training */
    INSERT INTO @CrunchCosts
    (
        CostElementId,
        GradeType,
        GradeLevel,
        Amount
    )
    SELECT 3512,
           GradeType,
           GradeLevel,
           @Training
    FROM @AverageAnnualBasePay;

    /* Federal OM; Retired Pay Accrual; Avg Cost of Post Retirement Life Insurance */
    INSERT INTO @CrunchCosts
    (
        CostElementId,
        GradeType,
        GradeLevel,
        Amount
    )
    SELECT 3511,
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
    SELECT 3510,
           GradeType,
           GradeLevel,
           @PostRetHealthIns
    FROM @AverageAnnualBasePay;

    SELECT 'GG',
           @OccupationalGroupNumber,
           @OccupationalSeriesNumber,
           CostElementId,
           GradeType,
           GradeLevel,
           Amount,
           CONVERT(SMALLDATETIME, GETDATE()) AS CrunchTime
    FROM @CrunchCosts;

END;