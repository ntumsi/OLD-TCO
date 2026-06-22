

CREATE PROCEDURE [web].[PMProjectInventory]
    @UserId AS VARCHAR(50),
    @ProjectId AS INT
AS
SELECT *
INTO #tblInventory
FROM
(
    SELECT tblCat.UserId,
           tblCat.ProjectId,
           tblInv.SkillId,
           tblCat.PMCategoryName,
           tblCat.PayPlan,
           tblCat.CategoryGroupCode,
           tblCat.CategorySubGroupCode,
           tblCat.Area,
           tblCat.Location,
           (CASE
                WHEN PayPlan IN ( 'NE', 'NO', 'NWO', 'RE', 'RO', 'RWO' ) THEN
                    CONVERT(VARCHAR, ISNULL(activeDays, 0))
                ELSE
                    ''
            END
           ) AS activeDays,
           (CASE
                WHEN PayPlan = 'CCE' THEN
                    CONVERT(VARCHAR, ISNULL(overheadPct, 0))
                ELSE
                    ''
            END
           ) AS overheadPct,
           tblCat.StateCountry,
           FunctionalAreaText + ' (' + tblCat.FunctionalAreaCode + ')' AS FunctionalArea,
           CostCenterText + ' (' + tblCat.CostCenterCode + ')' AS CostCenter,
           (CASE
                WHEN tblCat.PayPlan = 'CCE'
                     AND tblCat.GradeLevel = 1 THEN
                    'A_PCT10'
                WHEN tblCat.PayPlan = 'CCE'
                     AND tblCat.GradeLevel = 2 THEN
                    'A_PCT25'
                WHEN tblCat.PayPlan = 'CCE'
                     AND tblCat.GradeLevel = 3 THEN
                    'A_MEDIAN'
                WHEN tblCat.PayPlan = 'CCE'
                     AND tblCat.GradeLevel = 4 THEN
                    'A_PCT75'
                WHEN tblCat.PayPlan = 'CCE'
                     AND tblCat.GradeLevel = 5 THEN
                    'A_PCT90'
                ELSE
                    tblCat.GradeType + CAST(tblCat.GradeLevel AS VARCHAR(5))
            END
           ) AS Grade,
           tblInv.[Year],
           tblInv.Amount
    FROM
    (
        SELECT tblA.UserId,
               tblA.ProjectId,
               tblB.CategoryName AS PMCategoryName,
               tblA.PayPlan,
               tblA.CategoryGroupCode,
               tblA.CategorySubGroupCode,
               (CASE
                    WHEN tblA.AreaCode = '0' THEN
                        '-ALL-'
                    WHEN tblE.AreaName IS NOT NULL THEN
                        tblA.AreaCode + ':' + tblE.AreaName
                    ELSE
                        tblA.AreaCode
                END
               ) AS Area,
               tblD.[Description] AS Location,
               tblA.GradeType,
               tblA.GradeLevel,
               tblA.SkillId,
               tblA.activeDays,
               tblA.overheadPct,
               tblA.StateCountry,
               tblA.FunctionalAreaCode,
               tblA.CostCenterCode
        FROM webuser.PMCategorySkill AS tblA
            INNER JOIN webuser.PMCategory AS tblB
                ON tblA.CategoryId = tblB.CategoryId
            INNER JOIN webuser.PMReport AS tblC
                ON tblA.CategoryId = tblC.CategoryId
                   AND tblA.PayPlan = tblC.PayPlan
            INNER JOIN lookup.LocalityRates AS tblD
                ON COALESCE(tblA.LocalityId, 0) = COALESCE(tblD.Id, 0)
            LEFT JOIN lookup.MetroArea tblE
                ON COALESCE(tblA.AreaCode, '__ALL__') = COALESCE(tblE.AreaCode, '__ALL__')
        WHERE (tblA.UserId = @UserId)
              AND (tblA.ProjectId = @ProjectId)
    ) tblCat
        JOIN webuser.PMCategorySkillInventory tblInv
            ON tblCat.UserId = tblInv.UserId
               AND tblCat.ProjectId = tblInv.ProjectId
               AND tblCat.SkillId = tblInv.SkillId
        JOIN webuser.PMProject p
            ON tblInv.ProjectId = p.ProjectId
               AND tblInv.[Year] < p.YearDuration
        LEFT JOIN lookup.GFEBS_FunctionalArea
            ON GFEBS_FunctionalArea.FunctionalAreaCode = tblCat.FunctionalAreaCode
        LEFT JOIN lookup.GFEBS_CostCenter
            ON GFEBS_CostCenter.CostCenterCode = tblCat.CostCenterCode
) AS tblData;

------------------------------------------------------------------ 
DECLARE @tbYears TABLE (iYear INT);
DECLARE @i INT,
        @iMax INT;
SELECT @i = 0,
       @iMax = YearDuration
FROM webuser.PMProject
WHERE ProjectId = @ProjectId;
IF @iMax >
(
    SELECT MAX([Year]) FROM #tblInventory
)
    SET @iMax =
(
    SELECT MAX([Year]) FROM #tblInventory
)   ;

WHILE @i < @iMax
BEGIN
    INSERT @tbYears
    (
        iYear
    )
    VALUES (@i);
    SET @i = @i + 1;
END;

SELECT a.UserId,
       a.ProjectId,
       a.SkillId,
       a.PMCategoryName,
       a.PayPlan,
       a.CategoryGroupCode,
       a.CategorySubGroupCode,
       a.Area,
       a.Location,
       activeDays,
       overheadPct,
       a.StateCountry,
       FunctionalArea,
       CostCenter,
       a.Grade,
       b.iYear AS 'Year',
       0 AS Amount
INTO #dummyInv
FROM
(
    SELECT DISTINCT
        UserId,
        ProjectId,
        SkillId,
        PMCategoryName,
        PayPlan,
        CategoryGroupCode,
        CategorySubGroupCode,
        Area,
        Location,
        activeDays,
        overheadPct,
        StateCountry,
        FunctionalArea,
        CostCenter,
        Grade
    FROM #tblInventory
) a
    JOIN @tbYears b
        ON 1 = 1;

INSERT INTO #tblInventory
SELECT b.*
FROM #tblInventory a
    RIGHT JOIN #dummyInv b
        ON a.UserId = b.UserId
           AND a.ProjectId = b.ProjectId
           AND a.SkillId = b.SkillId
           AND a.PMCategoryName = b.PMCategoryName
           AND a.PayPlan = b.PayPlan
           AND a.CategoryGroupCode = b.CategoryGroupCode
           AND a.CategorySubGroupCode = b.CategorySubGroupCode
           AND a.Area = b.Area
           AND a.Location = b.Location
           AND a.Grade = b.Grade
           AND a.[Year] = b.[Year]
           AND a.activeDays = b.activeDays
           AND a.overheadPct = b.overheadPct
           AND a.StateCountry = b.StateCountry
           AND a.FunctionalArea = b.FunctionalArea
           AND a.CostCenter = b.CostCenter
WHERE a.UserId IS NULL;

UPDATE #tblInventory
SET CategoryGroupCode = 'ALL'
WHERE CategoryGroupCode = '__ALL__';

UPDATE #tblInventory
SET CategorySubGroupCode = 'ALL'
WHERE CategorySubGroupCode = '__ALL__';

IF EXISTS (SELECT * FROM #tblInventory)
BEGIN
    DECLARE @SQL AS VARCHAR(1000),
            @GroupBy AS VARCHAR(500);
    SET @SQL = 'SELECT PMCategoryName, PayPlan, CategoryGroupCode, CategorySubGroupCode, ';
    SET @GroupBy = ' PMCategoryName, PayPlan, CategoryGroupCode, CategorySubGroupCode, ';

    IF EXISTS
    (
        SELECT *
        FROM #tblInventory
        WHERE PayPlan = 'CCE'
              OR PayPlan = 'GP'
    )
    BEGIN
        SET @SQL = @SQL + 'Area, ';
        SET @GroupBy = @GroupBy + 'Area, ';
    END;

    IF EXISTS (SELECT * FROM #tblInventory WHERE PayPlan = 'GS')
    BEGIN
        SET @SQL = @SQL + 'Location, ';
        SET @GroupBy = @GroupBy + 'Location, ';
    END;

    IF EXISTS
    (
        SELECT *
        FROM #tblInventory
        WHERE PayPlan IN ( 'NE', 'NO', 'NWO', 'RE', 'RO', 'RWO' )
    )
    BEGIN
        SET @SQL = @SQL + 'activeDays, ';
        SET @GroupBy = @GroupBy + 'activeDays, ';
    END;

    IF EXISTS (SELECT * FROM #tblInventory WHERE PayPlan = 'CCE')
    BEGIN
        SET @SQL = @SQL + 'overheadPct, ';
        SET @GroupBy = @GroupBy + 'overheadPct, ';
    END;

    IF EXISTS
    (
        SELECT *
        FROM #tblInventory
        WHERE PayPlan IN ( 'DB', 'DE', 'DJ', 'DK', 'GP', 'NH', 'NJ', 'NK' )
    )
    BEGIN
        SET @SQL = @SQL + 'StateCountry, FunctionalArea, CostCenter, ';
        SET @GroupBy = @GroupBy + 'StateCountry, FunctionalArea, CostCenter, ';
    END;

    SET @SQL = @SQL + 'Grade, [Year], Amount FROM #tblInventory ';
    SET @GroupBy = @GroupBy + 'Grade ';

    EXEC spCrossTabNumber @SQL, @GroupBy, NULL, '[Year]', 'Amount';
END;
ELSE
BEGIN
    SELECT *
    FROM #tblInventory;
END;