-- =============================================
-- Author:      Name
-- Create Date: 
-- Description: 
-- =============================================
CREATE FUNCTION web.PayPlanContainsTag
(
    @payPlan NVARCHAR(3),
    @tag NVARCHAR(50)
)
RETURNS BIT
AS
BEGIN
    DECLARE @Result BIT = 0;
    DECLARE @RowCount INT;

    SET @RowCount =
    (
        SELECT COUNT(*)
        FROM web.PayPlanTag
        WHERE PayPlan = @payPlan
              AND Tag = @tag
    );

    IF @RowCount > 0
        SET @Result = 1;

    RETURN @Result;
END;