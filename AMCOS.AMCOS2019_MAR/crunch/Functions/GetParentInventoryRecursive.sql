

-- =============================================
-- Author:		Name
-- Create date: 
-- Description:	
-- =============================================
CREATE FUNCTION crunch.GetParentInventoryRecursive
(
    @PayPlan NVARCHAR(3),
    @CategorySubGroupCode NVARCHAR(3),
    @GradeType NVARCHAR(3),
    @GradeLevel TINYINT
)
RETURNS FLOAT
BEGIN

    DECLARE @currentValue NVARCHAR(3);
    DECLARE @currentParent NVARCHAR(3);
    DECLARE @nextParent NVARCHAR(3);
    DECLARE @FinalResult FLOAT = 0.0;
    DECLARE @parentinv FLOAT = 0.0;


    SET @currentParent =
    (
        SELECT Parent_MOS FROM lookup.MOS WHERE MOS = @CategorySubGroupCode
    );
    SET @currentValue = @CategorySubGroupCode;

    IF (@currentParent IS NULL)
        RETURN 0.0;

    SET @parentinv =
    (
        SELECT ISNULL(SUM(Inventory), 0)
        FROM data.Inventory
        WHERE PayPlan = @PayPlan
              AND CategorySubGroupCode = @currentParent
              AND GradeType = @GradeType
    );

    SET @FinalResult
        = crunch.GetParentSharePercentage(@PayPlan, @CategorySubGroupCode, @GradeType)
          * (@parentinv + crunch.GetParentInventoryRecursive(@PayPlan, @currentParent, @GradeType, @GradeLevel));

    RETURN @FinalResult;
END;