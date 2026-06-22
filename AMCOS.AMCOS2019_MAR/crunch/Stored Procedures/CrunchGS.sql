
/*
Description:	
Dependencies:  Inventory
               PaySchedule
               SingleValues
*/
CREATE PROCEDURE [crunch].[CrunchGS]
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
              AND PayPlan = 'GS'
    )
        RETURN 0;

    DECLARE @OccupationalGroupNumber NVARCHAR(4) = SUBSTRING(@OccupationalSeriesNumber, 1, 2) + "00";

    DECLARE @CrunchCosts TABLE
    (
        CostElementId INT NOT NULL,
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
           Inventory.Amount,
           Pay.Rate AS BasePay
    FROM
    (
        SELECT Rate,
               GradeLevel,
               Step_YOS
        FROM data.PaySchedules
        WHERE PayPlan = 'GS'
              AND RateType = 'Annual'
    ) Pay
        INNER JOIN crunch.InventoryByGradeYosForCategorySubgroup('GS', @OccupationalSeriesNumber) Inventory
            ON Pay.GradeLevel = Inventory.GradeLevel
               AND Pay.Step_YOS = Inventory.Step_YOS;

    DECLARE @AverageAnnualBasePay TABLE
    (
        GradeLevel TINYINT NOT NULL,
        Amount NUMERIC(10, 2) NOT NULL
    );
    INSERT INTO @AverageAnnualBasePay
    SELECT GradeLevel,
           SUM(Inventory * BasePay) / SUM(Inventory)
    FROM @AnnualBasePay
    GROUP BY GradeLevel;

    DECLARE @PostRetHealthIns FLOAT = crunch.GetSingleValue('AA', 'PostRetHealthIns');
    DECLARE @PostRetLifeIns FLOAT = crunch.GetSingleValue('AA', 'PostRetLifeIns');
    DECLARE @Training FLOAT = crunch.GetSingleValue('AA', 'Training');
    DECLARE @BenefitsRet FLOAT = crunch.GetSingleValue('GS', 'BenefitsRet');
    DECLARE @CashAwards FLOAT = crunch.GetSingleValue('GS', 'CashAwards');
    DECLARE @FormerEmp FLOAT = crunch.GetSingleValue('GS', 'FormerEmp');
    DECLARE @Holiday FLOAT = crunch.GetSingleValue('GS', 'Holiday');
    DECLARE @OtherComp FLOAT = crunch.GetSingleValue('GS', 'OtherComp');
    DECLARE @Ovrt FLOAT = crunch.GetSingleValue('GS', 'Ovrt');

    /* Army CivPay; Compensation - Basic; Avg Cost of Base Pay (Civilian) */
    INSERT INTO @CrunchCosts
    (
        CostElementId,
        GradeLevel,
        Amount
    )
    SELECT 275,
           GradeLevel,
           Amount
    FROM @AverageAnnualBasePay;

    /* Army CivPay; Compensation - Other; Avg Cost of Other Compensation */
    INSERT INTO @CrunchCosts
    (
        CostElementId,
        GradeLevel,
        Amount
    )
    SELECT 284,
           GradeLevel,
           Amount * @OtherComp
    FROM @AverageAnnualBasePay;

    /* Army CivPay; Benefits; Avg Cost of Benefits */
    INSERT INTO @CrunchCosts
    (
        CostElementId,
        GradeLevel,
        Amount
    )
    SELECT 286,
           GradeLevel,
           Amount * @BenefitsRet
    FROM @AverageAnnualBasePay;

    /* Army CivPay; Benefits; Avg Cost of Former Employee Compensation */
    INSERT INTO @CrunchCosts
    (
        CostElementId,
        GradeLevel,
        Amount
    )
    SELECT 282,
           GradeLevel,
           Amount * @FormerEmp
    FROM @AverageAnnualBasePay;

    /* Army CivPay; Cash Awards; Avg Cost of Cash Awards */
    INSERT INTO @CrunchCosts
    (
        CostElementId,
        GradeLevel,
        Amount
    )
    SELECT 279,
           GradeLevel,
           Amount * @CashAwards
    FROM @AverageAnnualBasePay;

    /* Army CivPay; Holiday Pay; Avg Cost of Holiday Pay */
    INSERT INTO @CrunchCosts
    (
        CostElementId,
        GradeLevel,
        Amount
    )
    SELECT 276,
           GradeLevel,
           Amount * @Holiday
    FROM @AverageAnnualBasePay;

    /* Army CivPay; Overtime Pay; Avg Cost of Overtime Pay */
    INSERT INTO @CrunchCosts
    (
        CostElementId,
        GradeLevel,
        Amount
    )
    SELECT 277,
           GradeLevel,
           Amount * @Ovrt
    FROM @AverageAnnualBasePay;

    /* OMA; Training Costs; Training */
    INSERT INTO @CrunchCosts
    (
        CostElementId,
        GradeLevel,
        Amount
    )
    SELECT 735,
           GradeLevel,
           @Training
    FROM @AverageAnnualBasePay;

    /* Federal OM; Retired Pay Accrual; Avg Cost of Post Retirement Health Insurance */
    INSERT INTO @CrunchCosts
    (
        CostElementId,
        GradeLevel,
        Amount
    )
    SELECT 952,
           GradeLevel,
           @PostRetHealthIns
    FROM @AverageAnnualBasePay;

    /* Federal OM; Retired Pay Accrual; Avg Cost of Post Retirement Life Insurance */
    INSERT INTO @CrunchCosts
    (
        CostElementId,
        GradeLevel,
        Amount
    )
    SELECT 951,
           GradeLevel,
           @PostRetLifeIns
    FROM @AverageAnnualBasePay;

    SELECT 'GS',
           @OccupationalGroupNumber,
           @OccupationalSeriesNumber,
           CostElementId,
           'GS',
           GradeLevel,
           Amount,
           CONVERT(SMALLDATETIME, GETDATE()) AS CrunchTime
    FROM @CrunchCosts;

END;