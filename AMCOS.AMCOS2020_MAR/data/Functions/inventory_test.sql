
-- ========================================================================================================
-- Description:  Compute civilian base pay for pay plans that receive locality pay.
-- ========================================================================================================
CREATE FUNCTION [data].[inventory_test]
(
    @PP_Type NVARCHAR(20) = '',
    @YoS_Type NVARCHAR(20) = '',
    @AmcosVersionId INT = -1
)
RETURNS @Inventory TABLE
(
    [PayPlan] NVARCHAR(3) NULL,
    [CategoryGroupCode] NCHAR(2) NOT NULL,
    [CategorySubgroupCode] NVARCHAR(3) NOT NULL,
    [WageArea] NVARCHAR(3) NOT NULL,
    [GradeType] NVARCHAR(3) NOT NULL,
    [GradeLevel] TINYINT NOT NULL,
    [Step] TINYINT NOT NULL,
    [YOS] TINYINT NOT NULL
)
AS
BEGIN;

    WITH InventoryWithoutUnknown_CTE
    AS (SELECT DISTINCT
               PayPlan,
               CategoryGroupCode,
               CategorySubgroupCode,
               LocationId,
               GradeType,
               GradeLevel,
               Step,
               YOS
        FROM data.Inventory)
    INSERT INTO @Inventory
    (
        PayPlan,
        CategoryGroupCode,
        CategorySubgroupCode,
        WageArea,
        GradeType,
        GradeLevel,
        Step,
        YOS
    )
    SELECT DISTINCT
           PayPlan,
           CategoryGroupCode,
           CategorySubgroupCode,
           Inventory.LocationId,
           GradeType,
           GradeLevel,
           Step,
           YOS
    FROM data.Inventory Inventory
    WHERE NOT EXISTS
    (
        SELECT *
        FROM InventoryWithoutUnknown_CTE
        WHERE Inventory.PayPlan = InventoryWithoutUnknown_CTE.PayPlan
              AND Inventory.CategoryGroupCode = InventoryWithoutUnknown_CTE.CategoryGroupCode
              AND Inventory.CategorySubgroupCode = InventoryWithoutUnknown_CTE.CategorySubgroupCode
              AND ISNULL(Inventory.LocationId, 'ZZZ') = ISNULL(InventoryWithoutUnknown_CTE.LocationId, 'ZZZ')
              AND Inventory.GradeType = InventoryWithoutUnknown_CTE.GradeType
              AND Inventory.GradeLevel = InventoryWithoutUnknown_CTE.GradeLevel
    );
    RETURN;
END;