
-- =====================================================================================================================
-- Description:		If a continuation rate exists for the PayPlan/CMF/YOS combination, use it.
--					If a value is not found use rate for PayPlan/ZZ/YOS.
--					If a value still isn't found, use 1.
-- =====================================================================================================================
CREATE FUNCTION [crunch].[GetContinuationRate]
(
    @PayPlan NVARCHAR(3),
    @CMF NCHAR(2),
    @YOS TINYINT,
    @AmcosVersionId INT
)
RETURNS FLOAT
AS
BEGIN
    DECLARE @Result FLOAT = 1;

    IF EXISTS
    (
        SELECT PayPlan,
               CMF,
               YOS,
               AmcosVersionId,
               Amount
        FROM dataload.MilitaryContinuationRates
        WHERE PayPlan = @PayPlan
              AND CMF = @CMF
              AND YOS = @YOS
              AND AmcosVersionId = @AmcosVersionId
    )
    BEGIN
        SELECT @Result = Amount
        FROM dataload.MilitaryContinuationRates
        WHERE PayPlan = @PayPlan
              AND CMF = @CMF
              AND YOS = @YOS
              AND AmcosVersionId = @AmcosVersionId;
    END;
    ELSE
    BEGIN
        IF EXISTS
        (
            SELECT PayPlan,
                   CMF,
                   YOS,
                   AmcosVersionId,
                   Amount
            FROM dataload.MilitaryContinuationRates
            WHERE PayPlan = @PayPlan
                  AND CMF = 'ZZ'
                  AND YOS = @YOS
                  AND AmcosVersionId = @AmcosVersionId
        )
        BEGIN
            SELECT @Result = Amount
            FROM dataload.MilitaryContinuationRates
            WHERE CMF = 'ZZ'
                  AND PayPlan = @PayPlan
                  AND YOS = @YOS
                  AND AmcosVersionId = @AmcosVersionId;
        END;
    END;

    RETURN @Result;

END;