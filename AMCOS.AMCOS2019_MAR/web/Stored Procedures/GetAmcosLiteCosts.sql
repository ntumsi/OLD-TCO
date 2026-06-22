
/*  
Description:	Provide the costs to AMCOS Lite screen
Author:			Roger, Gary, Greg
Create Date:	?
Param:			
Return:			For Weapon System Manpower cost summary
				1=Inventory by grade
				2=Minimum and maximum pay by grade
				3=Average cost for cost element by grade
				4=Army Cost Element Structure Names (For weapon system manpower cost summary)
				5=Average costs grouped by cost element category			
				6=Average cost of base pay cost element

				For Default summary
				1=Inventory by grade (used for chart report)
				2=Minimum and maximum pay by grade (used for chart report)
				3=Average cost for cost element by grade (used for tabular report)
				4=Average costs grouped by cost element category (used for chart report)
				5=Average cost of base pay cost element (used for chart report)

				For all other cost summaries
				1=Average cost for cost element by grade (used for tabular report)
Modified Date:  
Modification:   
*/
CREATE PROCEDURE [web].[GetAmcosLiteCosts]
    @PayPlan NVARCHAR(3),
    @CostSummaryId INTEGER = NULL,
    @CategoryGroupCode NVARCHAR(7) = '__ALL__',
    @CategorySubGroupCode NVARCHAR(7) = '__ALL__',
    @LocalityId INTEGER = NULL,
    @StateCountry VARCHAR(50) = NULL,
    @FunctionalAreaCode VARCHAR(100) = NULL,
    @CostCenterCode VARCHAR(100) = NULL,
    @InflationConversion NVARCHAR(25),
    @InflationYear NVARCHAR(4),
    @Debug BIT = 0
AS
BEGIN
    SET NOCOUNT ON;

    IF @CostSummaryId IS NOT NULL
        DECLARE @CostSummaryName NVARCHAR(50) = web.GetCostSummaryName(@CostSummaryId);
    DECLARE @LocalityRate FLOAT = web.GetLocalityRate(@LocalityId);

    CREATE TABLE #AmcosLite
    (
        appnGroup NVARCHAR(50) NULL,
        APPN NVARCHAR(50) NULL,
        CostElementCategory NVARCHAR(50) NULL,
        CostElementName NVARCHAR(250) NULL,
        Description NVARCHAR(3000) NULL,
        CostElementId INTEGER NULL,
        ShowOrder INTEGER NULL,
        Locality BIT NULL,
        ApplyInflation BIT NULL,
        GradeLevel TINYINT NULL,
        Grade NVARCHAR(5) NULL,
        WeaponSystemId INTEGER NULL,
        WeaponSystemName NVARCHAR(50) NULL,
        Amount FLOAT NULL,
        ArmyCesTitle NVARCHAR(250) NULL,
        OsdCapeCesTitle NVARCHAR(250) NULL
    ) ON [PRIMARY];

    IF (
           @PayPlan = 'AE'
           OR @PayPlan = 'AO'
           OR @PayPlan = 'AWO'
           OR @PayPlan = 'NE'
           OR @PayPlan = 'NO'
           OR @PayPlan = 'NWO'
           OR @PayPlan = 'RE'
           OR @PayPlan = 'RO'
           OR @PayPlan = 'RWO'
           OR @PayPlan = 'SES'
           OR @PayPlan = 'WG'
           OR @PayPlan = 'WL'
           OR @PayPlan = 'WS'
       )
    BEGIN
        /* CostSummaryName <> Detailed, Training, or Ancillary */
        IF (@CostSummaryName <> 'Detailed')
           AND (@CostSummaryName <> 'Training')
           AND (@CostSummaryName <> 'Ancillary')
        BEGIN
            /* Costs for each cost element by grade */
            INSERT INTO #AmcosLite
            (
                appnGroup,
                APPN,
                CostElementCategory,
                CostElementName,
                Description,
                CostElementId,
                ShowOrder,
                Locality,
                ApplyInflation,
                GradeLevel,
                Grade,
                WeaponSystemId,
                Amount,
                ArmyCesTitle,
                OsdCapeCesTitle
            )
            SELECT Costs.AppropriationGroup,
                   Costs.APPN,
                   Costs.CostElementCategory,
                   Costs.CostElementName,
                   Costs.Description,
                   Costs.CostElementId,
                   Costs.showOrder,
                   Costs.Locality,
                   Costs.ApplyInflation,
                   Costs.GradeLevel,
                   Grade = CASE Costs.PayPlan
                               WHEN 'SES' THEN
                                   CASE Costs.GradeLevel
                                       WHEN 1 THEN
                                           'MIN'
                                       WHEN 2 THEN
                                           'AVG'
                                       WHEN 3 THEN
                                           'MAX'
                                       ELSE
                                           CAST(Costs.GradeLevel AS NVARCHAR(3))
                                   END
                               ELSE
                                   CAST(Costs.GradeType AS NVARCHAR(3)) + CAST(Costs.GradeLevel AS NVARCHAR(2))
                           END,
                   Costs.WeaponSystemId,
                   Costs.Amount,
                   Costs.ArmyCesTitle,
                   Costs.OsdCapeCesTitle
            FROM data.Costs Costs
                INNER JOIN lookup.CostSummaryElement CostSummaryElement
                    ON CostSummaryElement.CostElementId = Costs.CostElementId
            WHERE Costs.PayPlan = @PayPlan
                  AND
                  (
                      Costs.CategoryGroupCode = @CategoryGroupCode
                      OR @CategoryGroupCode = '__ALL__'
                  )
                  AND
                  (
                      Costs.CategorySubGroupCode = @CategorySubGroupCode
                      OR @CategorySubGroupCode = '__ALL__'
                  )
                  AND CostSummaryElement.SummaryId = @CostSummaryId;

            IF @CostSummaryName = 'Default'
            BEGIN
                /* Inventory */
                SELECT CAST(GradeType AS NVARCHAR(3)) + CAST(GradeLevel AS NVARCHAR(2)) AS Grade,
                       SUM(Inventory) AS Inventory
                FROM data.Inventory
                WHERE PayPlan = @PayPlan
                      AND
                      (
                          CategoryGroupCode = @CategoryGroupCode
                          OR @CategoryGroupCode = '__ALL__'
                      )
                      AND
                      (
                          CategorySubGroupCode = @CategorySubGroupCode
                          OR @CategorySubGroupCode = '__ALL__'
                      )
                GROUP BY GradeLevel,
                         CAST(GradeType AS NVARCHAR(3)) + CAST(GradeLevel AS NVARCHAR(2))
                ORDER BY GradeLevel;

                /* Min and Max Pay */
                SELECT Grade,
                       GradeLevel,
                       MinimumPay,
                       MaximumPay
                FROM web.GetMinMaxPay(@PayPlan, @CategoryGroupCode, @CategorySubGroupCode, NULL, NULL)
                ORDER BY GradeLevel;
            END;
        END;

        /* CostSummaryName = Detailed, Training, or Ancillary */
        IF (@CostSummaryName = 'Detailed')
           OR (@CostSummaryName = 'Training')
           OR (@CostSummaryName = 'Ancillary')
        BEGIN
            INSERT INTO #AmcosLite
            (
                appnGroup,
                APPN,
                CostElementCategory,
                CostElementName,
                Description,
                CostElementId,
                ShowOrder,
                Locality,
                ApplyInflation,
                GradeLevel,
                Grade,
                Amount
            )
            SELECT Costs.AppropriationGroup,
                   Costs.APPN,
                   Costs.CostElementCategory,
                   Costs.CostElementName,
                   Costs.Description,
                   Costs.CostElementId,
                   Costs.showOrder,
                   Costs.Locality,
                   Costs.ApplyInflation,
                   Costs.GradeLevel,
                   Grade = CASE Costs.PayPlan
                               WHEN 'SES' THEN
                                   CASE Costs.GradeLevel
                                       WHEN 1 THEN
                                           'MIN'
                                       WHEN 2 THEN
                                           'AVG'
                                       WHEN 3 THEN
                                           'MAX'
                                       ELSE
                                           CAST(Costs.GradeLevel AS NVARCHAR(3))
                                   END
                               ELSE
                                   CAST(Costs.GradeType AS NVARCHAR(3)) + CAST(Costs.GradeLevel AS NVARCHAR(2))
                           END,
                   Costs.Amount
            FROM data.Costs Costs
                INNER JOIN lookup.CostSummaryElement CostSummaryElement
                    ON CostSummaryElement.CostElementId = Costs.CostElementId
            WHERE Costs.PayPlan = @PayPlan
                  AND
                  (
                      Costs.CategoryGroupCode = @CategoryGroupCode
                      OR @CategoryGroupCode = '__ALL__'
                  )
                  AND
                  (
                      Costs.CategorySubGroupCode = @CategorySubGroupCode
                      OR @CategorySubGroupCode = '__ALL__'
                  )
                  AND CostSummaryElement.SummaryId = @CostSummaryId
                  AND Costs.CostElementName <> 'Avg Cost of Weapon Specific Training'
            UNION ALL
            SELECT Costs.AppropriationGroup,
                   Costs.APPN,
                   Costs.CostElementCategory,
                   Costs.CostElementName,
                   Costs.Description,
                   Costs.CostElementId,
                   Costs.showOrder,
                   Costs.Locality,
                   Costs.ApplyInflation,
                   Costs.GradeLevel,
                   Grade = CASE Costs.PayPlan
                               WHEN 'SES' THEN
                                   CASE Costs.GradeLevel
                                       WHEN 1 THEN
                                           'MIN'
                                       WHEN 2 THEN
                                           'AVG'
                                       WHEN 3 THEN
                                           'MAX'
                                       ELSE
                                           CAST(Costs.GradeLevel AS NVARCHAR(3))
                                   END
                               ELSE
                                   CAST(Costs.GradeType AS NVARCHAR(3)) + CAST(Costs.GradeLevel AS NVARCHAR(2))
                           END,
                   AVG(Costs.Amount)
            FROM data.Costs Costs
                INNER JOIN lookup.CostSummaryElement CostSummaryElement
                    ON CostSummaryElement.CostElementId = Costs.CostElementId
            WHERE Costs.PayPlan = @PayPlan
                  AND
                  (
                      Costs.CategoryGroupCode = @CategoryGroupCode
                      OR @CategoryGroupCode = '__ALL__'
                  )
                  AND
                  (
                      Costs.CategorySubGroupCode = @CategorySubGroupCode
                      OR @CategorySubGroupCode = '__ALL__'
                  )
                  AND CostSummaryElement.SummaryId = @CostSummaryId
                  AND Costs.CostElementName = 'Avg Cost of Weapon Specific Training'
            GROUP BY Costs.PayPlan,
                     Costs.AppropriationGroup,
                     Costs.APPN,
                     Costs.CostElementCategory,
                     Costs.CostElementName,
                     Costs.Description,
                     Costs.CostElementId,
                     Costs.WeaponSystemId,
                     Costs.showOrder,
                     Costs.Locality,
                     Costs.ApplyInflation,
                     Costs.GradeType,
                     Costs.GradeLevel;
        END;

        /* CostSummary = ALL */
        IF (@CostSummaryId IS NULL)
        BEGIN
            INSERT INTO #AmcosLite
            (
                appnGroup,
                APPN,
                CostElementCategory,
                CostElementName,
                Description,
                CostElementId,
                ShowOrder,
                Locality,
                ApplyInflation,
                GradeLevel,
                Grade,
                Amount
            )
            SELECT AppropriationGroup,
                   APPN,
                   CostElementCategory,
                   CostElementName,
                   Description,
                   CostElementId,
                   showOrder,
                   Locality,
                   ApplyInflation,
                   GradeLevel,
                   Grade = CASE Costs.PayPlan
                               WHEN 'SES' THEN
                                   CASE GradeLevel
                                       WHEN 1 THEN
                                           'MIN'
                                       WHEN 2 THEN
                                           'AVG'
                                       WHEN 3 THEN
                                           'MAX'
                                       ELSE
                                           CAST(GradeLevel AS NVARCHAR(3))
                                   END
                               ELSE
                                   CAST(GradeType AS NVARCHAR(3)) + CAST(GradeLevel AS NVARCHAR(2))
                           END,
                   Amount
            FROM data.Costs
            WHERE PayPlan = @PayPlan
                  AND
                  (
                      CategoryGroupCode = @CategoryGroupCode
                      OR @CategoryGroupCode = '__ALL__'
                  )
                  AND
                  (
                      CategorySubGroupCode = @CategorySubGroupCode
                      OR @CategorySubGroupCode = '__ALL__'
                  )
                  AND CostElementName <> 'Avg Cost of Weapon Specific Training'
            UNION ALL
            SELECT AppropriationGroup,
                   APPN,
                   CostElementCategory,
                   CostElementName,
                   Description,
                   CostElementId,
                   showOrder,
                   Locality,
                   ApplyInflation,
                   GradeLevel,
                   Grade = CASE Costs.PayPlan
                               WHEN 'SES' THEN
                                   CASE GradeLevel
                                       WHEN 1 THEN
                                           'MIN'
                                       WHEN 2 THEN
                                           'AVG'
                                       WHEN 3 THEN
                                           'MAX'
                                       ELSE
                                           CAST(GradeLevel AS NVARCHAR(3))
                                   END
                               ELSE
                                   CAST(GradeType AS NVARCHAR(3)) + CAST(GradeLevel AS NVARCHAR(2))
                           END,
                   AVG(Amount)
            FROM data.Costs
            WHERE PayPlan = @PayPlan
                  AND
                  (
                      CategoryGroupCode = @CategoryGroupCode
                      OR @CategoryGroupCode = '__ALL__'
                  )
                  AND
                  (
                      CategorySubGroupCode = @CategorySubGroupCode
                      OR @CategorySubGroupCode = '__ALL__'
                  )
                  AND CostElementName = 'Avg Cost of Weapon Specific Training'
            GROUP BY PayPlan,
                     AppropriationGroup,
                     APPN,
                     CostElementCategory,
                     CostElementName,
                     Description,
                     CostElementId,
                     WeaponSystemId,
                     showOrder,
                     Locality,
                     ApplyInflation,
                     GradeType,
                     GradeLevel;
        END;
    END;

    /* GFEBS Pay Plans*/
    IF (
           @PayPlan = 'DB'
           OR @PayPlan = 'DE'
           OR @PayPlan = 'DJ'
           OR @PayPlan = 'DK'
           OR @PayPlan = 'GP'
           OR @PayPlan = 'NH'
           OR @PayPlan = 'NJ'
           OR @PayPlan = 'NK'
       )
    BEGIN
        /* Costs for each cost element by grade */
        INSERT INTO #AmcosLite
        (
            appnGroup,
            APPN,
            CostElementCategory,
            CostElementName,
            Description,
            CostElementId,
            ShowOrder,
            Locality,
            ApplyInflation,
            GradeLevel,
            Grade,
            WeaponSystemId,
            WeaponSystemName,
            Amount,
            ArmyCesTitle,
            OsdCapeCesTitle
        )
        SELECT AppropriationGroup,
               APPN,
               CostElementCategory,
               CostElementName,
               Description,
               CostElementId,
               showOrder,
               Locality,
               ApplyInflation,
               GradeLevel,
               CAST(GradeType AS NVARCHAR(3)) + CAST(GradeLevel AS NVARCHAR(2)) AS Grade,
               NULL AS WeaponSystemId,
               NULL AS WeaponSystemName,
               Amount,
               NULL AS ArmyCesTitle,
               NULL AS OsdCapeCesTitle
        FROM data.Costs
        WHERE PayPlan = @PayPlan
              AND
              (
                  CategoryGroupCode = @CategoryGroupCode
                  OR @CategoryGroupCode = '__ALL__'
              )
              AND
              (
                  CategorySubGroupCode = @CategorySubGroupCode
                  OR @CategorySubGroupCode = '__ALL__'
              )
              AND
              (
                  StateCountry = @StateCountry
                  OR @StateCountry = '__ALL__'
              )
              AND
              (
                  FunctionalAreaCode = @FunctionalAreaCode
                  OR @FunctionalAreaCode = '__ALL__'
              )
              AND
              (
                  CostCenterCode = @CostCenterCode
                  OR @CostCenterCode = '__ALL__'
              );

        IF @CostSummaryName = 'Default'
        BEGIN
            /* Inventory */
            SELECT CAST(GradeType AS NVARCHAR(3)) + CAST(GradeLevel AS NVARCHAR(2)) AS Grade,
                   SUM(Inventory) AS Inventory
            FROM data.Inventory
            WHERE PayPlan = @PayPlan
                  AND
                  (
                      CategoryGroupCode = @CategoryGroupCode
                      OR @CategoryGroupCode = '__ALL__'
                  )
                  AND
                  (
                      CategorySubGroupCode = @CategorySubGroupCode
                      OR @CategorySubGroupCode = '__ALL__'
                  )
                  AND
                  (
                      StateCountry = @StateCountry
                      OR @StateCountry = '__ALL__'
                  )
                  AND
                  (
                      FunctionalAreaCode = @FunctionalAreaCode
                      OR @FunctionalAreaCode = '__ALL__'
                  )
                  AND
                  (
                      CostCenterCode = @CostCenterCode
                      OR @CostCenterCode = '__ALL__'
                  )
            GROUP BY GradeLevel,
                     CAST(GradeType AS NVARCHAR(3)) + CAST(GradeLevel AS NVARCHAR(2));

            /* Min and Max Pay */
            SELECT Grade,
                   GradeLevel,
                   MinimumPay,
                   MaximumPay
            FROM web.GetMinMaxPay(@PayPlan, @CategoryGroupCode, @CategorySubGroupCode, @LocalityId, NULL);
        END;
    END;

    /* General Service Pay Plans */
    IF (@PayPlan = 'GG' OR @PayPlan = 'GL' OR @PayPlan = 'GS')
    BEGIN
        /* Costs for each cost element by grade */
        INSERT INTO #AmcosLite
        (
            appnGroup,
            APPN,
            CostElementCategory,
            CostElementName,
            Description,
            CostElementId,
            ShowOrder,
            Locality,
            ApplyInflation,
            GradeLevel,
            Grade,
            WeaponSystemId,
            WeaponSystemName,
            Amount,
            ArmyCesTitle,
            OsdCapeCesTitle
        )
        SELECT AppropriationGroup,
               APPN,
               CostElementCategory,
               CostElementName,
               Description,
               CostElementId,
               showOrder,
               Locality,
               ApplyInflation,
               GradeLevel,
               Grade,
               NULL AS WeaponSystemId,
               NULL AS WeaponSystemName,
               CASE
                   WHEN Costs.Locality = 1 THEN
                       Amount * @LocalityRate
                   ELSE
                       Amount
               END AS Amount,
               NULL AS ArmyCesTitle,
               NULL AS OsdCapeCesTitle
        FROM
        (
            SELECT Costs.PayPlan,
                   Costs.AppropriationGroup,
                   Costs.APPN,
                   Costs.CostElementCategory,
                   Costs.CostElementName,
                   Costs.Description,
                   Costs.WageArea,
                   Costs.CostElementId,
                   Costs.showOrder,
                   Costs.Locality,
                   Costs.ApplyInflation,
                   Costs.Amort AS Amortized,
                   Costs.Model,
                   Costs.GradeLevel,
                   CAST(Costs.GradeType AS NVARCHAR(3)) + CAST(Costs.GradeLevel AS NVARCHAR(2)) AS Grade,
                   Costs.Amount
            FROM data.Costs Costs
                INNER JOIN lookup.CostSummaryElement CostSummaryElement
                    ON CostSummaryElement.CostElementId = Costs.CostElementId
            WHERE CostSummaryElement.SummaryId = @CostSummaryId
                  AND Costs.PayPlan = @PayPlan
                  AND
                  (
                      @CategoryGroupCode = '__ALL__'
                      OR Costs.CategoryGroupCode = @CategoryGroupCode
                  )
                  AND
                  (
                      @CategorySubGroupCode = '__ALL__'
                      OR Costs.CategorySubGroupCode = @CategorySubGroupCode
                  )
        ) Costs;

        IF @CostSummaryName = 'Default'
        BEGIN
            /* Inventory */
            SELECT CAST(GradeType AS NVARCHAR(3)) + CAST(GradeLevel AS NVARCHAR(2)) AS Grade,
                   SUM(Inventory) AS Inventory
            FROM data.Inventory
            WHERE PayPlan = @PayPlan
                  AND
                  (
                      CategoryGroupCode = @CategoryGroupCode
                      OR @CategoryGroupCode = '__ALL__'
                  )
                  AND
                  (
                      CategorySubGroupCode = @CategorySubGroupCode
                      OR @CategorySubGroupCode = '__ALL__'
                  )
            GROUP BY GradeLevel,
                     CAST(GradeType AS NVARCHAR(3)) + CAST(GradeLevel AS NVARCHAR(2));

            /* Min and Max Pay */
            SELECT Grade,
                   GradeLevel,
                   MinimumPay,
                   MaximumPay
            FROM web.GetMinMaxPay(@PayPlan, @CategoryGroupCode, @CategorySubGroupCode, @LocalityId, NULL);
        END;

        IF (@CostSummaryId IS NULL)
        BEGIN
            /* Costs for each cost element by grade */
            INSERT INTO #AmcosLite
            (
                appnGroup,
                APPN,
                CostElementCategory,
                CostElementName,
                Description,
                CostElementId,
                ShowOrder,
                Locality,
                ApplyInflation,
                GradeLevel,
                Grade,
                WeaponSystemId,
                WeaponSystemName,
                Amount,
                ArmyCesTitle,
                OsdCapeCesTitle
            )
            SELECT AppropriationGroup,
                   APPN,
                   CostElementCategory,
                   CostElementName,
                   Description,
                   CostElementId,
                   showOrder,
                   Locality,
                   ApplyInflation,
                   GradeLevel,
                   CAST(GradeType AS NVARCHAR(3)) + CAST(GradeLevel AS NVARCHAR(2)) AS Grade,
                   NULL AS WeaponSystemId,
                   NULL AS WeaponSystemName,
                   CASE
                       WHEN Costs.Locality = 1 THEN
                           Amount * @LocalityRate
                       ELSE
                           Amount
                   END AS Amount,
                   NULL AS ArmyCesTitle,
                   NULL AS OsdCapeCesTitle
            FROM data.Costs
            WHERE PayPlan = @PayPlan
                  AND
                  (
                      @CategoryGroupCode = '__ALL__'
                      OR CategoryGroupCode = @CategoryGroupCode
                  )
                  AND
                  (
                      @CategorySubGroupCode = '__ALL__'
                      OR CategorySubGroupCode = @CategorySubGroupCode
                  );

            IF @CostSummaryName = 'Default'
            BEGIN
                /* Inventory */
                SELECT CAST(GradeType AS NVARCHAR(3)) + CAST(GradeLevel AS NVARCHAR(2)) AS Grade,
                       SUM(Inventory) AS Inventory
                FROM data.Inventory
                WHERE PayPlan = @PayPlan
                GROUP BY GradeLevel,
                         CAST(GradeType AS NVARCHAR(3)) + CAST(GradeLevel AS NVARCHAR(2));

                /* Min and Max Pay */
                SELECT Grade,
                       GradeLevel,
                       MinimumPay,
                       MaximumPay
                FROM web.GetMinMaxPay(@PayPlan, @CategoryGroupCode, @CategorySubGroupCode, @LocalityId, NULL);
            END;
        END;
    END;

    /* Apply inflation */
    UPDATE #AmcosLite
    SET Amount = i.Amount * A.Amount
    FROM #AmcosLite A
        INNER JOIN lookup.JicInflationRates i
            ON @InflationConversion = i.ConversionType
               AND @InflationYear = i.Year
               AND A.APPN = i.Appropriation
    WHERE A.ApplyInflation = 1;

    /* Include Weapon System Name instead of Id */
    UPDATE #AmcosLite
    SET WeaponSystemName = WeaponSystem.WeaponSystemName
    FROM #AmcosLite AmcosLite
        INNER JOIN lookup.WeaponSystem WeaponSystem
            ON WeaponSystem.WeaponSystemId = AmcosLite.WeaponSystemId
    WHERE WeaponSystem.WeaponSystemName <> 'Not Applicable';

    /* Pivot results on grade level */
    DECLARE @From NVARCHAR(1000);
    IF (@CostSummaryName = 'Detailed')
       OR (@CostSummaryName = 'Training')
       OR (@CostSummaryName = 'Ancillary')
        SET @From
            = N'(SELECT appnGroup,APPN,CostElementCategory,CostElementName,Description,ShowOrder,GradeLevel,Grade,Amount = CASE WHEN CostElementName = ''Avg Cost of Weapon Specific Training'' THEN SUM(Amount) WHEN CostElementName LIKE ''Actual Cost%'' THEN SUM(Amount) ELSE AVG(Amount) END FROM #AmcosLite GROUP BY appnGroup,APPN,CostElementCategory,CostElementName,Description,ShowOrder,GradeLevel,Grade) as Costs ';
    ELSE
        SET @From
            = N'(SELECT appnGroup,APPN,CostElementCategory,CostElementName,Description,ShowOrder,GradeLevel,Grade,Avg(Amount) AS Amount FROM #AmcosLite GROUP BY appnGroup,APPN,CostElementCategory,CostElementName,Description,ShowOrder,GradeLevel,Grade) as Costs ';

    DECLARE @Select NVARCHAR(500)
        = N'appnGroup,APPN,CostElementCategory AS [Cost Element Category],CostElementName AS [Cost Element Name],Description,ShowOrder';
    DECLARE @PivotValueColumn NVARCHAR(100) = N'Grade';
    DECLARE @PivotSortColumn NVARCHAR(100) = N'GradeLevel';
    DECLARE @DataColumn NVARCHAR(100) = N'Amount';
    DECLARE @GroupBy NVARCHAR(500) = N'appnGroup,APPN,CostElementCategory,CostElementName,Description,ShowOrder';
    DECLARE @OrderBy NVARCHAR(500) = N'appnGroup,APPN,CostElementCategory,CostElementName,Description,ShowOrder';

    IF @CostSummaryName = 'Weapon System Manpower'
    BEGIN
        SET @From = REPLACE(@From, 'CostElementName', 'ArmyCesTitle,OsdCapeCesTitle,WeaponSystemName,CostElementName');
        SET @GroupBy
            = REPLACE(@GroupBy, 'CostElementName', 'ArmyCesTitle,OsdCapeCesTitle,WeaponSystemName,CostElementName');
        SET @OrderBy
            = REPLACE(@OrderBy, 'CostElementName', 'ArmyCesTitle,OsdCapeCesTitle,WeaponSystemName,CostElementName');
        SET @Select
            = REPLACE(
                         @Select,
                         'CostElementName AS [Cost Element Name]',
                         'ArmyCesTitle AS [Army CES Title],OsdCapeCesTitle AS [OSD CAPE CES Title],WeaponSystemName AS [Weapon System Name],CostElementName AS [Cost Element Name]'
                     );
    END;

    EXEC web.spCrossTabGrades @From = @From,                         -- nvarchar(4000)
                              @Select = @Select,                     -- nvarchar(500)
                              @PivotValueColumn = @PivotValueColumn, -- nvarchar(100)
                              @PivotSortColumn = @PivotSortColumn,   -- nvarchar(100)
                              @DataColumn = @DataColumn,             -- nvarchar(100)
                              @GroupBy = @GroupBy,                   -- nvarchar(500)
                              @OrderBy = @OrderBy,                   -- nvarchar(500)
                              @Debug = @Debug;                       -- bit

    IF @CostSummaryName = 'Default'
    BEGIN;
        WITH AmcosLiteChart_CTE (appnGroup, APPN, CostElementCategory, CostElementName, ShowOrder, Grade, GradeLevel,
                                 Amount
                                )
        AS (SELECT appnGroup,
                   APPN,
                   CostElementCategory,
                   CostElementName,
                   ShowOrder,
                   Grade,
                   GradeLevel,
                   Amount = CASE CostElementName
                                WHEN 'Avg Cost of Weapon Specific Training' THEN
                                    SUM(Amount)
                                WHEN 'Actual Cost of Weapon Specific Training' THEN
                                    SUM(Amount)
                                ELSE
                                    AVG(Amount)
                            END
            FROM #AmcosLite
            GROUP BY appnGroup,
                     APPN,
                     CostElementCategory,
                     CostElementName,
                     ShowOrder,
                     Grade,
                     GradeLevel)
        SELECT AmcosLiteChart_CTE.Grade,
               AmcosLiteChart_CTE.GradeLevel,
               AmcosLiteChart_CTE.CostElementCategory,
               MIN(AmcosLiteChart_CTE.ShowOrder) AS ShowOrder,
               SUM(Amount) AS Amount
        FROM AmcosLiteChart_CTE
        GROUP BY AmcosLiteChart_CTE.Grade,
                 AmcosLiteChart_CTE.GradeLevel,
                 AmcosLiteChart_CTE.CostElementCategory
        ORDER BY AmcosLiteChart_CTE.GradeLevel,
                 MIN(AmcosLiteChart_CTE.ShowOrder);
    END;

    IF @CostSummaryName = 'Default'
    BEGIN
        SELECT Grade,
               GradeLevel,
               AVG(Amount) AS AveragePay
        FROM #AmcosLite
        WHERE CostElementName LIKE '%base pay%'
        GROUP BY Grade,
                 GradeLevel
        ORDER BY GradeLevel;
    END;
END;