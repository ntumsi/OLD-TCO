
CREATE PROCEDURE [web].[GetSkillsCascade]
    @PayPlan NVARCHAR(3),
    @CategoryGroupCode NVARCHAR(15),
    @CategorySubGroupCode NVARCHAR(15)
AS
BEGIN
    SET NOCOUNT ON;

    /* Pay Plan */
    SELECT PayPlan,
           [Description]
    FROM lookup.PayPlan
    ORDER BY [Description];

    /* Group */
    IF @PayPlan = 'CCE'
    BEGIN
        SELECT DISTINCT
               CategoryGroupCode,
               CategoryGroupCode + ' : ' + CategoryGroupDescription AS CategoryGroupDescription
        FROM data.CategoryGroup
        WHERE PayPlan = 'CCE'
        ORDER BY CategoryGroupCode;

        IF @CategoryGroupCode = '__ALL__'
            SELECT TOP 1
                   @CategoryGroupCode = CategoryGroupCode
            FROM data.CategoryGroup
            WHERE PayPlan = 'CCE';
    END;
    ELSE
        SELECT DISTINCT
               CategoryGroupCode,
               CategoryGroupCode + ' : ' + CategoryGroupDescription AS CategoryGroupDescription
        FROM data.CategoryGroupWithInventory
        WHERE PayPlan = @PayPlan
        UNION
        SELECT '__ALL__' AS CategoryGroupCode,
               '-ALL-' AS CategoryGroupDescription
        ORDER BY CategoryGroupCode;

    /* Sub Group */
    IF (@CategoryGroupCode = '__ALL__')
        SELECT '__ALL__' AS CategorySubGroupCode,
               '-ALL-' AS CategorySubGroupDescription;
    ELSE
    BEGIN
        IF @PayPlan = 'CCE'
        BEGIN
            SELECT DISTINCT
                   CategorySubGroupCode,
                   CategorySubGroupCode + ' : ' + CategorySubGroupDescription AS CategorySubGroupDescription
            FROM data.CategorySubgroup
            WHERE PayPlan = @PayPlan
                  AND CategoryGroupCode = @CategoryGroupCode;

            IF @CategorySubGroupCode = '__ALL__'
                SELECT TOP 1
                       @CategorySubGroupCode = CategorySubGroupCode
                FROM data.CategorySubgroup
                WHERE PayPlan = 'CCE'
                      AND CategoryGroupCode = @CategoryGroupCode;
        END;
        ELSE
            SELECT DISTINCT
                   CategorySubGroupCode,
                   CategorySubGroupCode + ' : ' + CategorySubGroupDescription AS CategorySubGroupDescription
            FROM data.CategorySubgroupWithInventory
            WHERE PayPlan = @PayPlan
                  AND CategoryGroupCode = @CategoryGroupCode
            UNION
            SELECT '__ALL__',
                   '-ALL-'
            ORDER BY CategorySubGroupCode;
    END;

    /* Area */
    /*  only applicable to CCE */
    IF @PayPlan = 'CCE'
    BEGIN
        SELECT AreaCode,
               AreaCode + ' : ' + AreaName AS AreaDescription
        FROM lookup.MetroArea
        WHERE AreaCode IN
              (
                  SELECT DISTINCT
                         AreaCode
                  FROM dataload.OccupationalEmploymentStatisticsMetro
                  WHERE SOC = @CategorySubGroupCode
              )
        ORDER BY AreaCode;
    END;
    ELSE
        SELECT '' AS AreaCode,
               '' AS AreaDescription
        WHERE 1 = 2;

    /* Locality */
    IF (@PayPlan = 'GS')
       OR (@PayPlan = 'SES')
        SELECT Id,
               [Description] + ' @ ' + CAST((Amount - 1) * 100 AS VARCHAR(50)) + '%' AS Locality
        FROM lookup.LocalityRates
        WHERE Id = LocalityId
              AND Amount > 0
        ORDER BY [Description];
    ELSE
        SELECT '__ALL__' AS Id,
               '' AS Locality;

    /* Grade */
    IF (@PayPlan = 'CCE')
        SELECT 1 AS Grade,
               'A_PCT10' AS GradeDescription
        UNION
        SELECT 2,
               'A_PCT25'
        UNION
        SELECT 3,
               'A_MEDIAN'
        UNION
        SELECT 4,
               'A_PCT75'
        UNION
        SELECT 5,
               'A_PCT90';

    ELSE IF (@PayPlan = 'SES')
        SELECT 1 AS Grade,
               'MIN' AS GradeDescription
        UNION
        SELECT 2,
               'AVG'
        UNION
        SELECT 3,
               'MAX';

    ELSE IF @PayPlan IN ( 'WG', 'WL', 'WS' )
    BEGIN
        IF (@CategoryGroupCode = '__ALL__')
            SELECT DISTINCT
                   GradeLevel AS Grade,
                   GradeType + CAST(GradeLevel AS VARCHAR(4)) AS GradeDescription
            FROM data.Inventory
            WHERE PayPlan = @PayPlan
            ORDER BY [GradeLevel];
        ELSE
            SELECT DISTINCT
                   GradeLevel AS Grade,
                   GradeType + CAST(GradeLevel AS VARCHAR(4)) AS GradeDescription
            FROM data.Inventory
            WHERE PayPlan = @PayPlan
                  AND CategoryGroupCode = @CategoryGroupCode
            ORDER BY GradeLevel;
    END;

    ELSE
    BEGIN
        IF (@CategoryGroupCode = '__ALL__')
           OR (@CategorySubGroupCode = '__ALL__')
            SELECT DISTINCT
                   GradeLevel AS Grade,
                   GradeType + CAST(GradeLevel AS VARCHAR(4)) AS GradeDescription
            FROM data.Inventory
            WHERE PayPlan = @PayPlan
            ORDER BY [GradeLevel];
        ELSE
            SELECT DISTINCT
                   GradeLevel AS Grade,
                   GradeType + CAST(GradeLevel AS VARCHAR(4)) AS GradeDescription
            FROM data.Inventory
            WHERE PayPlan = @PayPlan
                  AND CategoryGroupCode = @CategoryGroupCode
                  AND CategorySubGroupCode = @CategorySubGroupCode
            ORDER BY GradeLevel;
    END;
END;