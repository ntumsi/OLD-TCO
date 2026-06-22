

-- =============================================
-- Author:		
-- Create date: 5/14/2018
-- Description:	There should be at least one O9 for the Army Reserve
-- =============================================
CREATE FUNCTION [test].[O9ExistsInInventoryForUSAR]
()
RETURNS BIT
AS
BEGIN
    DECLARE @Result BIT = 0;
    DECLARE @TotalInventory INT;

    SELECT @TotalInventory = SUM(Inventory)
    FROM data.Inventory
    WHERE PayPlan = 'RO'
          AND GradeType = 'O'
          AND GradeLevel = 9;

    IF @TotalInventory >= 1
        SET @Result = 1;

    RETURN @Result;

END;