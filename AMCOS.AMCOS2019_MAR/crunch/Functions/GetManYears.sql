
CREATE FUNCTION [crunch].[GetManYears]
(
    @PayPlan NVARCHAR(3),
    @CMF NVARCHAR(3),
    @YOS INT,
    @AmcosVersionId INT
)
RETURNS FLOAT
AS
BEGIN

    DECLARE @ContinuationRate FLOAT;
    DECLARE @Percentage FLOAT;
    DECLARE @ManYears FLOAT;

    SELECT @Percentage = 1;
    SELECT @ContinuationRate = 0;
    SET @ManYears = 0;

    IF @PayPlan = 'AE'
       OR @PayPlan = 'AO'
       OR @PayPlan = 'AWO'
    BEGIN
        WHILE (@YOS < 31)
        BEGIN
            SELECT @ContinuationRate = crunch.GetContinuationRate(@PayPlan, @CMF, @YOS, @AmcosVersionId);
            SELECT @Percentage = @Percentage * @ContinuationRate;
            SELECT @ManYears = @ManYears + @Percentage;
            SELECT @YOS = @YOS + 1;
        END;
    END;

    IF @PayPlan = 'NE'
       OR @PayPlan = 'NO'
       OR @PayPlan = 'NWO'
       OR @PayPlan = 'RE'
       OR @PayPlan = 'RO'
       OR @PayPlan = 'RWO'
    BEGIN

        WHILE (@YOS < 41)
        BEGIN
            SELECT @ContinuationRate = crunch.GetContinuationRate(@PayPlan, @CMF, @YOS, @AmcosVersionId);
            SELECT @Percentage = @Percentage * @ContinuationRate;
            SELECT @ManYears = @ManYears + @Percentage;
            SELECT @YOS = @YOS + 1;
        END;
    END;

    IF (@ManYears = 0)
        SET @ManYears = 1;
    RETURN @ManYears;
END;