

-- =============================================
-- Author:		Name
-- Create date: 
-- Description:	
-- =============================================
CREATE FUNCTION [crunch].[GetChildInventoryPercentage]
(
    @PayPlan NVARCHAR(3),
    @CategorySubgroupCode NVARCHAR(3),
    @AmcosVersionId INT = -1
)
RETURNS NUMERIC(3, 2)
BEGIN

    DECLARE @ParentMOS NVARCHAR(3);
    DECLARE @ChildInventory INT;
    DECLARE @TotalSiblingInventory INT;
    DECLARE @FinalResult NUMERIC(3, 2);


    SET @ParentMOS = crunch.GetParentMOS(@CategorySubgroupCode, @AmcosVersionId);
    IF (@ParentMOS IS NULL)
        RETURN 0.0;

    SET @ChildInventory = crunch.GetInventoryByCategorySubgroup(@PayPlan, @CategorySubgroupCode, @AmcosVersionId);
    IF (@ChildInventory IS NULL)
        RETURN 0.0;

    SET @TotalSiblingInventory = crunch.GetTotalSiblingInventory(@PayPlan, @ParentMOS, @AmcosVersionId);
    IF (@TotalSiblingInventory IS NULL)
        RETURN 0.0;

    SET @FinalResult = CAST(@ChildInventory AS NUMERIC) / CAST(@TotalSiblingInventory
AS  NUMERIC                                                   );
    RETURN @FinalResult;
END;