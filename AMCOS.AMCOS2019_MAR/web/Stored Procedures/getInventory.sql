
CREATE PROCEDURE [web].[getInventory]
    @PayPlan NVARCHAR(3),
    @CategoryGroupCode NVARCHAR(7),
    @CategorySubGroupCode NVARCHAR(7),
    @AreaCode NVARCHAR(7) = '0'
AS
BEGIN
    SET NOCOUNT ON;

    --Resultset #0:  PayPlan
    SELECT PayPlan,
           [Description]
    FROM lookup.PayPlan
    WHERE PayPlan NOT IN ( 'GSS' );

    IF @PayPlan = 'CCE'
    BEGIN

        /* Resultset #1:  PayPlanTotal */
        BEGIN
            SELECT SUM(TOT_EMP)
            FROM dataload.OccupationalEmploymentStatisticsMetro
            WHERE TOT_EMP > 0;
        END;

        /* Resultset #2:  CategoryGroup */
        BEGIN
            SELECT CategoryGroupCode,
                   CategoryGroupCode + ' : ' + CategoryGroupDescription AS CategoryGroupDescription
            FROM data.CategoryGroupWithInventory
            WHERE PayPlan = 'CCE'
            ORDER BY CategoryGroupCode;
        END;

        /* Resultset #3:  CategoryGroupTotal */
        BEGIN
            IF (@CategoryGroupCode = '__ALL__')
                SELECT TOP (1)
                       @CategoryGroupCode = CategoryGroupCode
                FROM data.CategoryGroupWithInventory
                WHERE PayPlan = 'CCE'
                ORDER BY CategoryGroupCode;

            SELECT SUM(TOT_EMP)
            FROM dataload.OccupationalEmploymentStatisticsMetro
            WHERE SUBSTRING(SOC, 1, 2) + '-0000' = @CategoryGroupCode
                  AND TOT_EMP > 0;
        END;

        /* Resultset #4:  CategorySubGroup */
        BEGIN
            SELECT CategorySubGroupCode,
                   CategorySubGroupCode + ' : ' + CategorySubGroupDescription AS CategorySubGroupDescription
            FROM data.CategorySubgroupWithInventory
            WHERE PayPlan = @PayPlan
                  AND CategoryGroupCode = @CategoryGroupCode
            ORDER BY CategorySubGroupCode;
        END;

        /* Resultset #5:  CategorySubGroupTotal */
        BEGIN
            IF (@CategorySubGroupCode = '__ALL__')
                SELECT TOP (1)
                       @CategorySubGroupCode = CategorySubGroupCode
                FROM data.CategorySubgroupWithInventory
                WHERE PayPlan = @PayPlan
                      AND CategoryGroupCode = @CategoryGroupCode
                ORDER BY CategorySubGroupCode;

            SELECT SUM(TOT_EMP)
            FROM dataload.OccupationalEmploymentStatisticsMetro
            WHERE SOC = @CategorySubGroupCode
                  AND TOT_EMP > 0;
        END;

        --Resultset #6:  Inventory
        IF (@AreaCode = '0')
            SELECT TOP (1)
                   @AreaCode = AreaCode
            FROM dataload.OccupationalEmploymentStatisticsMetro
            WHERE SOC = @CategorySubGroupCode
            ORDER BY AreaCode;

        SELECT MetroArea.AreaName AS Area,
               OccupationalEmploymentStatisticsMetro.TOT_EMP,
               OccupationalEmploymentStatisticsMetro.EMP_PRSE
        FROM dataload.OccupationalEmploymentStatisticsMetro OccupationalEmploymentStatisticsMetro
            INNER JOIN lookup.MetroArea MetroArea
                ON MetroArea.AreaCode = OccupationalEmploymentStatisticsMetro.AreaCode
        WHERE OccupationalEmploymentStatisticsMetro.SOC = @CategorySubGroupCode
              AND OccupationalEmploymentStatisticsMetro.AreaCode = @AreaCode
        UNION
        SELECT 'zzzNational' AS Area,
               TOT_EMP,
               EMP_PRSE
        FROM dataload.OccupationalEmploymentStatisticsNational
        WHERE SOC = @CategorySubGroupCode
        ORDER BY Area;

        --Resultset #7:  Area
        SELECT AreaCode,
               AreaCode + ': ' + AreaName AS AreaName
        FROM lookup.MetroArea MetroArea
        WHERE AreaTypeCode IN ( 'M', 'S' )
              AND EXISTS
        (
            SELECT AreaCode
            FROM dataload.OccupationalEmploymentStatisticsMetro
            WHERE SOC = @CategorySubGroupCode
                  AND AreaCode = MetroArea.AreaCode
        )
        ORDER BY AreaCode;

    END;
    ELSE
    BEGIN
        DECLARE @From NVARCHAR(1000);
        DECLARE @YOS VARCHAR(5);

        SET @YOS = 'YOS';

        IF (@PayPlan = 'GG')
           OR (@PayPlan = 'GL')
           OR (@PayPlan = 'GS')
           OR (@PayPlan = 'GP')
           OR (@PayPlan = 'WL')
           OR (@PayPlan = 'WS')
           OR (@PayPlan = 'WG')
        BEGIN
            SET @YOS = 'Step';
        END;

        --Resultset #1:  PayPlanTotal
        SELECT SUM(Inventory)
        FROM data.Inventory
        WHERE PayPlan = @PayPlan
        GROUP BY PayPlan;

        --Resultset #2:  CategoryGroup
        SELECT CategoryGroupCode,
               CategoryGroupCode + ' : ' + CategoryGroupDescription AS CategoryGroupDescription
        FROM data.CategoryGroupWithInventory
        WHERE PayPlan = @PayPlan
        UNION
        SELECT '__ALL__',
               '-ALL-'
        ORDER BY CategoryGroupCode;

        --Resultset #3:  CategoryGroupTotal
        SELECT SUM(Inventory)
        FROM data.Inventory
        WHERE PayPlan = @PayPlan
              AND
              (
                  (CategoryGroupCode = @CategoryGroupCode)
                  OR @CategoryGroupCode = '__ALL__'
              );

        --Resultset #4:  CategorySubGroup
        SELECT CategorySubGroupCode,
               CategorySubGroupCode + ' : ' + CategorySubGroupDescription AS CategorySubGroupDescription
        FROM data.CategorySubgroupWithInventory
        WHERE PayPlan = @PayPlan
              AND CategoryGroupCode = @CategoryGroupCode
        UNION
        SELECT '__ALL__',
               '-ALL-'
        ORDER BY CategorySubGroupCode;

        --Resultset #5:  CategorySubGroupTotal
        SELECT SUM(Inventory)
        FROM data.Inventory
        WHERE PayPlan = @PayPlan
              AND
              (
                  (CategoryGroupCode = @CategoryGroupCode)
                  OR @CategoryGroupCode = '__ALL__'
              )
              AND
              (
                  (CategorySubGroupCode = @CategorySubGroupCode)
                  OR @CategorySubGroupCode = '__ALL__'
              );

        IF (@CategoryGroupCode = '__ALL__')
        BEGIN
            --Get Inventory Chart   
            SET @From
                = N' (SELECT GradeType + CAST(GradeLevel AS varchar(2)) As Grade, GradeLevel, Step_YOS As ' + @YOS
                  + N' , Inventory FROM data.Inventory WHERE PayPlan = ''' + @PayPlan + N''') tblInv ';
            EXEC web.spCrossTabGrades @From = @From,                     -- nvarchar(4000)
                                      @Select = @YOS,                    -- nvarchar(500)
                                      @PivotValueColumn = N'GradeLevel', -- nvarchar(100)
                                      @PivotSortColumn = N'GradeLevel',  -- nvarchar(100)
                                      @DataColumn = N'Inventory',        -- nvarchar(500)
                                      @GroupBy = @YOS,                   -- nvarchar(500)
                                      @OrderBy = @YOS,                   -- nvarchar(500)
                                      @Debug = 0;                        -- bit
            RETURN;
        END;

        IF (@CategorySubGroupCode = '__ALL__')
        BEGIN
            --Get Inventory Chart   
            SET @From
                = N' (SELECT GradeType + CAST(GradeLevel AS varchar(2)) As Grade, GradeLevel, Step_YOS As ' + @YOS
                  + N' , Inventory FROM data.Inventory WHERE PayPlan = ''' + @PayPlan
                  + N''' AND CategoryGroupCode = ''' + @CategoryGroupCode + N''') tblInv ';
            EXEC web.spCrossTabGrades @From = @From,                     -- nvarchar(4000)
                                      @Select = @YOS,                    -- nvarchar(500)
                                      @PivotValueColumn = N'GradeLevel', -- nvarchar(300)
                                      @PivotSortColumn = N'GradeLevel',  -- nvarchar(300)
                                      @DataColumn = N'Inventory',        -- nvarchar(500)
                                      @GroupBy = @YOS,                   -- nvarchar(500)
                                      @OrderBy = @YOS,                   -- nvarchar(500)
                                      @Debug = 0;                        -- bit
            RETURN;
        END;

        --Get Inventory Chart   
        SET @From
            = N' (SELECT GradeType + CAST(GradeLevel AS varchar(2)) As Grade, GradeLevel, Step_YOS As ' + @YOS
              + N' , Inventory FROM data.Inventory WHERE PayPlan = ''' + @PayPlan + N''' AND CategoryGroupCode = '''
              + @CategoryGroupCode + N''' AND CategorySubGroupCode = ''' + @CategorySubGroupCode + N''') tblInv ';
        EXEC web.spCrossTabGrades @From = @From,                     -- nvarchar(4000)
                                  @Select = @YOS,                    -- nvarchar(500)
                                  @PivotValueColumn = N'GradeLevel', -- nvarchar(100)
                                  @PivotSortColumn = N'GradeLevel',  -- nvarchar(100)
                                  @DataColumn = N'Inventory',        -- nvarchar(500)
                                  @GroupBy = @YOS,                   -- nvarchar(500)
                                  @OrderBy = @YOS,                   -- nvarchar(500)
                                  @Debug = 0;                        -- bit
    END;
    RETURN;
END;