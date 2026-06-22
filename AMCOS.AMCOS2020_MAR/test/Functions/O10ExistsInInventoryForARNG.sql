
-- =============================================
-- Author:		Greg
-- Create date: 5/11/2018
-- Description:	There MAY be zero or one O10 for the ARNG depending on whether their 4 star comes from the Army or another service
-- =============================================
CREATE FUNCTION [test].[O10ExistsInInventoryForARNG]
()
RETURNS BIT
AS
BEGIN
    DECLARE @Result BIT = 0;
    DECLARE @TotalInventory INT;

    SELECT @TotalInventory = SUM(Inventory)
    FROM data.Inventory
    WHERE PayPlan = 'NO'
          AND GradeType = 'O'
          AND GradeLevel = 10;

    IF @TotalInventory IS NULL
       OR @TotalInventory = 1
        SET @Result = 1;

    RETURN @Result;
END;