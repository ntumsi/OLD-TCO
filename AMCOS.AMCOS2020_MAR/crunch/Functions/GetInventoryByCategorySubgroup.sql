
-- =============================================
-- Author:		Name
-- Create date: 
-- Description:	
-- =============================================
CREATE FUNCTION [crunch].[GetInventoryByCategorySubgroup]
(
    @PayPlan NVARCHAR(3),
    @CategorySubgroupCode NVARCHAR(3),
    @AmcosVersionId INT = -1
)
RETURNS INT
AS
BEGIN
    DECLARE @Result INT;

    SET @Result =
    (
        SELECT SUM(Inventory)
        FROM data.Inventory
        WHERE PayPlan = @PayPlan
              AND CategorySubgroupCode = @CategorySubgroupCode
              AND AmcosVersionId = @AmcosVersionId
    );

    RETURN @Result;

END;