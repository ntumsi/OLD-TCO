

CREATE PROCEDURE [web].[PMProjectInventory]
    @ProjectId AS INT,
    @SilentRunning AS BIT = NULL --optional parameter if suppresion of the results is desired
AS
SELECT tblData.ProjectId,
       tblData.SkillId,
       tblData.PMCategoryName,
       tblData.Uic,
       tblData.PayPlan,
       tblData.CategoryGroupCode,
       tblData.CategorySubgroupCode,
       tblData.ActiveDutyDays,
       tblData.OverheadPercent,
       tblData.Grade,
       tblData.Year,
       tblData.Amount
INTO #ProjectInventory
FROM
(
    SELECT PMCategorySkillReport.ProjectId,
           PMCategorySkillInventory.SkillId,
           PMCategorySkillReport.PMCategoryName,
           PMCategorySkillReport.Uic,
           PMCategorySkillReport.PayPlan,
           PMCategorySkillReport.CategoryGroupCode,
           PMCategorySkillReport.CategorySubgroupCode,
           PMCategorySkillReport.ActiveDutyDays,
           PMCategorySkillReport.OverheadPercent,
           web.FormatGradeLevel(PMCategorySkillReport.PayPlan, PMCategorySkillReport.GradeLevel) AS Grade,
           PMCategorySkillInventory.[Year],
           PMCategorySkillInventory.Amount
    FROM
    (
        SELECT PMCategory.ProjectId,
               PMCategory.CategoryName AS PMCategoryName,
               PMCategorySkill.Uic,
               PMCategorySkill.PayPlan,
               PMCategorySkill.CategoryGroupCode,
               PMCategorySkill.CategorySubgroupCode,
               PMCategorySkill.GradeLevel,
               PMCategorySkill.SkillId,
               PMCategorySkill.ActiveDutyDays,
               PMCategorySkill.OverheadPercent
        FROM webuser.PMCategorySkill AS PMCategorySkill
            INNER JOIN webuser.PMCategory AS PMCategory
                ON PMCategorySkill.CategoryId = PMCategory.CategoryId
            INNER JOIN webuser.PMReport AS PMReport
                ON PMCategorySkill.CategoryId = PMReport.CategoryId
                   AND PMCategorySkill.PayPlan = PMReport.PayPlan
        WHERE PMCategory.ProjectId = @ProjectId
    ) PMCategorySkillReport
        JOIN webuser.PMCategorySkillInventory PMCategorySkillInventory
            ON PMCategorySkillReport.SkillId = PMCategorySkillInventory.SkillId
        JOIN webuser.PMProject PMProject
            ON PMCategorySkillReport.ProjectId = PMProject.ProjectId
               AND PMCategorySkillInventory.[Year] < PMProject.YearDuration
) AS tblData;

DECLARE @ProjectYears TABLE
(
    iYear INT NOT NULL
);

DECLARE @i INT;
DECLARE @iMax INT;

SELECT @i = 0,
       @iMax = YearDuration
FROM webuser.PMProject
WHERE ProjectId = @ProjectId;

IF @iMax >
(
    SELECT MAX([Year]) FROM #ProjectInventory
)
    SET @iMax =
(
    SELECT MAX([Year]) FROM #ProjectInventory
)   ;

WHILE @i < @iMax
BEGIN
    INSERT @ProjectYears
    (
        iYear
    )
    VALUES
    (@i );
    SET @i = @i + 1;
END;

SELECT A.ProjectId,
       A.SkillId,
       A.PMCategoryName,
       A.Uic,
       A.PayPlan,
       A.CategoryGroupCode,
       A.CategorySubgroupCode,
       A.ActiveDutyDays,
       A.OverheadPercent,
       A.Grade,
       B.iYear [Year],
       0 Amount
INTO #PlaceholderProjectInventory
FROM
(
    SELECT DISTINCT
           ProjectId,
           SkillId,
           PMCategoryName,
           Uic,
           PayPlan,
           CategoryGroupCode,
           CategorySubgroupCode,
           ActiveDutyDays,
           OverheadPercent,
           Grade
    FROM #ProjectInventory
) A
    JOIN @ProjectYears B
        ON 1 = 1;

INSERT INTO #ProjectInventory
(
    ProjectId,
    SkillId,
    PMCategoryName,
    Uic,
    PayPlan,
    CategoryGroupCode,
    CategorySubgroupCode,
    ActiveDutyDays,
    OverheadPercent,
    Grade,
    Year,
    Amount
)
SELECT B.ProjectId,
       B.SkillId,
       B.PMCategoryName,
       B.Uic,
       B.PayPlan,
       B.CategoryGroupCode,
       B.CategorySubgroupCode,
       B.ActiveDutyDays,
       B.OverheadPercent,
       B.Grade,
       B.Year,
       B.Amount
FROM #ProjectInventory A
    RIGHT JOIN #PlaceholderProjectInventory B
        ON A.ProjectId = B.ProjectId
           AND A.SkillId = B.SkillId
           AND A.PMCategoryName = B.PMCategoryName
           AND A.Uic = B.Uic
           AND A.PayPlan = B.PayPlan
           AND A.CategoryGroupCode = B.CategoryGroupCode
           AND A.CategorySubgroupCode = B.CategorySubgroupCode
           AND A.Grade = B.Grade
           AND A.[Year] = B.[Year]
           AND A.ActiveDutyDays = B.ActiveDutyDays
           AND A.OverheadPercent = B.OverheadPercent
WHERE A.ProjectId IS NULL;

UPDATE #ProjectInventory
SET CategoryGroupCode = 'ALL'
WHERE CategoryGroupCode = '-1';

UPDATE #ProjectInventory
SET CategorySubgroupCode = 'ALL'
WHERE CategorySubgroupCode = '-1';

IF EXISTS (SELECT * FROM #ProjectInventory)
BEGIN
    DECLARE @SQL AS VARCHAR(1000),
            @GroupBy AS VARCHAR(500);
    SET @SQL = 'SELECT PMCategoryName, Uic [UIC], PayPlan, CategoryGroupCode, CategorySubgroupCode, ';
    SET @GroupBy = ' PMCategoryName, Uic, PayPlan, CategoryGroupCode, CategorySubgroupCode, ';

    IF EXISTS
    (
        SELECT *
        FROM #ProjectInventory
        WHERE PayPlan IN ( 'NE', 'NO', 'NWO', 'RE', 'RO', 'RWO' )
    )
    BEGIN
        SET @SQL = @SQL + 'ActiveDutyDays, ';
        SET @GroupBy = @GroupBy + 'ActiveDutyDays, ';
    END;

    IF EXISTS (SELECT * FROM #ProjectInventory WHERE PayPlan = 'CCE')
    BEGIN
        SET @SQL = @SQL + 'OverheadPercent, ';
        SET @GroupBy = @GroupBy + 'OverheadPercent, ';
    END;

    SET @SQL = @SQL + 'Grade, [Year], Amount FROM #ProjectInventory ';
    SET @GroupBy = @GroupBy + 'Grade ';

    --suppress the output if desired
    IF ISNULL(@SilentRunning, 0) = 1
    BEGIN
        EXEC dbo.spCrossTabNumber @table = @SQL,       -- varchar(8000)
                                  @onrows = @GroupBy,  -- varchar(2000)
                                  @onrowsalias = NULL, -- varchar(2000)
                                  @oncols = '[Year]',  -- varchar(2000)
                                  @sumcol = 'Amount',  -- varchar(2000)
                                  @SilentRunning = 1;  -- bit
    END;
    ELSE
    BEGIN
        EXEC dbo.spCrossTabNumber @table = @SQL,         -- varchar(8000)
                                  @onrows = @GroupBy,    -- varchar(2000)
                                  @onrowsalias = NULL,   -- varchar(2000)
                                  @oncols = '[Year]',    -- varchar(2000)
                                  @sumcol = 'Amount',    -- varchar(2000)
                                  @SilentRunning = NULL; -- bit
    END;

END;
ELSE
BEGIN
    --suppress the output if desired
    IF ISNULL(@SilentRunning, 0) = 1
    BEGIN
        SET NOCOUNT ON;
        SELECT SkillId,
               PMCategoryName,
               Uic [UIC],
               PayPlan,
               CategoryGroupCode,
               CategorySubgroupCode,
               ActiveDutyDays,
               OverheadPercent,
               Grade,
               Year,
               Amount
        INTO #temptable
        FROM #ProjectInventory;
    END;
    ELSE
        SELECT SkillId,
               PMCategoryName,
               Uic [UIC],
               PayPlan,
               CategoryGroupCode,
               CategorySubgroupCode,
               ActiveDutyDays,
               OverheadPercent,
               Grade,
               Year,
               Amount
        FROM #ProjectInventory;
END;