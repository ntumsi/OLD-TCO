

CREATE FUNCTION [web].[PMInflatedValue]
(
    @AmountToInflate FLOAT,
    @CostElementId INTEGER,
    @ProjectYear SMALLINT,
    @LocalityId INTEGER,
    @1ActiveDayAmountToInflate FLOAT = 0,
    @ActiveDutyDays INTEGER = 0
)
RETURNS FLOAT
AS
BEGIN

    DECLARE @PayPlan NVARCHAR(3);
    DECLARE @APPN NVARCHAR(25);
    DECLARE @PayRate DECIMAL(18, 15);
    DECLARE @Locality BIT;
    DECLARE @ApplyInflation BIT;
    DECLARE @LocalityRate NUMERIC(18, 4);

    SELECT @PayPlan = PayPlan,
           @APPN = APPN,
           @Locality = Locality,
           @ApplyInflation = ApplyInflation
    FROM lookup.CostElement
    WHERE CostElementId = @CostElementId;

    /* Contractor Cost Estimate pay plan uses the OMA appropriation */
    IF @PayPlan = 'CCE'
        SET @APPN = N'OMA';

    SELECT @PayRate = Amount
    FROM lookup.JicInflationRates
    WHERE ConversionType = 'ThenToThen'
          AND Appropriation = @APPN
          AND Year = @ProjectYear;

    /* Only apply inflation to cost elements where required */
    IF @ApplyInflation = 0
        SET @PayRate = 1.00;

    /*Apply locality rate to GS base salary*/
    SET @LocalityRate = 1.0;
    IF @Locality = 1
        SELECT @LocalityRate = Amount
        FROM lookup.LocalityRates
        WHERE Id = @LocalityId;

    /*NG / Res ADT Days*/
    IF @PayPlan IN ( 'NE', 'NO', 'NWO', 'RE', 'RO', 'RWO' )
        SET @AmountToInflate
            = @1ActiveDayAmountToInflate + (@AmountToInflate - @1ActiveDayAmountToInflate) * (@ActiveDutyDays - 1) / 14;

    RETURN @AmountToInflate * @PayRate * @LocalityRate;

END;