





-- =============================================
-- Author:		Name
-- Create date: 
-- Description:	
-- =============================================
CREATE FUNCTION crunch.GetParentSharePercentage
(
    @PayPlan NVARCHAR(3),
    @CategorySubGroupCode NVARCHAR(3),
    @GradeType NVARCHAR(3)
)
RETURNS FLOAT
BEGIN

    DECLARE @currentValue NVARCHAR(3);
    DECLARE @currentParent NVARCHAR(3);

    DECLARE @FinalResult FLOAT = 0.0;

    DECLARE @inv FLOAT = 0.0;
    DECLARE @totalchildinv FLOAT = 0.0;


    SET @currentParent =
    (
        SELECT Parent_MOS FROM lookup.MOS WHERE MOS = @CategorySubGroupCode
    );
    SET @currentValue = @CategorySubGroupCode;

    IF (@currentParent IS NULL)
        RETURN 0.0;

    SET @inv =
    (
        SELECT (SUM(Inventory))
        FROM data.Inventory
        WHERE PayPlan = @PayPlan
              AND CategorySubGroupCode = @currentValue
              AND GradeType = @GradeType
    );

    IF (@inv IS NULL)
        RETURN 0.0;

    SET @totalchildinv =
    (
        SELECT SUM(Inventory)
        FROM data.Inventory
            LEFT OUTER JOIN lookup.MOS
                ON data.Inventory.CategorySubGroupCode = lookup.MOS.MOS
        WHERE PayPlan = @PayPlan
              AND Parent_MOS = @currentParent
              AND GradeType = @GradeType
    );

    IF (@totalchildinv IS NULL)
        RETURN 0.0;

    SET @FinalResult = (@inv / @totalchildinv);

    RETURN @FinalResult;
END;