

CREATE PROCEDURE [crunch].[SumOfAveragesFixAO] @CrunchTime SMALLDATETIME
AS
BEGIN

    DECLARE @PayPlan NVARCHAR(3) = N'AO';

    /* Insert a zero amount row for all cost elements to solve the average of sums/sum of averages issue
   For each weapon system, also insert a zero amount row */

    /* Grade levels with inventory */
    BEGIN
        DECLARE @InventoryByCategorySubgroupGradeForPayPlan TABLE
        (
            PayPlan NVARCHAR(3) NOT NULL,
            CategoryGroupCode NVARCHAR(4) NOT NULL,
            CategorySubgroupCode NVARCHAR(4) NOT NULL,
            GradeType NVARCHAR(3) NOT NULL,
            GradeLevel TINYINT NULL
        );

        INSERT INTO @InventoryByCategorySubgroupGradeForPayPlan
        (
            PayPlan,
            CategoryGroupCode,
            CategorySubgroupCode,
            GradeType,
            GradeLevel
        )
        SELECT PayPlan,
               CategoryGroupCode,
               CategorySubGroupCode,
               GradeType,
               GradeLevel
        FROM crunch.InventoryByCategorySubgroupGradeForPayPlan(@PayPlan);
    END;

    /* WeaponSystem */
    BEGIN
        DECLARE @WeaponSystem TABLE
        (
            WeaponSystemId INT NOT NULL,
            WeaponSystemName NVARCHAR(50) NULL
        );

        INSERT INTO @WeaponSystem
        (
            WeaponSystemId,
            WeaponSystemName
        )
        SELECT WeaponSystemId,
               WeaponSystemName
        FROM lookup.WeaponSystem
        WHERE WeaponSystemId <> -1;
    END;

    DROP TABLE IF EXISTS #CostElementsTemplate;
    CREATE TABLE #CostElementsTemplate
    (
        CategoryGroupCode NCHAR(2) NOT NULL,
        CategorySubgroupCode NVARCHAR(3) NOT NULL,
        CostElementId INT NOT NULL,
        GradeType NVARCHAR(3) NOT NULL,
        GradeLevel TINYINT NOT NULL,
        WeaponSystemId INT NOT NULL
    );
    INSERT INTO #CostElementsTemplate
    (
        CategoryGroupCode,
        CategorySubgroupCode,
        CostElementId,
        GradeType,
        GradeLevel,
        WeaponSystemId
    )
    SELECT Inventory.CategoryGroupCode,
           Inventory.CategorySubgroupCode,
           CostElement.CostElementId,
           Inventory.GradeType,
           Inventory.GradeLevel,
           CASE
               WHEN CostElement.CostElementName LIKE '%weapon%' THEN
                   WeaponSystem.WeaponSystemId
               ELSE
                   -1
           END AS WeaponSystemId
    FROM @InventoryByCategorySubgroupGradeForPayPlan Inventory
        LEFT JOIN data.CostElement CostElement
            ON CostElement.PayPlan = Inventory.PayPlan
        CROSS JOIN @WeaponSystem WeaponSystem
    WHERE CostElement.PayPlan = @PayPlan;
    INSERT INTO crunch.Costs_AO
    (
        PayPlan,
        CMF,
        AOC,
        CostElementId,
        GradeType,
        GradeLevel,
        WeaponSystemId,
        Amount,
        CrunchTime
    )
    SELECT DISTINCT
           @PayPlan,
           a.CategoryGroupCode,
           a.CategorySubgroupCode,
           a.CostElementId,
           a.GradeType,
           a.GradeLevel,
           a.WeaponSystemId,
           0 AS Amount,
           @CrunchTime
    FROM #CostElementsTemplate a
    WHERE NOT EXISTS
    (
        SELECT *
        FROM data.Costs
        WHERE PayPlan = @PayPlan
              AND a.CategoryGroupCode = CategoryGroupCode
              AND a.CategorySubgroupCode = CategorySubGroupCode
              AND a.CostElementId = CostElementId
              AND a.GradeType = GradeType
              AND a.GradeLevel = GradeLevel
              AND a.WeaponSystemId = WeaponSystemId
    );
END;