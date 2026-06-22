
CREATE PROCEDURE [web].[getCostView_CompareGS]
    @PayPlan NVARCHAR(3),
    @OccupationalGroupNumber NVARCHAR(7),
    @OccupationalSeriesNumber NVARCHAR(7),
    @localityID INT
AS
BEGIN
    DECLARE @localityRate FLOAT;
    SELECT @localityRate = Amount
    FROM lookup.LocalityRates
    WHERE Id =
    (
        SELECT LocalityId FROM lookup.LocalityRates WHERE Id = @localityID
    );

    DECLARE @DefaultSummary TABLE
    (
        CostElementId INT NULL
    );
    INSERT @DefaultSummary
    SELECT CostElementId
    FROM lookup.CostSummariesByPayPlan
    WHERE PayPlan = @PayPlan
          AND Name = 'Default';

    DECLARE @Data VARCHAR(300);
    DECLARE @Row VARCHAR(200);
    DECLARE @RowAlias VARCHAR(200);
    DECLARE @Column VARCHAR(50);
    DECLARE @Sum VARCHAR(50);
    SET @Data
        = '(SELECT APPN, CostElementCategory, CostElementName, GradeLevel, Avg(Amount) As avgAmount FROM #tblCosts GROUP BY APPN, CostElementCategory, CostElementName, GradeLevel) as tblCosts ';
    SET @Row = 'APPN,CostElementCategory,CostElementName';
    SET @RowAlias = 'APPN,CostElementCategory,CostElementName';
    SET @Column = 'GradeLevel';
    SET @Sum = 'avgAmount';

    -- Special Rates Only
    CREATE TABLE #tblCosts
    (
        [APPN] [VARCHAR](30) NULL,
        [CostElementCategory] [VARCHAR](40) NULL,
        [CostElementName] [VARCHAR](500) NULL,
        [TableNumber] [VARCHAR](5) NULL,
        [CostElementId] [INT] NULL,
        [GradeType] [VARCHAR](3) NULL,
        [GradeLevel] [INT] NULL,
        [Amount] [FLOAT] NULL
    );

    -------------------------------------------------------------------------------------- Get PROD cost view
    INSERT INTO #tblCosts
    SELECT tblCosts.APPN,
           tblCosts.CostElementCategory,
           tblCosts.CostElementName,
           tblCosts.WageArea,
           tblCosts.CostElementId,
           tblCosts.GradeType,
           tblCosts.GradeLevel,
           CASE tblCosts.Locality
               WHEN 0 THEN
                   tblCosts.Amount
               ELSE
                   tblCosts.Amount * @localityRate
           END
    FROM
    (
        SELECT Costs.PayPlan,
               Costs.APPN,
               Costs.CostElementCategory,
               Costs.CostElementName,
               Costs.WageArea,
               Costs.CostElementId,
               Costs.Model,
               Costs.Locality,
               Costs.GradeType,
               Costs.GradeLevel,
               Costs.Amount
        FROM compare.CostsProduction Costs
            JOIN lookup.CostElement CostElement
                ON CostElement.CostElementId = Costs.CostElementId
        WHERE Costs.PayPlan = @PayPlan
              AND
              (
                  @OccupationalGroupNumber = '__ALL__'
                  OR RIGHT(Costs.CategoryGroupCode, 4) = @OccupationalGroupNumber
              )
              AND
              (
                  @OccupationalSeriesNumber = '__ALL__'
                  OR RIGHT(Costs.CategorySubGroupCode, 4) = @OccupationalSeriesNumber
              )
    ) tblCosts
        INNER JOIN @DefaultSummary tblSum
            ON tblCosts.CostElementId = tblSum.CostElementId;

    EXEC web.spCrossTabGrades @Data, @Row, NULL, @Column, @Sum;

    -------------------------------------------------------------------------------------- Get TEST cost view
    TRUNCATE TABLE #tblCosts;

    INSERT INTO #tblCosts
    SELECT tblCosts.APPN,
           tblCosts.CostElementCategory,
           tblCosts.CostElementName,
           tblCosts.WageArea,
           tblCosts.CostElementId,
           tblCosts.GradeType,
           tblCosts.GradeLevel,
           CASE tblCosts.Locality
               WHEN 0 THEN
                   tblCosts.Amount
               ELSE
                   tblCosts.Amount * @localityRate
           END
    FROM
    (
        SELECT Costs.PayPlan,
               Costs.APPN,
               Costs.CostElementCategory,
               Costs.CostElementName,
               Costs.WageArea,
               Costs.CostElementId,
               Costs.Model,
               Costs.Locality,
               Costs.GradeType,
               Costs.GradeLevel,
               Costs.Amount
        FROM compare.CostsExternalTest Costs
            JOIN lookup.CostElement CostElement
                ON CostElement.CostElementId = Costs.CostElementId
        WHERE Costs.PayPlan = @PayPlan
              AND
              (
                  @OccupationalGroupNumber = '__ALL__'
                  OR RIGHT(Costs.CategoryGroupCode, 4) = @OccupationalGroupNumber
              )
              AND
              (
                  @OccupationalSeriesNumber = '__ALL__'
                  OR RIGHT(Costs.CategorySubGroupCode, 4) = @OccupationalSeriesNumber
              )
    ) tblCosts
        INNER JOIN @DefaultSummary tblSum
            ON tblCosts.CostElementId = tblSum.CostElementId;

    EXEC web.spCrossTabGrades @Data, @Row, NULL, @Column, @Sum;

    -------------------------------------------------------------------------------------- Get DEV cost view
    TRUNCATE TABLE #tblCosts;

    INSERT INTO #tblCosts
    SELECT tblCosts.APPN,
           tblCosts.CostElementCategory,
           tblCosts.CostElementName,
           tblCosts.WageArea,
           tblCosts.CostElementId,
           tblCosts.GradeType,
           tblCosts.GradeLevel,
           CASE tblCosts.Locality
               WHEN 0 THEN
                   tblCosts.Amount
               ELSE
                   tblCosts.Amount * @localityRate
           END
    FROM
    (
        SELECT Costs.PayPlan,
               Costs.APPN,
               Costs.CostElementCategory,
               Costs.CostElementName,
               Costs.WageArea,
               Costs.CostElementId,
               Costs.Amort AS Amortized,
               Costs.Model,
               Costs.Locality,
               Costs.GradeType,
               Costs.GradeLevel,
               Costs.Amount
        FROM data.Costs Costs
            JOIN lookup.CostElement CostElement
                ON CostElement.CostElementId = Costs.CostElementId
        WHERE Costs.PayPlan = @PayPlan
              AND
              (
                  @OccupationalGroupNumber = '__ALL__'
                  OR Costs.CategoryGroupCode = @OccupationalGroupNumber
              )
              AND
              (
                  @OccupationalSeriesNumber = '__ALL__'
                  OR Costs.CategorySubGroupCode = @OccupationalSeriesNumber
              )
    ) tblCosts
        INNER JOIN @DefaultSummary tblSum
            ON tblCosts.CostElementId = tblSum.CostElementId;

    EXEC web.spCrossTabGrades @Data, @Row, NULL, @Column, @Sum;
    DROP TABLE #tblCosts;
END;