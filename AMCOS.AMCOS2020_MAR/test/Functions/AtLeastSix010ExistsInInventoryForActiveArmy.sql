
-- =============================================
-- Author:		Greg
-- Create date: 5/14/2018
-- Description:	There should be at least 6 O10s for the Active (CSA, VCSA, FORSCOM, AMC, USARPAC, TRDOC) + others as assigned to Joint posts
-- =============================================
CREATE FUNCTION [test].[AtLeastSix010ExistsInInventoryForActiveArmy]
()
RETURNS BIT
AS
BEGIN
    DECLARE @Result BIT = 0;
    DECLARE @TotalInventory INT;


    SELECT @TotalInventory = SUM(Inventory)
    FROM data.Inventory
    WHERE PayPlan = 'AO'
          AND GradeType = 'O'
          AND GradeLevel = 10;

    IF @TotalInventory >= 6
        SET @Result = 1;

    RETURN @Result;

END;