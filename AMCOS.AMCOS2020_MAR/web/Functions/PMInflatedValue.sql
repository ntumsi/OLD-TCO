CREATE FUNCTION [web].[PMInflatedValue]
(
    @AmountToInflate FLOAT,
    @CostElementId INTEGER,
    @ProjectYear SMALLINT,
    @1ActiveDayAmountToInflate FLOAT = 0,
    @ActiveDutyDays INTEGER = 0,
    @AmcosVersionId INTEGER
)
RETURNS FLOAT
AS
BEGIN

    DECLARE @PayPlan NVARCHAR(3);
    DECLARE @APPN NVARCHAR(25);
    DECLARE @PayRate DECIMAL(18, 15);
    DECLARE @ApplyInflation BIT;

    SELECT @PayPlan = PayPlan,
           @APPN = APPN,
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
          AND Year = @ProjectYear
          AND AmcosVersionId = @AmcosVersionId;

    /* Only apply inflation to cost elements where required */
    IF @ApplyInflation = 0
        SET @PayRate = 1.00;

    /*NG / Res ADT Days*/
    IF @PayPlan IN ( 'NE', 'NO', 'NWO', 'RE', 'RO', 'RWO' )
        SET @AmountToInflate
            = @1ActiveDayAmountToInflate + (@AmountToInflate - @1ActiveDayAmountToInflate) * (@ActiveDutyDays - 1) / 14;

    RETURN @AmountToInflate * @PayRate;

END;