
/*
Description:	
Dependencies:  Inventory
               PaySchedule
               SingleValues
*/
CREATE PROCEDURE [crunch].[CrunchGSS]
    @OccupationalSeriesNumber NVARCHAR(4),
    @AmcosVersionId INT = -1
AS
BEGIN

    SET NOCOUNT ON;

    DECLARE @IsValidAmcosVersion BIT = crunch.ValidateAmcosVersion(@AmcosVersionId);

    IF (@IsValidAmcosVersion = 0)
        RETURN 0;

    DECLARE @OccupationalGroupNumber NVARCHAR(4) = SUBSTRING(@OccupationalSeriesNumber, 1, 2) + "00";

    DECLARE @CrunchCosts TABLE
    (
        SpecialRateTableNumber NVARCHAR(4) NOT NULL,
        CostElementId INT NOT NULL,
        GradeLevel TINYINT NOT NULL,
        Amount FLOAT NULL,
        CrunchTime SMALLDATETIME NULL
    );

    DECLARE @SpecialRateTableNumber VARCHAR(5);

    DECLARE cTableNumber CURSOR FOR
    SELECT DISTINCT
           SpecialRateTableNumber
    FROM lookup.OPM_SpecialRate
    WHERE OccupationalSeriesNumber = @OccupationalSeriesNumber
    ORDER BY SpecialRateTableNumber;

    OPEN cTableNumber;

    FETCH cTableNumber
    INTO @SpecialRateTableNumber;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        -- 4/25/2013 Change to calculate Weighted Average by Inventory values.  
        DECLARE @AnnualBasePay TABLE
        (
            GradeLevel TINYINT NOT NULL,
            Step TINYINT NOT NULL,
            Inventory INT NOT NULL,
            BasePay NUMERIC(10, 2) NULL
        );
        INSERT INTO @AnnualBasePay
        SELECT Pay.GradeLevel,
               Pay.Step_YOS,
               Inventory.Amount,
               Pay.Rate
        FROM
        (
            SELECT GradeLevel,
                   Step_YOS,
                   Rate
            FROM data.PaySchedules
            WHERE PayPlan = 'GSS'
                  AND RateType = 'Annual'
                  AND SpecialRateTableNumber = @SpecialRateTableNumber
        ) Pay
            INNER JOIN crunch.InventoryByGradeYosForCategorySubgroup('GS', @OccupationalSeriesNumber) Inventory
                ON Pay.GradeLevel = Inventory.GradeLevel
                   AND Pay.Step_YOS = Inventory.Step_YOS;

        DECLARE @AverageAnnualBasePay TABLE
        (
            GradeLevel TINYINT NOT NULL,
            Amount FLOAT NULL
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
            SpecialRateTableNumber,
            GradeLevel,
            Amount
        )
        SELECT 2275,
               @SpecialRateTableNumber,
               GradeLevel,
               Amount
        FROM @AverageAnnualBasePay;

        /* Army CivPay; Compensation - Other; Avg Cost of Other Compensation */
        INSERT INTO @CrunchCosts
        (
            CostElementId,
            SpecialRateTableNumber,
            GradeLevel,
            Amount
        )
        SELECT 2284,
               @SpecialRateTableNumber,
               GradeLevel,
               Amount * @OtherComp
        FROM @AverageAnnualBasePay;

        /* Army CivPay; Benefits; Avg Cost of Benefits */
        INSERT INTO @CrunchCosts
        (
            CostElementId,
            SpecialRateTableNumber,
            GradeLevel,
            Amount
        )
        SELECT 2286,
               @SpecialRateTableNumber,
               GradeLevel,
               Amount * @BenefitsRet
        FROM @AverageAnnualBasePay;

        /* Army CivPay; Benefits; Avg Cost of Former Employee Compensation */
        INSERT INTO @CrunchCosts
        (
            CostElementId,
            SpecialRateTableNumber,
            GradeLevel,
            Amount
        )
        SELECT 2282,
               @SpecialRateTableNumber,
               GradeLevel,
               Amount * @FormerEmp
        FROM @AverageAnnualBasePay;

        /* Army CivPay; Cash Awards; Avg Cost of Cash Awards */
        INSERT INTO @CrunchCosts
        (
            CostElementId,
            SpecialRateTableNumber,
            GradeLevel,
            Amount
        )
        SELECT 2279,
               @SpecialRateTableNumber,
               GradeLevel,
               Amount * @CashAwards
        FROM @AverageAnnualBasePay;

        /* Army CivPay; Holiday Pay; Avg Cost of Holiday Pay */
        INSERT INTO @CrunchCosts
        (
            CostElementId,
            SpecialRateTableNumber,
            GradeLevel,
            Amount
        )
        SELECT 2276,
               @SpecialRateTableNumber,
               GradeLevel,
               Amount * @Holiday
        FROM @AverageAnnualBasePay;

        /* Army CivPay; Overtime Pay; Avg Cost of Overtime Pay */
        INSERT INTO @CrunchCosts
        (
            CostElementId,
            SpecialRateTableNumber,
            GradeLevel,
            Amount
        )
        SELECT 2277,
               @SpecialRateTableNumber,
               GradeLevel,
               Amount * @Ovrt
        FROM @AverageAnnualBasePay;

        /* OMA; Training Costs; Training */
        INSERT INTO @CrunchCosts
        (
            CostElementId,
            SpecialRateTableNumber,
            GradeLevel,
            Amount
        )
        SELECT 2735,
               @SpecialRateTableNumber,
               GradeLevel,
               @Training
        FROM @AverageAnnualBasePay;

        /* Federal OM; Retired Pay Accrual; Avg Cost of Post Retirement Health Insurance */
        INSERT INTO @CrunchCosts
        (
            CostElementId,
            SpecialRateTableNumber,
            GradeLevel,
            Amount
        )
        SELECT 2952,
               @SpecialRateTableNumber,
               GradeLevel,
               @PostRetHealthIns
        FROM @AverageAnnualBasePay;

        /* Federal OM; Retired Pay Accrual; Avg Cost of Post Retirement Life Insurance */
        INSERT INTO @CrunchCosts
        (
            CostElementId,
            SpecialRateTableNumber,
            GradeLevel,
            Amount
        )
        SELECT 2951,
               @SpecialRateTableNumber,
               GradeLevel,
               @PostRetLifeIns
        FROM @AverageAnnualBasePay;

        PRINT 'Special Rate Table:  ' + @SpecialRateTableNumber;

        DELETE @AnnualBasePay;
        DELETE @AverageAnnualBasePay;

        FETCH cTableNumber
        INTO @SpecialRateTableNumber;
    END;

    CLOSE cTableNumber;
    DEALLOCATE cTableNumber;

    SELECT 'GSS',
           @OccupationalGroupNumber,
           @OccupationalSeriesNumber,
           SpecialRateTableNumber,
           CostElementId,
           'GSS',
           GradeLevel,
           Amount,
           CONVERT(SMALLDATETIME, GETDATE()) AS CrunchTime
    FROM @CrunchCosts;

END;