

-- =============================================
-- Author:		Name
-- Create date: 
-- Description:	
-- =============================================
CREATE FUNCTION [crunch].[GetParentInventory]
(
    @PayPlan NVARCHAR(3),
    @CategorySubgroupCode NVARCHAR(3),
    @AmcosVersionId INT = -1
)
RETURNS NUMERIC(16, 2)
BEGIN

    DECLARE @ParentMOS NVARCHAR(3);
    DECLARE @FinalResult NUMERIC(16, 2);
    DECLARE @ParentInventory INT;

    SET @ParentMOS =
    (
        SELECT Parent_MOS
        FROM lookup.MOS
        WHERE MOS = @CategorySubgroupCode
              AND (@AmcosVersionId
              BETWEEN AmcosVersionIdStart AND AmcosVersionIdEnd
                  )
    );

    IF (@ParentMOS IS NULL)
        RETURN 0.0;

    SET @ParentInventory =
    (
        SELECT ISNULL(SUM(Inventory), 0)
        FROM data.Inventory
        WHERE PayPlan = @PayPlan
              AND CategorySubgroupCode = @ParentMOS
              AND AmcosVersionId = @AmcosVersionId
    );

    SET @FinalResult
        = crunch.GetChildInventoryPercentage(@PayPlan, @CategorySubgroupCode, @AmcosVersionId)
          * (@ParentInventory + crunch.GetParentInventory(@PayPlan, @ParentMOS, @AmcosVersionId));

    RETURN @FinalResult;
END;