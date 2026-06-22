


-- =============================================
-- Author:		Name
-- Create date: 
-- Description:	
-- =============================================
CREATE FUNCTION [crunch].[GetTotalSiblingInventory]
(
    @PayPlan NVARCHAR(3),
    @ParentMOS NVARCHAR(3),
    @AmcosVersionId INT = -1
)
RETURNS INT
AS
BEGIN
    DECLARE @Result INT;

    SET @Result =
    (
        SELECT SUM(Inventory.Inventory)
        FROM data.Inventory Inventory
            LEFT OUTER JOIN lookup.MOS MOS
                ON Inventory.CategorySubgroupCode = MOS.MOS
        WHERE Inventory.PayPlan = @PayPlan
              AND MOS.Parent_MOS = @ParentMOS
              AND (@AmcosVersionId
              BETWEEN MOS.AmcosVersionIdStart AND MOS.AmcosVersionIdEnd
                  )
              AND Inventory.AmcosVersionId = @AmcosVersionId
    );

    RETURN @Result;

END;