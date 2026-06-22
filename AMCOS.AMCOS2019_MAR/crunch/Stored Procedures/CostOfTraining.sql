
-- =============================================
-- Author:Dan Hogan	
-- Create date: July 2018
-- Description:	Training calculation to replace amortization
-- =============================================
CREATE PROCEDURE [crunch].[CostOfTraining]
    @AmcosVersionId INT = -1,
    @Debug AS BIT = 0
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @IsValidAmcosVersion BIT = crunch.ValidateAmcosVersion(@AmcosVersionId);

    IF (@IsValidAmcosVersion = 0)
        RETURN 0;

    --create temp tables using the version id for all our data, this makes it easier by locating all the versioning based clauses in one location
    DROP TABLE IF EXISTS crunch.TempATRM;
    CREATE TABLE crunch.TempATRM
    (
        [Sch Code] NVARCHAR(255) NULL,
        [Course Number] NVARCHAR(255) NULL,
        [Course Title] NVARCHAR(255) NULL,
        [Location] NVARCHAR(255) NULL,
        [Activity] NVARCHAR(255) NULL,
        [Length (wks)] NUMERIC(18, 10) NULL,
        [EGRADS] NUMERIC(18, 10) NULL,
        [Modal Grade] NVARCHAR(10) NULL,
        [Frequency] NUMERIC(18, 10) NULL,
        [Flying Hours] NUMERIC(18, 10) NULL,
        [TMW/EGRAD] NUMERIC(18, 10) NULL,
        [MPA] NUMERIC(18, 10) NULL,
        [OMA CIV] NUMERIC(18, 10) NULL,
        [OMA Non-Pay] NUMERIC(18, 10) NULL,
        [Other] NUMERIC(18, 10) NULL,
        [AmcosVersionId] INT NULL
    );

    INSERT INTO crunch.TempATRM
    (
        [Sch Code],
        [Course Number],
        [Course Title],
        Location,
        Activity,
        [Length (wks)],
        EGRADS,
        [Modal Grade],
        Frequency,
        [Flying Hours],
        [TMW/EGRAD],
        MPA,
        [OMA CIV],
        [OMA Non-Pay],
        Other,
        AmcosVersionId
    )
    SELECT SchoolCode,
           CourseNumber,
           CourseTitle,
           [Location],
           Activity,
           Length_weeks,
           EGRADS,
           ModalGrade,
           Frequency,
           FlyingHours,
           ICH,
           MPA_Cost,
           OMACivPay_Cost,
           OMANonPay_Cost,
           Other_Cost,
           AmcosVersionId
    FROM load_training.ATRM
    WHERE AmcosVersionId IN
          (
              SELECT TOP (3)
                     AmcosVersionId
              FROM load_training.ATRM
              GROUP BY AmcosVersionId
              ORDER BY AmcosVersionId DESC
          );

    DROP TABLE IF EXISTS crunch.TempATRRS;
    CREATE TABLE crunch.TempATRRS
    (
        [CPBRANCH] NVARCHAR(255) NULL,
        [SCH] NVARCHAR(255) NULL,
        [DEFSCH] NVARCHAR(255) NULL,
        [CRSPH] NVARCHAR(255) NULL,
        [CRSTITLE] NVARCHAR(255) NULL,
        [PGRAD] NVARCHAR(255) NULL,
        [PMOSEN4] NVARCHAR(255) NULL,
        [CRMGOF] NVARCHAR(255) NULL,
        [CRSTYPE] NVARCHAR(255) NULL,
        [Number of Students] FLOAT NULL,
        [AmcosVersionId] INT NULL
    );

    INSERT INTO crunch.TempATRRS
    (
        CPBRANCH,
        SCH,
        DEFSCH,
        CRSPH,
        CRSTITLE,
        PGRAD,
        PMOSEN4,
        CRMGOF,
        CRSTYPE,
        [Number of Students],
        AmcosVersionId
    )
    SELECT CPBRANCH,
           SCH,
           DEFSCH,
           CRSPH,
           CRSTITLE,
           PGRAD,
           PMOSEN4,
           CRMGOF,
           CRSTYPE,
           [Number of Students],
           AmcosVersionId
    FROM load_training.ATRRS
    WHERE AmcosVersionId IN
          (
              SELECT TOP (3)
                     AmcosVersionId
              FROM load_training.ATRM
              GROUP BY AmcosVersionId
              ORDER BY AmcosVersionId DESC
          );

    DROP TABLE IF EXISTS crunch.TempTraining_xwalk_atrrs_atrm;
    CREATE TABLE crunch.TempTraining_xwalk_atrrs_atrm
    (
        [ATRM_Key] NVARCHAR(255) NULL,
        [ATRRS_Key] NVARCHAR(255) NULL,
        [AmcosVersionId] INT NULL
    );

    INSERT INTO crunch.TempTraining_xwalk_atrrs_atrm
    (
        ATRM_Key,
        ATRRS_Key,
        AmcosVersionId
    )
    SELECT ATRM_Key,
           ATRRS_Key,
           AmcosVersionId
    FROM lookup.ATRRSATRMCrosswalk
    WHERE AmcosVersionId IN
          (
              SELECT TOP (3)
                     AmcosVersionId
              FROM load_training.ATRM
              GROUP BY AmcosVersionId
              ORDER BY AmcosVersionId DESC
          );

    DROP TABLE IF EXISTS crunch.TempTraining_xwalk_atrrs_crstype_mos;
    CREATE TABLE crunch.TempTraining_xwalk_atrrs_crstype_mos
    (
        [ATRRS_Sch_Code] NVARCHAR(255) NULL,
        [ATRRS_Crs_Number] NVARCHAR(255) NULL,
        [Crs_Type_O] NVARCHAR(4) NULL,
        [Crs_Type_E] NVARCHAR(4) NULL,
        [WeaponSystemName] NVARCHAR(50) NULL,
        [AOC] NVARCHAR(8) NULL,
        [WOMOS] NVARCHAR(8) NULL,
        [MOS] NVARCHAR(8) NULL,
        [O_GradeLevel_Floor] INT NULL,
        [O_GradeLevel_Ceiling] INT NULL,
        [W_GradeLevel_Floor] INT NULL,
        [W_GradeLevel_Ceiling] INT NULL,
        [E_GradeLevel_Floor] INT NULL,
        [E_GradeLevel_Ceiling] INT NULL,
        [AmcosVersionId] INT NULL
    );

    INSERT INTO crunch.TempTraining_xwalk_atrrs_crstype_mos
    (
        ATRRS_Sch_Code,
        ATRRS_Crs_Number,
        Crs_Type_O,
        Crs_Type_E,
        WeaponSystemName,
        AOC,
        WOMOS,
        MOS,
        O_GradeLevel_Floor,
        O_GradeLevel_Ceiling,
        W_GradeLevel_Floor,
        W_GradeLevel_Ceiling,
        E_GradeLevel_Floor,
        E_GradeLevel_Ceiling,
        AmcosVersionId
    )
    SELECT ATRRS_Sch_Code,
           ATRRS_Crs_Number,
           Crs_Type_O,
           Crs_Type_E,
           WeaponSystemName,
           AOC,
           WOMOS,
           MOS,
           O_GradeLevel_Floor,
           O_GradeLevel_Ceiling,
           W_GradeLevel_Floor,
           W_GradeLevel_Ceiling,
           E_GradeLevel_Floor,
           E_GradeLevel_Ceiling,
           AmcosVersionId
    FROM lookup.ATRRSCourseTypeMOS
    WHERE AmcosVersionId IN
          (
              SELECT TOP (3)
                     AmcosVersionId
              FROM load_training.ATRM
              GROUP BY AmcosVersionId
              ORDER BY AmcosVersionId DESC
          );

    DROP TABLE IF EXISTS crunch.TempArmyBudgetSingleValues;
    CREATE TABLE crunch.TempArmyBudgetSingleValues
    (
        [ParameterName] NVARCHAR(50) NOT NULL,
        [Appropriation] NVARCHAR(10) NOT NULL,
        [FY] NVARCHAR(4) NOT NULL,
        [AmcosVersionId] INT NOT NULL,
        [Amount] FLOAT NULL
    );

    INSERT INTO crunch.TempArmyBudgetSingleValues
    (
        ParameterName,
        Appropriation,
        FY,
        AmcosVersionId,
        Amount
    )
    SELECT ParameterName,
           Appropriation,
           FY,
           AmcosVersionId,
           Amount
    FROM crunch.ArmyBudgetSingleValues
    WHERE AmcosVersionId = @AmcosVersionId
          AND FY = 'Avg';

    --this is a combination of ATRRS Verification Table 58 Officer Branch Codes AND our own analysis to link those codes to CMFs
    DROP TABLE IF EXISTS crunch.TempATRRSOfficerBranchCodes;
    CREATE TABLE crunch.TempATRRSOfficerBranchCodes
    (
        [CMF] NVARCHAR(3) NULL,
        [Branch] NVARCHAR(3) NULL,
        [definition] NVARCHAR(255) NULL,
        [AmcosVersionId] INT NULL
    );

    INSERT INTO crunch.TempATRRSOfficerBranchCodes
    (
        CMF,
        Branch,
        definition,
        AmcosVersionId
    )
    SELECT CMF,
           Branch,
           definition,
           AmcosVersionId
    FROM lookup.ATRRSOfficerBranchCodes
    WHERE AmcosVersionId IN
          (
              SELECT TOP (3)
                     AmcosVersionId
              FROM load_training.ATRM
              GROUP BY AmcosVersionId
              ORDER BY AmcosVersionId DESC
          );

    DROP TABLE IF EXISTS crunch.TempMilitaryConversions;
    CREATE TABLE crunch.TempMilitaryConversions
    (
        [OldMOS] NVARCHAR(4) NULL,
        [Grade] NVARCHAR(1) NULL,
        [NewMOS] NVARCHAR(4) NULL,
        [AmcosVersionId] INT NULL
    );

    INSERT INTO crunch.TempMilitaryConversions
    (
        OldMOS,
        Grade,
        NewMOS,
        AmcosVersionId
    )
    SELECT OldMOS,
           Grade,
           NewMOS,
           AmcosVersionId
    FROM lookup.MilitaryConversions
    WHERE AmcosVersionId IN
          (
              SELECT TOP (3)
                     AmcosVersionId
              FROM load_training.ATRM
              GROUP BY AmcosVersionId
              ORDER BY AmcosVersionId DESC
          );

    --we only care about the latest valid MOSes for this we only pull one version unlike the above tables
    DROP TABLE IF EXISTS crunch.TempMOSAOC_Validation;
    CREATE TABLE crunch.TempMOSAOC_Validation
    (
        [MOS] NVARCHAR(4) NULL,
        [GradeType] NVARCHAR(3) NULL,
        [GradeLevel] TINYINT NULL,
        [AmcosVersionId] INT NULL,
        [Value] CHAR(1) NULL
    );

    INSERT INTO crunch.TempMOSAOC_Validation
    (
        MOS,
        GradeType,
        GradeLevel,
        AmcosVersionId,
        Value
    )
    SELECT MOS,
           GradeType,
           GradeLevel,
           AmcosVersionId,
           Value
    FROM dbo.MOSAOC_Validation
    WHERE AmcosVersionId = @AmcosVersionId;


    DECLARE @Exception AS NVARCHAR(50);

    DROP TABLE IF EXISTS crunch.TempATRRS_ATRM_Raw;
    CREATE TABLE crunch.TempATRRS_ATRM_Raw
    (
        [Exception] NVARCHAR(50) NULL,
        [ATRM_Other] FLOAT NULL,
        [ATRM_OMA] FLOAT NULL,
        [ATRM_MPA] FLOAT NULL,
        [ATRM_TMW_EGRD] FLOAT NULL,
        [ATRM_Flying_Hrs] FLOAT NULL,
        [ATRM_Frequency] FLOAT NULL,
        [ATRM_Modal_Grade] NVARCHAR(255) NULL,
        [ATRM_EGRADS] FLOAT NULL,
        [ATRM_Length_wks] FLOAT NULL,
        [ATRM_Activity] NVARCHAR(255) NULL,
        [ATRM_Location] NVARCHAR(255) NULL,
        [ATRM_Crs_Title] NVARCHAR(255) NULL,
        [ATRM_Crs_Num] NVARCHAR(255) NULL,
        [ATRM_Sch_Code] NVARCHAR(255) NULL,
        [ATRM_Version_id] INT NULL,
        [ATRM_Key] NVARCHAR(255) NULL,
        [ATRRS_Key] NVARCHAR(255) NULL,
        [AmcosVersionId] INT NULL,
        [ATRRS_Version_id] INT NULL,
        [ATRRS_Sch_Code] NVARCHAR(255) NULL,
        [ATRRS_Crs_Num] NVARCHAR(255) NULL,
        [ATRRS_Component] NVARCHAR(255) NULL,
        [ATRRS_School] NVARCHAR(255) NULL,
        [ATRRS_Crs_Title] NVARCHAR(255) NULL,
        [ATRRS_GradeLevel] NVARCHAR(255) NULL,
        [ATRRS_MOS] NVARCHAR(255) NULL,
        [ATRRS_Branch] NVARCHAR(255) NULL,
        [ATRRS_CrsType] NVARCHAR(255) NULL,
        [ATRRS_Num_students] FLOAT NULL
    );

    INSERT INTO crunch.TempATRRS_ATRM_Raw
    (
        Exception,
        ATRM_Other,
        ATRM_OMA,
        ATRM_MPA,
        ATRM_TMW_EGRD,
        ATRM_Flying_Hrs,
        ATRM_Frequency,
        ATRM_Modal_Grade,
        ATRM_EGRADS,
        ATRM_Length_wks,
        ATRM_Activity,
        ATRM_Location,
        ATRM_Crs_Title,
        ATRM_Crs_Num,
        ATRM_Sch_Code,
        ATRM_Version_id,
        ATRM_Key,
        ATRRS_Key,
        AmcosVersionId,
        ATRRS_Version_id,
        ATRRS_Sch_Code,
        ATRRS_Crs_Num,
        ATRRS_Component,
        ATRRS_School,
        ATRRS_Crs_Title,
        ATRRS_GradeLevel,
        ATRRS_MOS,
        ATRRS_Branch,
        ATRRS_CrsType,
        ATRRS_Num_students
    )
    SELECT a.Exception,
           a.ATRM_Other,
           a.ATRM_OMA,
           a.ATRM_MPA,
           a.ATRM_TMW_EGRD,
           a.ATRM_Flying_Hrs,
           a.ATRM_Frequency,
           a.ATRM_Modal_Grade,
           a.ATRM_EGRADS,
           a.ATRM_Length_wks,
           a.ATRM_Activity,
           a.ATRM_Location,
           a.ATRM_Crs_Title,
           a.ATRM_Crs_Num,
           a.ATRM_Sch_Code,
           a.ATRM_Version_id,
           a.ATRM_Key,
           a.ATRRS_Key,
           a.AmcosVersionId,
           a.ATRRS_Version_id,
           a.ATRRS_Sch_Code,
           a.ATRRS_Crs_Num,
           a.ATRRS_Component,
           a.ATRRS_School,
           a.ATRRS_Crs_Title,
           a.ATRRS_GradeLevel,
           a.ATRRS_MOS,
           a.ATRRS_Branch,
           a.ATRRS_CrsType,
           a.ATRRS_Num_students
    FROM
    (
        SELECT @Exception AS [Exception],
               a.*,
               b.AmcosVersionId AS ATRRS_Version_id,
               b.SCH AS ATRRS_Sch_Code,
               b.[CRSPH] AS ATRRS_Crs_Num,
               b.CPBRANCH AS ATRRS_Component,
               b.DEFSCH AS ATRRS_School,
               b.CRSTITLE AS ATRRS_Crs_Title,
               b.PGRAD AS ATRRS_GradeLevel,
               b.PMOSEN4 AS ATRRS_MOS,
               b.CRMGOF AS ATRRS_Branch,
               b.CRSTYPE AS ATRRS_CrsType,
               b.[Number of Students] AS ATRRS_Num_students
        FROM
        (
            SELECT a.*,
                   b.AmcosVersionId AS ATRM_Version_id,
                   b.[Sch Code] AS ATRM_Sch_Code,
                   b.[Course Number] AS ATRM_Crs_Num,
                   b.[Course Title] AS [ATRM_Crs_Title],
                   b.[Location] AS [ATRM_Location],
                   b.Activity AS ATRM_Activity,
                   b.[Length (wks)] AS ATRM_Length_wks,
                   b.EGRADS AS ATRM_EGRADS,
                   b.[Modal Grade] AS ATRM_Modal_Grade,
                   b.Frequency AS ATRM_Frequency,
                   b.[Flying Hours] AS ATRM_Flying_Hrs,
                   b.[TMW/EGRAD] AS ATRM_TMW_EGRD,
                   b.MPA AS ATRM_MPA,
                   b.[OMA CIV] + b.[OMA Non-Pay] AS ATRM_OMA,
                   b.Other AS ATRM_Other
            FROM crunch.TempTraining_xwalk_atrrs_atrm AS a
                FULL OUTER JOIN crunch.TempATRM AS b
                    ON a.ATRM_Key = (CONCAT(b.[Sch Code], b.[Course Number]))
                       AND a.AmcosVersionId = b.AmcosVersionId
        ) AS a
            FULL OUTER JOIN crunch.TempATRRS AS b
                ON a.ATRRS_Key = (CONCAT(b.[SCH], b.[CRSPH]))
                   AND b.AmcosVersionId = a.AmcosVersionId
    ) AS a;




    --there are business rules that determine which ATRM courses should be excluded
    --we implement them here
    UPDATE crunch.TempATRRS_ATRM_Raw
    SET Exception = 'Exclude'
    FROM crunch.TempATRRS_ATRM_Raw AS a
    WHERE
        --general exclude, need to find the business reason why for this 
        RIGHT(a.ATRM_Crs_Num, 3) = '(X)'
        OR
        --exclude foreign service classes
        a.ATRM_Modal_Grade LIKE '%FGN%'
        OR
        --exclude foreign military sales courses
        a.ATRM_Modal_Grade LIKE '%FMS%'
        OR
        --exclude based on a strange modal grade
        a.ATRM_Modal_Grade LIKE '%S&F%'
        OR a.ATRM_Modal_Grade LIKE '%SF%'
        OR a.ATRM_Sch_Code LIKE '%S&F%'
        OR a.ATRM_Sch_Code LIKE '%SF%'
        --exclude because its a training class for another service
        OR a.ATRM_Crs_Num LIKE '%(OS) (CT)%'
        OR RIGHT(a.ATRM_Crs_Num, 4) = '(OS)'
        --exclude because it is a foreign weapon sytem
        OR a.ATRM_Crs_Num LIKE '%MI-17%'
        OR a.ATRM_Crs_Title LIKE '%MI-17%'
        OR a.ATRRS_Crs_Title LIKE '%MI-17%'
        --officer candidate school is captured in officer acq so back it out of training
        --but we need to make sure we don't knock out warrant officer candidate school as that is NOT in officer acq per Marsha
        OR
        (
            a.ATRRS_Crs_Title LIKE '%officer candidate%'
            AND ATRRS_Crs_Title NOT LIKE '%warrant%'
        )
        --direction commisioning training which is captured in officer acq
        OR a.ATRRS_Crs_Title LIKE '%DIRECT COMMISSION%'
        --atrrs records where the gradelevel can be converted to a integer are civilians (e.g. 03, 04, etc) and should be excluded; whereas O4, W4 military and are fine to go through
        OR ISNUMERIC(a.ATRRS_GradeLevel) = 1
        --the following exclusions are because the ATRM model has some 'main' courses and some 'detachment' courses with the same key (crs and sch code), without this exclusion we'd double count
        --those costs because they don't  each have a single corresponding course link in ATRS
        OR
        (
            ATRM_Sch_Code = '091S'
            AND ATRM_Activity LIKE '%detachment%'
        );

    IF @Debug = 1
    BEGIN
        --check for multiple entries which would cause problems with joins and calculations later
        SELECT 'for this script to work right there must be 1 and only 1 ATRM sch and course combination in the ATRM table, if this table is not empty that means we need to look at an exclusion so we are not double counting';
        SELECT ATRM.AmcosVersionId,
               ATRM.[Sch Code],
               ATRM.[Course Number],
               ATRM.[Course Title],
               ATRM.Location,
               ATRM.Activity,
               ATRM.[Length (wks)],
               ATRM.EGRADS,
               ATRM.[Modal Grade],
               ATRM.Frequency,
               ATRM.[Flying Hours],
               ATRM.[TMW/EGRAD],
               ATRM.MPA,
               ATRM.[OMA CIV],
               ATRM.[OMA Non-Pay],
               ATRM.Other,
               ATRM.AmcosVersionId
        FROM crunch.TempATRM AS ATRM
            INNER JOIN
            (
                SELECT *,
                       COUNT([Course Number]) AS mycount
                FROM
                (
                    SELECT a.AmcosVersionId,
                           a.[Sch Code],
                           a.[Course Number]
                    FROM crunch.TempATRM AS a
                        LEFT JOIN crunch.TempATRRS_ATRM_Raw AS b
                            ON a.AmcosVersionId = b.AmcosVersionId
                               AND a.[Sch Code] = b.ATRM_Sch_Code
                               AND a.[Course Number] = b.ATRM_Crs_Num
                    WHERE b.Exception IS NULL
                    GROUP BY a.AmcosVersionId,
                             a.[Sch Code],
                             a.[Course Number]
                ) AS a
                GROUP BY AmcosVersionId,
                         [Sch Code],
                         [Course Number]
            ) AS b
                ON ATRM.[Sch Code] = b.[Sch Code]
                   AND ATRM.[Course Number] = b.[Course Number]
                   AND ATRM.AmcosVersionId = b.AmcosVersionId
        WHERE b.mycount >= 2
        ORDER BY ATRM.AmcosVersionId,
                 ATRM.[Sch Code],
                 ATRM.[Course Number];

        SELECT 'for this script to work right there must be 1 and only 1 ATRM school/course combination to ATRRS school/course, review the folowing and make deletions in the xwalk table';
        SELECT Exception,
               AmcosVersionId,
               ATRM_Key,
               ATRRS_Key,
               ATRM_Sch_Code,
               ATRM_Crs_Num,
               ATRM_Crs_Title,
               ATRM_Activity,
               ATRRS_Sch_Code,
               ATRRS_Crs_Num,
               ATRRS_School,
               ATRRS_Crs_Title
        FROM crunch.TempATRRS_ATRM_Raw
        WHERE CONCAT(ATRM_Key, AmcosVersionId) IN
              (
                  SELECT CONCAT([ATRM_Key], AmcosVersionId)
                  FROM crunch.TempTraining_xwalk_atrrs_atrm
                  GROUP BY [ATRM_Key],
                           AmcosVersionId
                  HAVING COUNT([ATRM_Key]) >= 2
              )
              OR CONCAT(ATRRS_Key, AmcosVersionId) IN
                 (
                     SELECT CONCAT([ATRRS_Key], AmcosVersionId)
                     FROM crunch.TempTraining_xwalk_atrrs_atrm
                     GROUP BY [ATRRS_Key],
                              AmcosVersionId
                     HAVING COUNT([ATRRS_Key]) >= 2
                 )
        GROUP BY Exception,
                 AmcosVersionId,
                 ATRM_Key,
                 ATRRS_Key,
                 ATRM_Sch_Code,
                 ATRM_Crs_Num,
                 ATRM_Crs_Title,
                 ATRM_Activity,
                 ATRRS_Sch_Code,
                 ATRRS_Crs_Num,
                 ATRRS_School,
                 ATRRS_Crs_Title
        ORDER BY ATRM_Key,
                 ATRRS_Key;

        SELECT 'CIRCLE BACK ON THE FOLLOWING SCRIPT, IT MAY NOT BE A PROBLEM/NEEDED';
        SELECT 'for this script to work right there must be 1 and only 1 CMF entry in the ATRRS Officer Branch table so this table should be empty';
        SELECT a.CMF,
               a.Branch,
               a.definition,
               a.AmcosVersionId
        FROM crunch.TempATRRSOfficerBranchCodes AS a
            INNER JOIN
            (
                SELECT CMF,
                       AmcosVersionId,
                       COUNT(CMF) AS mycount
                FROM crunch.TempATRRSOfficerBranchCodes
                GROUP BY CMF,
                         AmcosVersionId
                HAVING COUNT(CMF) > 1
            ) AS b
                ON a.CMF = b.CMF
                   AND a.AmcosVersionId = b.AmcosVersionId;


        --check the mappings for issues
        SELECT 'the following mapppings have issues because you have a xwalk entry which does not map to anything, every entry in the xwalk table should map to something';
        SELECT Exception,
               ATRM_Other,
               ATRM_OMA,
               ATRM_MPA,
               ATRM_TMW_EGRD,
               ATRM_Flying_Hrs,
               ATRM_Frequency,
               ATRM_Modal_Grade,
               ATRM_EGRADS,
               ATRM_Length_wks,
               ATRM_Activity,
               ATRM_Location,
               ATRM_Crs_Title,
               ATRM_Crs_Num,
               ATRM_Sch_Code,
               ATRM_Version_id,
               ATRM_Key,
               ATRRS_Key,
               AmcosVersionId,
               ATRRS_Version_id,
               ATRRS_Sch_Code,
               ATRRS_Crs_Num,
               ATRRS_Component,
               ATRRS_School,
               ATRRS_Crs_Title,
               ATRRS_GradeLevel,
               ATRRS_MOS,
               ATRRS_Branch,
               ATRRS_CrsType,
               ATRRS_Num_students
        FROM crunch.TempATRRS_ATRM_Raw
        WHERE (
                  ATRRS_Key IS NOT NULL
                  AND ATRRS_Crs_Num IS NULL
              )
              OR
              (
                  ATRM_Key IS NOT NULL
                  AND ATRM_Crs_Num IS NULL
              );


        SELECT 'for this script to work right there must be 1 and only 1 ATRRS course type entry so the below query should be empty';
        SELECT AmcosVersionId,
               [ATRRS_Sch_Code],
               [ATRRS_Crs_Number],
               COUNT([ATRRS_Crs_Number]) AS mycount
        FROM crunch.TempTraining_xwalk_atrrs_crstype_mos
        GROUP BY AmcosVersionId,
                 [ATRRS_Sch_Code],
                 [ATRRS_Crs_Number]
        HAVING COUNT([ATRRS_Crs_Number]) >= 2;




        --check these records to make sure nothing is excluded that shouldn't have been
        SELECT 'exclude list';
        SELECT Exception,
               ATRM_Other,
               ATRM_OMA,
               ATRM_MPA,
               ATRM_TMW_EGRD,
               ATRM_Flying_Hrs,
               ATRM_Frequency,
               ATRM_Modal_Grade,
               ATRM_EGRADS,
               ATRM_Length_wks,
               ATRM_Activity,
               ATRM_Location,
               ATRM_Crs_Title,
               ATRM_Crs_Num,
               ATRM_Sch_Code,
               ATRM_Version_id,
               ATRM_Key,
               ATRRS_Key,
               AmcosVersionId,
               ATRRS_Version_id,
               ATRRS_Sch_Code,
               ATRRS_Crs_Num,
               ATRRS_Component,
               ATRRS_School,
               ATRRS_Crs_Title,
               ATRRS_GradeLevel,
               ATRRS_MOS,
               ATRRS_Branch,
               ATRRS_CrsType,
               ATRRS_Num_students
        FROM crunch.TempATRRS_ATRM_Raw
        WHERE Exception = 'Exclude'
        ORDER BY ATRM_Sch_Code,
                 ATRM_Crs_Num,
                 ATRRS_Sch_Code,
                 ATRRS_Crs_Num;



        --check these records to make sure we can't do anymore mapping
        --note that all we care about are non-mapped ATRM records, this is because if we don't have an
        --ATRM cost then we can't do anything with the ATRRS data so we focus only on ATRM
        SELECT 'use excel fuzzylookup, or similiar technique, to see if there any more matches between the following unmatched ATRM, then ATRRS records';
        SELECT ATRM_Version_id,
               ATRM_Key,
               ATRM_Sch_Code,
               ATRM_Crs_Num,
               ATRM_Activity,
               ATRM_Crs_Title
        FROM crunch.TempATRRS_ATRM_Raw
        WHERE AmcosVersionId IS NULL
              AND Exception IS NULL
        GROUP BY ATRM_Version_id,
                 ATRM_Key,
                 ATRM_Sch_Code,
                 ATRM_Crs_Num,
                 ATRM_Activity,
                 ATRM_Crs_Title;

        SELECT ATRRS_Version_id,
               ATRRS_Key,
               ATRRS_Sch_Code,
               ATRRS_Crs_Num,
               ATRRS_School,
               ATRRS_Crs_Title
        FROM crunch.TempATRRS_ATRM_Raw
        WHERE AmcosVersionId IS NULL
              AND Exception IS NULL
        GROUP BY ATRRS_Version_id,
                 ATRRS_Key,
                 ATRRS_Sch_Code,
                 ATRRS_Crs_Num,
                 ATRRS_School,
                 ATRRS_Crs_Title;

    --  SELECT concat (sch,crsph), sch, crsph,defsch, crstitle FROM crunch.training_atrrs WHERE 
    --	  CONCAT (sch,crsph) not IN (SELECT atrrs_key FROM crunch.training_xwalk_atrrs_atrm WHERE AmcosVersionId=-1)
    --	  AND AmcosVersionId=-1
    --	  GROUP BY sch,crsph, defsch, crstitle

    --	  SELECT CONCAT([sch code], [course number]), [sch code], [course number], [course title], activity FROM crunch.training_atrm WHERE
    --      CONCAT([sch code], [course number]) NOT IN  (SELECT atrrs_key from crunch.training_xwalk_atrrs_atrm WHERE AmcosVersionId=-1 )
    --	  AND AmcosVersionId=-1
    --	  GROUP BY [sch code], [course number], [course title], activity


    END;


    --alright, let's bring in the course and MOS/AOC/WOMOS mappings
    DROP TABLE IF EXISTS crunch.TempATRRS_ATRM_Crs_MOS;
    DECLARE @nvar AS NVARCHAR(10);
    DECLARE @int AS INTEGER;

    CREATE TABLE crunch.TempATRRS_ATRM_Crs_MOS
    (
        [ATRRS_Num_students] FLOAT NULL,
        [ATRRS_CrsType] NVARCHAR(255) NULL,
        [ATRRS_Branch] NVARCHAR(255) NULL,
        [ATRRS_MOS] NVARCHAR(255) NULL,
        [ATRRS_GradeLevel] NVARCHAR(255) NULL,
        [ATRRS_Crs_Title] NVARCHAR(255) NULL,
        [ATRRS_School] NVARCHAR(255) NULL,
        [ATRRS_Component] NVARCHAR(255) NULL,
        [ATRRS_Crs_Num] NVARCHAR(255) NULL,
        [ATRRS_Sch_Code] NVARCHAR(255) NULL,
        [ATRRS_Version_id] INT NULL,
        [AmcosVersionId] INT NULL,
        [ATRRS_Key] NVARCHAR(255) NULL,
        [ATRM_Key] NVARCHAR(255) NULL,
        [ATRM_Version_id] INT NULL,
        [ATRM_Sch_Code] NVARCHAR(255) NULL,
        [ATRM_Crs_Num] NVARCHAR(255) NULL,
        [ATRM_Crs_Title] NVARCHAR(255) NULL,
        [ATRM_Location] NVARCHAR(255) NULL,
        [ATRM_Activity] NVARCHAR(255) NULL,
        [ATRM_Length_wks] FLOAT NULL,
        [ATRM_EGRADS] FLOAT NULL,
        [ATRM_Modal_Grade] NVARCHAR(255) NULL,
        [ATRM_Frequency] FLOAT NULL,
        [ATRM_Flying_Hrs] FLOAT NULL,
        [ATRM_TMW_EGRD] FLOAT NULL,
        [ATRM_MPA] FLOAT NULL,
        [ATRM_OMA] FLOAT NULL,
        [ATRM_Other] FLOAT NULL,
        [Exception] NVARCHAR(50) NULL,
        [Crs_Type_O] NVARCHAR(4) NULL,
        [Crs_Type_E] NVARCHAR(4) NULL,
        [WeaponSystemName] NVARCHAR(50) NULL,
        [AOC] NVARCHAR(8) NULL,
        [WOMOS] NVARCHAR(8) NULL,
        [MOS] NVARCHAR(8) NULL,
        [O_GradeLevel_Floor] INT NULL,
        [O_GradeLevel_Ceiling] INT NULL,
        [W_GradeLevel_Floor] INT NULL,
        [W_GradeLevel_Ceiling] INT NULL,
        [E_GradeLevel_Floor] INT NULL,
        [E_GradeLevel_Ceiling] INT NULL,
        [final_crs_type] NVARCHAR(10) NULL,
        [final_MOS] NVARCHAR(10) NULL,
        [final_Branch] NVARCHAR(10) NULL,
        [final_Grade] NVARCHAR(10) NULL,
        [final_GradeType] NVARCHAR(10) NULL,
        [final_GradeLevel] NVARCHAR(10) NULL,
        [payplan] NVARCHAR(10) NULL,
        [atrrs_tot_students] INT NULL,
        [adj_students] FLOAT NULL,
        [running_adj_students] FLOAT NULL,
        [inventory] INT NULL,
        [inv_add] FLOAT NULL,
        [total_inv_add] FLOAT NULL,
        [final_adj_inv] FLOAT NULL,
        [final_adj_students] FLOAT NULL
    );

    INSERT INTO crunch.TempATRRS_ATRM_Crs_MOS
    (
        ATRRS_Num_students,
        ATRRS_CrsType,
        ATRRS_Branch,
        ATRRS_MOS,
        ATRRS_GradeLevel,
        ATRRS_Crs_Title,
        ATRRS_School,
        ATRRS_Component,
        ATRRS_Crs_Num,
        ATRRS_Sch_Code,
        ATRRS_Version_id,
        AmcosVersionId,
        ATRRS_Key,
        ATRM_Key,
        ATRM_Version_id,
        ATRM_Sch_Code,
        ATRM_Crs_Num,
        ATRM_Crs_Title,
        ATRM_Location,
        ATRM_Activity,
        ATRM_Length_wks,
        ATRM_EGRADS,
        ATRM_Modal_Grade,
        ATRM_Frequency,
        ATRM_Flying_Hrs,
        ATRM_TMW_EGRD,
        ATRM_MPA,
        ATRM_OMA,
        ATRM_Other,
        Exception,
        Crs_Type_O,
        Crs_Type_E,
        WeaponSystemName,
        AOC,
        WOMOS,
        MOS,
        O_GradeLevel_Floor,
        O_GradeLevel_Ceiling,
        W_GradeLevel_Floor,
        W_GradeLevel_Ceiling,
        E_GradeLevel_Floor,
        E_GradeLevel_Ceiling,
        final_crs_type,
        final_MOS,
        final_Branch,
        final_Grade,
        final_GradeType,
        final_GradeLevel,
        payplan,
        atrrs_tot_students,
        adj_students,
        running_adj_students,
        inventory,
        inv_add,
        total_inv_add,
        final_adj_inv,
        final_adj_students
    )
    SELECT a.ATRRS_Num_students,
           a.ATRRS_CrsType,
           a.ATRRS_Branch,
           a.ATRRS_MOS,
           a.ATRRS_GradeLevel,
           a.ATRRS_Crs_Title,
           a.ATRRS_School,
           a.ATRRS_Component,
           a.ATRRS_Crs_Num,
           a.ATRRS_Sch_Code,
           a.ATRRS_Version_id,
           a.AmcosVersionId,
           a.ATRRS_Key,
           a.ATRM_Key,
           a.ATRM_Version_id,
           a.ATRM_Sch_Code,
           a.ATRM_Crs_Num,
           a.ATRM_Crs_Title,
           a.ATRM_Location,
           a.ATRM_Activity,
           a.ATRM_Length_wks,
           a.ATRM_EGRADS,
           a.ATRM_Modal_Grade,
           a.ATRM_Frequency,
           a.ATRM_Flying_Hrs,
           a.ATRM_TMW_EGRD,
           a.ATRM_MPA,
           a.ATRM_OMA,
           a.ATRM_Other,
           a.Exception,
           a.Crs_Type_O,
           a.Crs_Type_E,
           a.WeaponSystemName,
           a.AOC,
           a.WOMOS,
           a.MOS,
           a.O_GradeLevel_Floor,
           a.O_GradeLevel_Ceiling,
           a.W_GradeLevel_Floor,
           a.W_GradeLevel_Ceiling,
           a.E_GradeLevel_Floor,
           a.E_GradeLevel_Ceiling,
           a.final_crs_type,
           a.final_MOS,
           a.final_Branch,
           a.final_Grade,
           a.final_GradeType,
           a.final_GradeLevel,
           a.payplan,
           a.atrrs_tot_students,
           a.adj_students,
           a.running_adj_students,
           a.inventory,
           a.inv_add,
           a.total_inv_add,
           a.final_adj_inv,
           a.final_adj_students
    FROM
    (
        SELECT a.Exception,
               a.ATRM_Other,
               a.ATRM_OMA,
               a.ATRM_MPA,
               a.ATRM_TMW_EGRD,
               a.ATRM_Flying_Hrs,
               a.ATRM_Frequency,
               a.ATRM_Modal_Grade,
               a.ATRM_EGRADS,
               a.ATRM_Length_wks,
               a.ATRM_Activity,
               a.ATRM_Location,
               a.ATRM_Crs_Title,
               a.ATRM_Crs_Num,
               a.ATRM_Sch_Code,
               a.ATRM_Version_id,
               a.ATRM_Key,
               a.ATRRS_Key,
               a.AmcosVersionId,
               a.ATRRS_Version_id,
               a.ATRRS_Sch_Code,
               a.ATRRS_Crs_Num,
               a.ATRRS_Component,
               a.ATRRS_School,
               a.ATRRS_Crs_Title,
               a.ATRRS_GradeLevel,
               a.ATRRS_MOS,
               a.ATRRS_Branch,
               a.ATRRS_CrsType,
               a.ATRRS_Num_students,
               b.Crs_Type_O,
               b.Crs_Type_E,
               b.WeaponSystemName,
               b.AOC,
               b.WOMOS,
               b.MOS,
               b.O_GradeLevel_Floor,
               b.O_GradeLevel_Ceiling,
               b.W_GradeLevel_Floor,
               b.W_GradeLevel_Ceiling,
               b.E_GradeLevel_Floor,
               b.E_GradeLevel_Ceiling,
               @nvar AS final_crs_type,
               @nvar AS final_MOS,
               @nvar AS final_Branch,
               @nvar AS final_Grade,
               @nvar AS final_GradeType,
               @nvar AS final_GradeLevel,
               @nvar AS payplan,
               @int AS atrrs_tot_students,
               0.0 AS adj_students,
               0.0 AS running_adj_students,
               @int AS inventory,
               0.0 AS inv_add,
               0.0 AS total_inv_add,
               0.0 AS final_adj_inv,
               0.0 AS final_adj_students
        FROM crunch.TempATRRS_ATRM_Raw AS a
            LEFT JOIN crunch.TempTraining_xwalk_atrrs_crstype_mos AS b
                ON a.ATRRS_Crs_Num = b.ATRRS_Crs_Number
                   AND a.ATRRS_Sch_Code = b.ATRRS_Sch_Code
                   AND a.AmcosVersionId = b.AmcosVersionId
        --we're getting down to business now so get rid of the non-matches to ATRRS and the excludes
        --we assume at this point the analyst will have looked at the previous debug flags and made necessary adjustments
        WHERE a.Exception IS NULL
              AND a.ATRRS_Key IS NOT NULL
    ) AS a;

    --alright, now we use the atrrs assignments to divvy out final assignments
    --make final grade level assignments
    --grade levels come from ATRRS with a few exceptions
    UPDATE crunch.TempATRRS_ATRM_Crs_MOS
    SET final_Grade = ATRRS_GradeLevel;

    --cadets become O1s
    UPDATE crunch.TempATRRS_ATRM_Crs_MOS
    SET final_Grade = 'O1'
    WHERE ATRRS_GradeLevel = 'CD';

    --warrant candidates become W1s
    UPDATE crunch.TempATRRS_ATRM_Crs_MOS
    SET final_Grade = 'W1'
    WHERE ATRRS_Crs_Title LIKE '%warrant officer candidate%'
          OR ATRRS_Crs_Title LIKE '%WOBC%'
          OR ATRRS_Crs_Title LIKE '%wo basic%';

    --those going to Basic Officer courses need to be converter to an O1 is they are not already
    UPDATE crunch.TempATRRS_ATRM_Crs_MOS
    SET final_Grade = 'O1'
    WHERE
        --if the student is already an officer then lets not change their grade level
        LEFT(ATRRS_GradeLevel, 1) <> 'O'
        AND ATRRS_Crs_Title LIKE '%basic officer%'
        AND
        --make sure we aren't including any warrant officer basic type courses
        (
            ATRRS_Crs_Title NOT LIKE '%WOBC%'
            AND ATRRS_Crs_Title NOT LIKE '%Warrant%'
        );






    --O/W & E crs type codes may be different for some courses
    --O/W/E grp/subgrp assignments are also made
    UPDATE crunch.TempATRRS_ATRM_Crs_MOS
    SET final_crs_type = Crs_Type_O,
        final_MOS = AOC
    WHERE LEFT(final_Grade, 1) = 'O';

    UPDATE crunch.TempATRRS_ATRM_Crs_MOS
    SET final_crs_type = Crs_Type_E,
        final_MOS = MOS
    WHERE LEFT(final_Grade, 1) = 'E';
    UPDATE crunch.TempATRRS_ATRM_Crs_MOS
    SET final_crs_type = Crs_Type_O,
        final_MOS = WOMOS
    WHERE LEFT(final_Grade, 1) = 'W';

    --one more final item, if there is a grade level adjustment required by the CrsType_MOS table then we need to make it
    --because each grade type has a floor and ceiling this is going to take a series of update statements

    --to make this easier before we do anything let's populate the final grade and level columns
    UPDATE crunch.TempATRRS_ATRM_Crs_MOS
    SET final_GradeType = LEFT(final_Grade, 1),
        final_GradeLevel = (RIGHT(final_Grade, 1));

    --now let's make the grade level adjustments
    --officer grade level floor and ceiling
    UPDATE crunch.TempATRRS_ATRM_Crs_MOS
    SET final_GradeLevel = O_GradeLevel_Floor
    WHERE final_GradeType = 'O'
          AND O_GradeLevel_Floor > final_GradeLevel
          AND O_GradeLevel_Floor IS NOT NULL;
    UPDATE crunch.TempATRRS_ATRM_Crs_MOS
    SET final_GradeLevel = O_GradeLevel_Ceiling
    WHERE final_GradeType = 'O'
          AND O_GradeLevel_Ceiling < final_GradeLevel
          AND O_GradeLevel_Ceiling IS NOT NULL;

    --warrant grade level floor and ceiling
    UPDATE crunch.TempATRRS_ATRM_Crs_MOS
    SET final_GradeLevel = W_GradeLevel_Floor
    WHERE final_GradeType = 'W'
          AND W_GradeLevel_Floor > final_GradeLevel
          AND W_GradeLevel_Floor IS NOT NULL;
    UPDATE crunch.TempATRRS_ATRM_Crs_MOS
    SET final_GradeLevel = W_GradeLevel_Ceiling
    WHERE final_GradeType = 'W'
          AND W_GradeLevel_Ceiling < final_GradeLevel
          AND W_GradeLevel_Ceiling IS NOT NULL;

    --enlisted grade level floor and ceiling
    UPDATE crunch.TempATRRS_ATRM_Crs_MOS
    SET final_GradeLevel = E_GradeLevel_Floor
    WHERE final_GradeType = 'E'
          AND E_GradeLevel_Floor > final_GradeLevel
          AND E_GradeLevel_Floor IS NOT NULL;
    UPDATE crunch.TempATRRS_ATRM_Crs_MOS
    SET final_GradeLevel = E_GradeLevel_Ceiling
    WHERE final_GradeType = 'E'
          AND E_GradeLevel_Ceiling < final_GradeLevel
          AND E_GradeLevel_Ceiling IS NOT NULL;


    ----Now copy any changes back into the combined final_Grade
    UPDATE crunch.TempATRRS_ATRM_Crs_MOS
    SET final_Grade = CONCAT(final_GradeType, final_GradeLevel);


    IF @Debug = 1
    BEGIN
        SELECT 'the following records do not have any course type assignment, this needs to be fixed';
        SELECT ATRRS_Num_students,
               ATRRS_CrsType,
               ATRRS_Branch,
               ATRRS_MOS,
               ATRRS_GradeLevel,
               ATRRS_Crs_Title,
               ATRRS_School,
               ATRRS_Component,
               ATRRS_Crs_Num,
               ATRRS_Sch_Code,
               ATRRS_Version_id,
               AmcosVersionId,
               ATRRS_Key,
               ATRM_Key,
               ATRM_Version_id,
               ATRM_Sch_Code,
               ATRM_Crs_Num,
               ATRM_Crs_Title,
               ATRM_Location,
               ATRM_Activity,
               ATRM_Length_wks,
               ATRM_EGRADS,
               ATRM_Modal_Grade,
               ATRM_Frequency,
               ATRM_Flying_Hrs,
               ATRM_TMW_EGRD,
               ATRM_MPA,
               ATRM_OMA,
               ATRM_Other,
               Exception,
               Crs_Type_O,
               Crs_Type_E,
               WeaponSystemName,
               AOC,
               WOMOS,
               MOS,
               O_GradeLevel_Floor,
               O_GradeLevel_Ceiling,
               W_GradeLevel_Floor,
               W_GradeLevel_Ceiling,
               E_GradeLevel_Floor,
               E_GradeLevel_Ceiling,
               final_crs_type,
               final_MOS,
               final_Branch,
               final_Grade,
               final_GradeType,
               final_GradeLevel,
               payplan,
               atrrs_tot_students,
               adj_students,
               running_adj_students,
               inventory,
               inv_add,
               total_inv_add,
               final_adj_inv,
               final_adj_students
        FROM crunch.TempATRRS_ATRM_Crs_MOS
        WHERE final_crs_type IS NULL
        ORDER BY ATRM_Sch_Code,
                 ATRM_Crs_Num;

    END;


    --Now we turn the  'ATRRS' data select values into whoever ATRRS says attended the course
    UPDATE crunch.TempATRRS_ATRM_Crs_MOS
    SET final_MOS = CASE
                        WHEN (LEN(ATRRS_MOS) > 3) THEN
                            ISNULL(LEFT(ATRRS_MOS, 3), NULL)
                        ELSE
                            ATRRS_MOS
                    END
    WHERE LEFT(ATRRS_GradeLevel, 1) <> 'W'
          AND final_MOS = 'ATRRS';

    UPDATE crunch.TempATRRS_ATRM_Crs_MOS
    SET final_MOS = ATRRS_MOS
    WHERE LEFT(ATRRS_GradeLevel, 1) = 'W'
          AND final_MOS = 'ATRRS';



    --this statement corrects the issue where the course xwalk wants to use ATRRS WOMOS but then we converted some Es to Ws, so we need to make those XXXs since we do not know which WOMOS to use
    --they will only be the ones with an existing 3 character MOS, we want to exclude any 2 character MOS (CMF level) or 4 character MOS (correct WOMOS)
    UPDATE crunch.TempATRRS_ATRM_Crs_MOS
    SET final_MOS = 'XXX'
    WHERE final_GradeType = 'W'
          --WOMOS is 4 digits so a 3 digit WOMOS is an enlisted that was converted to a warrant through warrant officer basic course
          AND LEN(final_MOS) = 3;

    --if the course xwalk used an WOMOS in the enlisted column that means we also need to now convert their grade
    UPDATE crunch.TempATRRS_ATRM_Crs_MOS
    SET final_GradeType = 'W'
    WHERE final_GradeType = 'E'
          --WOMOS is 4 digits so a 3 digit WOMOS in an enlisted grade means we need to convert the grade to W
          AND LEN(final_MOS) > 3;


    --bring in officer branch data
    --because ATRRS doesn't have officer AOCs we need someway to determine if we are doing officer conversions
    --we use the ATRRS branch field 2 character abbreviation and a lookup table to pull in the branch cmf
    UPDATE crunch.TempATRRS_ATRM_Crs_MOS
    SET final_Branch = b.Branch
    FROM crunch.TempATRRS_ATRM_Crs_MOS AS a
        LEFT JOIN crunch.TempATRRSOfficerBranchCodes AS b
            ON LEFT(a.final_MOS, 2) = b.CMF
    WHERE a.final_GradeType = 'O';

    --populate the payplan field
    UPDATE crunch.TempATRRS_ATRM_Crs_MOS
    SET payplan = ATRRS_Component;

    UPDATE crunch.TempATRRS_ATRM_Crs_MOS
    SET payplan = 'N'
    WHERE payplan = 'G';

    UPDATE crunch.TempATRRS_ATRM_Crs_MOS
    SET payplan = CONCAT(payplan, final_GradeType);

    UPDATE crunch.TempATRRS_ATRM_Crs_MOS
    SET payplan = CONCAT(payplan, 'O')
    WHERE payplan LIKE '%W%';

    -- =============================================
    --Make sure that before we bring in inventory we have valid AOCs/MOSes/WOMOSes
    --by converting those we can
    --Conversion information comes from the G1 Personnel Authorization Module (PAM)
    -- =============================================
    --
    UPDATE crunch.TempATRRS_ATRM_Crs_MOS
    SET final_MOS = b.NewMOS
    FROM crunch.TempATRRS_ATRM_Crs_MOS AS a
        INNER JOIN crunch.TempMilitaryConversions AS b
            ON a.final_MOS = b.OldMOS
               AND b.NewMOS NOT LIKE '%none%';


    IF @Debug = 1
    BEGIN
        SELECT ATRRS_Num_students,
               ATRRS_CrsType,
               ATRRS_Branch,
               ATRRS_MOS,
               ATRRS_GradeLevel,
               ATRRS_Crs_Title,
               ATRRS_School,
               ATRRS_Component,
               ATRRS_Crs_Num,
               ATRRS_Sch_Code,
               ATRRS_Version_id,
               AmcosVersionId,
               ATRRS_Key,
               ATRM_Key,
               ATRM_Version_id,
               ATRM_Sch_Code,
               ATRM_Crs_Num,
               ATRM_Crs_Title,
               ATRM_Location,
               ATRM_Activity,
               ATRM_Length_wks,
               ATRM_EGRADS,
               ATRM_Modal_Grade,
               ATRM_Frequency,
               ATRM_Flying_Hrs,
               ATRM_TMW_EGRD,
               ATRM_MPA,
               ATRM_OMA,
               ATRM_Other,
               Exception,
               Crs_Type_O,
               Crs_Type_E,
               WeaponSystemName,
               AOC,
               WOMOS,
               MOS,
               O_GradeLevel_Floor,
               O_GradeLevel_Ceiling,
               W_GradeLevel_Floor,
               W_GradeLevel_Ceiling,
               E_GradeLevel_Floor,
               E_GradeLevel_Ceiling,
               final_crs_type,
               final_MOS,
               final_Branch,
               final_Grade,
               final_GradeType,
               final_GradeLevel,
               payplan,
               atrrs_tot_students,
               adj_students,
               running_adj_students,
               inventory,
               inv_add,
               total_inv_add,
               final_adj_inv,
               final_adj_students
        FROM crunch.TempATRRS_ATRM_Crs_MOS;

        SELECT 'The following AOC/MOS/WOMOS are not valid, we need to fix this to the extent we can';
        SELECT a.final_MOS,
               a.final_GradeType,
               a.final_GradeLevel
        FROM crunch.TempATRRS_ATRM_Crs_MOS AS a
            LEFT OUTER JOIN
            (
                SELECT MOS,
                       GradeType,
                       GradeLevel
                FROM crunch.TempMOSAOC_Validation
                GROUP BY MOS,
                         GradeType,
                         GradeLevel
            ) AS b
                ON a.final_MOS = b.MOS
                   AND a.final_GradeType = b.GradeType
                   AND a.final_GradeLevel = b.GradeLevel
        WHERE b.MOS IS NULL
              --we're not checking CMFs and it doesn't make sense to check PayPlan wide assignments -> 'XXX'
              AND a.final_MOS <> 'XXX'
              AND LEN(a.final_MOS) > 2
        GROUP BY a.final_MOS,
                 a.final_GradeType,
                 a.final_GradeLevel;



        SELECT 'the following records do not have any MOS assignment, this needs to be fixed';
        SELECT ATRRS_Num_students,
               ATRRS_CrsType,
               ATRRS_Branch,
               ATRRS_MOS,
               ATRRS_GradeLevel,
               ATRRS_Crs_Title,
               ATRRS_School,
               ATRRS_Component,
               ATRRS_Crs_Num,
               ATRRS_Sch_Code,
               ATRRS_Version_id,
               AmcosVersionId,
               ATRRS_Key,
               ATRM_Key,
               ATRM_Version_id,
               ATRM_Sch_Code,
               ATRM_Crs_Num,
               ATRM_Crs_Title,
               ATRM_Location,
               ATRM_Activity,
               ATRM_Length_wks,
               ATRM_EGRADS,
               ATRM_Modal_Grade,
               ATRM_Frequency,
               ATRM_Flying_Hrs,
               ATRM_TMW_EGRD,
               ATRM_MPA,
               ATRM_OMA,
               ATRM_Other,
               Exception,
               Crs_Type_O,
               Crs_Type_E,
               WeaponSystemName,
               AOC,
               WOMOS,
               MOS,
               O_GradeLevel_Floor,
               O_GradeLevel_Ceiling,
               W_GradeLevel_Floor,
               W_GradeLevel_Ceiling,
               E_GradeLevel_Floor,
               E_GradeLevel_Ceiling,
               final_crs_type,
               final_MOS,
               final_Branch,
               final_Grade,
               final_GradeType,
               final_GradeLevel,
               payplan,
               atrrs_tot_students,
               adj_students,
               running_adj_students,
               inventory,
               inv_add,
               total_inv_add,
               final_adj_inv,
               final_adj_students
        FROM crunch.TempATRRS_ATRM_Crs_MOS
        WHERE final_MOS IS NULL;

    END;



    -- =============================================
    --bring in inventory
    -- =============================================

    --Bring in inventory for the subgroup matches
    UPDATE crunch.TempATRRS_ATRM_Crs_MOS
    SET inventory = b.inventory
    FROM crunch.TempATRRS_ATRM_Crs_MOS AS a
        LEFT OUTER JOIN
        (
            SELECT [PayPlan],
                   [CategoryGroupCode],
                   [CategorySubGroupCode],
                   [GradeType],
                   [GradeLevel],
                   SUM([Inventory]) AS inventory
            FROM [data].[Inventory]
            WHERE PayPlan IN ( 'AO', 'AWO', 'RO', 'RWO', 'NO', 'NWO', 'NE', 'AE', 'RE' )
            GROUP BY [PayPlan],
                     [CategoryGroupCode],
                     [CategorySubGroupCode],
                     [GradeType],
                     [GradeLevel]
        ) AS b
            ON a.final_MOS = b.CategorySubGroupCode
               AND a.final_GradeLevel = b.GradeLevel
               AND a.payplan = b.payplan;

    --Bring in inventory for the group matches
    UPDATE crunch.TempATRRS_ATRM_Crs_MOS
    SET inventory = b.inventory
    FROM crunch.TempATRRS_ATRM_Crs_MOS AS a
        LEFT OUTER JOIN
        (
            SELECT [PayPlan],
                   [CategoryGroupCode],
                   [GradeType],
                   [GradeLevel],
                   SUM([Inventory]) AS inventory
            FROM [data].[Inventory]
            WHERE PayPlan IN ( 'AO', 'AWO', 'RO', 'RWO', 'NO', 'NWO', 'NE', 'AE', 'RE' )
            GROUP BY [PayPlan],
                     [CategoryGroupCode],
                     [GradeType],
                     [GradeLevel]
        ) AS b
            ON LEFT(a.final_MOS, 2) = b.CategoryGroupCode
               AND a.final_GradeLevel = b.GradeLevel
               AND a.payplan = b.payplan
    WHERE LEN(a.final_MOS) = 2;
    --Bring in inventory for the payplan and grade  
    UPDATE crunch.TempATRRS_ATRM_Crs_MOS
    SET inventory = b.inventory
    FROM crunch.TempATRRS_ATRM_Crs_MOS AS a
        LEFT OUTER JOIN
        (
            SELECT [PayPlan],
                   [GradeType],
                   [GradeLevel],
                   SUM([Inventory]) AS inventory
            FROM [data].[Inventory]
            WHERE PayPlan IN ( 'AO', 'AWO', 'RO', 'RWO', 'NO', 'NWO', 'NE', 'AE', 'RE' )
            GROUP BY [PayPlan],
                     [GradeType],
                     [GradeLevel]
        ) AS b
            ON a.final_GradeLevel = b.GradeLevel
               AND a.payplan = b.payplan
    WHERE a.final_MOS = 'XXX';

    --when there is no inventory the value shows up as null, we want to change those to 0
    UPDATE crunch.TempATRRS_ATRM_Crs_MOS
    SET inventory = 0
    WHERE inventory IS NULL;



    IF @Debug = 1
    BEGIN
        SELECT 'these records do not have any inventory, it could be an invalid assignment by us or just a bad ATRRS record';
        SELECT ATRRS_Num_students,
               ATRRS_CrsType,
               ATRRS_Branch,
               ATRRS_MOS,
               ATRRS_GradeLevel,
               ATRRS_Crs_Title,
               ATRRS_School,
               ATRRS_Component,
               ATRRS_Crs_Num,
               ATRRS_Sch_Code,
               ATRRS_Version_id,
               AmcosVersionId,
               ATRRS_Key,
               ATRM_Key,
               ATRM_Version_id,
               ATRM_Sch_Code,
               ATRM_Crs_Num,
               ATRM_Crs_Title,
               ATRM_Location,
               ATRM_Activity,
               ATRM_Length_wks,
               ATRM_EGRADS,
               ATRM_Modal_Grade,
               ATRM_Frequency,
               ATRM_Flying_Hrs,
               ATRM_TMW_EGRD,
               ATRM_MPA,
               ATRM_OMA,
               ATRM_Other,
               Exception,
               Crs_Type_O,
               Crs_Type_E,
               WeaponSystemName,
               AOC,
               WOMOS,
               MOS,
               O_GradeLevel_Floor,
               O_GradeLevel_Ceiling,
               W_GradeLevel_Floor,
               W_GradeLevel_Ceiling,
               E_GradeLevel_Floor,
               E_GradeLevel_Ceiling,
               final_crs_type,
               final_MOS,
               final_Branch,
               final_Grade,
               final_GradeType,
               final_GradeLevel,
               payplan,
               atrrs_tot_students,
               adj_students,
               running_adj_students,
               inventory,
               inv_add,
               total_inv_add,
               final_adj_inv,
               final_adj_students
        FROM crunch.TempATRRS_ATRM_Crs_MOS
        WHERE inventory = 0
        ORDER BY final_MOS,
                 final_Grade,
                 ATRRS_Crs_Title;


    END;

    -- =============================================
    --make student adjustments
    -- =============================================
    --the ATRM data shows the number of graduates which can be compared to the number of students in ATRRS
    --when ATRRS Students exceeds ATRM Graduates we can throttle the number of students
    --when ATRRS Students falls short of ATRM Graduates we do nothing
    --purpose of this is to throttle costs by taking into account the reported graduates

    --first we need to calculate the total number of atrrs students for each course
    UPDATE crunch.TempATRRS_ATRM_Crs_MOS
    SET atrrs_tot_students = b.mycount
    FROM crunch.TempATRRS_ATRM_Crs_MOS AS a
        LEFT JOIN
        (
            SELECT AmcosVersionId,
                   ATRRS_Sch_Code,
                   ATRRS_Crs_Num,
                   SUM(ATRRS_Num_students) AS mycount
            FROM crunch.TempATRRS_ATRM_Crs_MOS
            GROUP BY AmcosVersionId,
                     ATRRS_Sch_Code,
                     ATRRS_Crs_Num
        ) AS b
            ON a.ATRRS_Sch_Code = b.ATRRS_Sch_Code
               AND a.ATRRS_Crs_Num = b.ATRRS_Crs_Num
               AND a.AmcosVersionId = b.AmcosVersionId;

    --next we calculate the adjusted students
    --first we fill in the adj_students field with the existing atrrs student count
    UPDATE crunch.TempATRRS_ATRM_Crs_MOS
    SET adj_students = ATRRS_Num_students;

    --now we adjust the student count for certain records
    UPDATE crunch.TempATRRS_ATRM_Crs_MOS
    SET adj_students = (ATRM_EGRADS / atrrs_tot_students) * ATRRS_Num_students
    --only reduce the total students, we do not want to inflate them as we trust atrrs except where it
    --exceeds atrm
    WHERE ATRM_EGRADS < atrrs_tot_students;



    --REVERSE THE EFFECTS OF THE ABOVE FOR TESTING PURPOSES
    --UPDATE crunch.TempATRRS_ATRM_Crs_MOS SET adj_students=atrrs_num_students


    -- =============================================
    --make inventory adjustments
    -- =============================================
    --conversions should be added to inventory in certain cases

    UPDATE crunch.TempATRRS_ATRM_Crs_MOS
    SET inv_add = 0;
    --if we converted positions then we should track those as additions to inventory

    --adjust inventory at the MOS level for warrants
    --their incoming MOS, if filled out, is exactly 4 digits
    UPDATE crunch.TempATRRS_ATRM_Crs_MOS
    SET inv_add = adj_students
    --when we changed the MOS, but also forget about the officers since they almost always come in without an MOS
    WHERE ATRRS_MOS <> final_MOS
          AND LEN(final_MOS) >= 3
          --we don't want to adjust inventory at the payplan level as that would be incorrectly addative
          AND final_MOS <> 'XXX'
          --we only do this for Warrants since their ATRRS reported MOS doesn't have a digit suffix
          AND final_GradeType = 'W';


    --adjust enlisted  and officers (most officers don't have an ATRRS MOS but some do) 
    --their incoming MOS, if filled out, can be 3 or 4 digits with some having a trailing suffix as the 4th digit which we do not care about
    UPDATE crunch.TempATRRS_ATRM_Crs_MOS
    SET inv_add = adj_students
    --when we changed the MOS, but also forget about the officers since they almost always come in without an MOS
    WHERE LEFT(ATRRS_MOS, 3) <> final_MOS
          AND ATRRS_MOS IS NOT NULL
          AND LEN(final_MOS) >= 3
          --we don't want to adjust inventory at the payplan level as that would be incorrectly addative
          AND final_MOS <> 'XXX'
          AND final_GradeType <> 'W';

    --adjust officers using branch (most officers don't have an MOS in ATRRS so we use some deduction to figure out if we are making a CMF conversion
    --their incoming MOS, if filled out, can be 3 or 4 digits with some having a trailing suffix as the 4th digit which we do not care about
    UPDATE crunch.TempATRRS_ATRM_Crs_MOS
    SET inv_add = adj_students
    --when we changed the MOS, but also forget about the officers since they almost always come in without an MOS
    WHERE ATRRS_Branch <> final_Branch
          AND final_GradeType = 'O'
          AND ATRRS_Branch IS NOT NULL
          --we don't want to adjust inventory at the payplan level as that would be incorrectly addative
          AND final_MOS <> 'XXX';



    --adjust inventory at the CMF level
    UPDATE crunch.TempATRRS_ATRM_Crs_MOS
    SET inv_add = adj_students
    --when we changed the CMF, but also forget about the officers since they almost always come in without an MOS
    WHERE LEFT(ATRRS_MOS, 2) <> LEFT(final_MOS, 2)
          AND final_GradeType <> 'O'
          --final MOS with a length of only 2 are our CMF level costs
          AND LEN(final_MOS) = 2;

    --if inventory is 0 then we don't touch that record since no cost elements are shown for records with 0 inventory
    --could have added this as a where clause to each of the above 3 statements but easier and more straightforward to just do a quick update here
    UPDATE crunch.TempATRRS_ATRM_Crs_MOS
    SET inv_add = 0
    WHERE inventory = 0






    --each ATRRS course can appear multiple times within a given AOC/MOS/WOMOS, PP, and gradelevel in cases where we made a manual conversion
    --if we don't account for this then we could average at the row level, but then the sum later on would cause an additive average which is not by any means the true average we want
    --we could account for this through an interim table with aggregation but we're going for one detailed table with all the steps so we have complete accountability of the entire process
    --from start to finish, so because of that we add 3 additional columns to assist with this important processing step

    --first give us a list of the running adjusted student total so we can stop adding costs when students outpace inventory
    ;
    WITH myAdjStudCTE
    AS (SELECT *, --running_adj_students,ATRRS_Sch_Code, ATRRS_Crs_Num, payplan, final_mos, final_Grade
               SUM(adj_students) OVER (PARTITION BY AmcosVersionId,
                                                    payplan,
                                                    ATRRS_Key,
                                                    final_MOS,
                                                    final_GradeLevel
                                       ORDER BY AmcosVersionId,
                                                payplan,
                                                ATRRS_Key,
                                                final_MOS,
                                                final_GradeLevel
                                      ) AS my_adj_students
        FROM crunch.TempATRRS_ATRM_Crs_MOS)
    UPDATE myAdjStudCTE
    SET running_adj_students = my_adj_students
    --FROM crunch.TempATRRS_ATRM_Crs_MOS AS a
    --INNER JOIN my_adj_students AS b ON a.ATRRS_Sch_Code=b.atrrs_sch_code AND a.ATRRS_Crs_Num=b.atrrs_crs_num and a.payplan=b.payplan AND a.final_mos=b.final_mos and a.final_Grade=b.final_Grade;


    --SELECT * FROM crunch.TempATRRS_ATRM_Crs_MOS
    --WHERE atrrs_crs_num='5E-F1/234-F41' AND payplan='AE' AND final_Grade='E4'

    ;
    WITH my_adj_inv
    AS (SELECT *,
               SUM(inv_add) OVER (PARTITION BY AmcosVersionId,
                                               ATRRS_Key,
                                               payplan,
                                               final_MOS,
                                               final_Grade
                                  ORDER BY ATRRS_Key,
                                           payplan,
                                           final_MOS,
                                           final_Grade
                                 ) AS my_inv_add
        FROM crunch.TempATRRS_ATRM_Crs_MOS)
    UPDATE my_adj_inv
    SET total_inv_add = my_inv_add;
    --FROM crunch.TempATRRS_ATRM_Crs_MOS AS a
    --INNER JOIN my_adj_inv AS b ON a.ATRRS_Sch_Code=b.atrrs_sch_code AND a.ATRRS_Crs_Num=b.atrrs_crs_num and a.payplan=b.payplan AND a.final_mos=b.final_mos and a.final_GradeType=b.final_Grade;



    --the final inventory is the base inventory plus all the inventory conversions we made
    UPDATE crunch.TempATRRS_ATRM_Crs_MOS
    --inventory add was removed when we went to the CGLA math, away from the show costs where they lay process which Mr Barth did not like
    SET final_adj_inv = inventory + total_inv_add;




    UPDATE crunch.TempATRRS_ATRM_Crs_MOS
    SET final_adj_students = 0;
    --compute the final adjusted students, there are 3 scenarios
    --1) the row's students don't exceed the adj inventory so we compute the cost for the row as an average

    UPDATE crunch.TempATRRS_ATRM_Crs_MOS
    SET final_adj_students = adj_students
    WHERE running_adj_students <= (final_adj_inv);





    --2) the row's students exceed the adj inventory
    --2a) but the row has some # of students which are under the adjusted inventory cap so we compute an average cost for those

    UPDATE crunch.TempATRRS_ATRM_Crs_MOS
    SET final_adj_students = CONVERT(INT, (final_adj_inv - (running_adj_students - adj_students)))
                             % NULLIF(CONVERT(INT, adj_students), 0)
    WHERE
        --need to be above adjusted inventory
        running_adj_students > final_adj_inv
        --need to have some headspace left in inventory
        AND final_adj_inv - (running_adj_students - adj_students) > 0;

    --2b) the # of students already exceeded adjusted inventory in a prior row so we return 0 
    --we do nothing here to default to a zero

    -- Basic training should costs should only appear up to GL4 per email with Marsha on 12/20/2018 therefore we set GL5 and above costs to 0
    UPDATE crunch.TempATRRS_ATRM_Crs_MOS
    SET adj_students = 0
    WHERE final_crs_type = 'B'
          AND final_GradeLevel >= 5
          AND final_GradeType = 'E';

    -- =============================================
    DROP TABLE IF EXISTS crunch.TempTraining_Costs_by_version;
    CREATE TABLE crunch.TempTraining_Costs_by_version
    (
        [AmcosVersionId] INT NULL,
        [ATRM_Key] NVARCHAR(255) NULL,
        [ATRRS_Key] NVARCHAR(255) NULL,
        [ATRM_Crs_Title] NVARCHAR(255) NULL,
        [ATRM_Location] NVARCHAR(255) NULL,
        [atrm_mpa] FLOAT NULL,
        [atrm_oma] FLOAT NULL,
        [atrm_other] FLOAT NULL,
        [inventory] INT NULL,
        [payplan] NVARCHAR(10) NULL,
        [final_MOS] NVARCHAR(10) NULL,
        [final_crs_type] NVARCHAR(10) NULL,
        [WeaponSystemName] NVARCHAR(50) NULL,
        [final_GradeType] NVARCHAR(10) NULL,
        [final_GradeLevel] NVARCHAR(10) NULL,
        [adj_students] FLOAT NULL,
        [MPA_Total_Cost] FLOAT NULL,
        [OMA_Total_Cost] FLOAT NULL,
        [Other_Total_cost] FLOAT NULL
    );

    INSERT INTO crunch.TempTraining_Costs_by_version
    (
        AmcosVersionId,
        ATRM_Key,
        ATRRS_Key,
        ATRM_Crs_Title,
        ATRM_Location,
        atrm_mpa,
        atrm_oma,
        atrm_other,
        inventory,
        payplan,
        final_MOS,
        final_crs_type,
        WeaponSystemName,
        final_GradeType,
        final_GradeLevel,
        adj_students,
        MPA_Total_Cost,
        OMA_Total_Cost,
        Other_Total_cost
    )
    SELECT AmcosVersionId,
           ATRM_Key,
           ATRRS_Key,
           ATRM_Crs_Title,
           ATRM_Location,
           MAX(ATRM_MPA) AS atrm_mpa,
           MAX(ATRM_OMA) AS atrm_oma,
           MAX(ATRM_Other) AS atrm_other,
           MAX(inventory) AS inventory,
           payplan,
           final_MOS,
           final_crs_type,
           WeaponSystemName,
           final_GradeType,
           final_GradeLevel,
           SUM(adj_students) AS adj_students,
           0.0 AS MPA_Total_Cost,
           0.0 AS OMA_Total_Cost,
           0.0 AS Other_Total_cost
    FROM crunch.TempATRRS_ATRM_Crs_MOS
    GROUP BY AmcosVersionId,
             ATRM_Key,
             ATRRS_Key,
             ATRM_Crs_Title,
             ATRM_Location,
             payplan,
             final_MOS,
             final_crs_type,
             WeaponSystemName,
             final_GradeType,
             final_GradeLevel;


    -- =============================================
    --compute costs
    -- =============================================
    --when the students exceed inventory use inventory
    --this prevents a situation where say 25 people attend a class for an E5 when there is only E5 inventory of 1 and no E6 or above exist
    --that would create astronimcal costs which are not reasonable
    --such a scenario is likely possible due both to our converting MOSes/AOCes and the questionable attendee data from ATRRs in some cases

    UPDATE crunch.TempTraining_Costs_by_version
    SET MPA_Total_Cost = CASE
                             WHEN adj_students > inventory THEN
                                 inventory * atrm_mpa
                             ELSE
                                 adj_students * atrm_mpa
                         END,
        OMA_Total_Cost = CASE
                             WHEN adj_students > inventory THEN
                                 inventory * atrm_oma
                             ELSE
                                 adj_students * atrm_oma
                         END,
        Other_Total_cost = CASE
                               WHEN adj_students > inventory THEN
                                   inventory * atrm_other
                               ELSE
                                   adj_students * atrm_other
                           END;







    -- =============================================
    --generate a average table
    -- =============================================
    DROP TABLE IF EXISTS crunch.TempTraining_Costs_avg;
    CREATE TABLE crunch.TempTraining_Costs_avg
    (
        [WeaponSystemName] NVARCHAR(50) NULL,
        [final_crs_type] NVARCHAR(10) NULL,
        [final_MOS] NVARCHAR(10) NULL,
        [final_GradeType] NVARCHAR(10) NULL,
        [final_GradeLevel] NVARCHAR(10) NULL,
        [payplan] NVARCHAR(10) NULL,
        [inv] INT NULL,
        [mpa_total_avg_cost] FLOAT NULL,
        [oma_total_avg_cost] FLOAT NULL,
        [other_total_avg_cost] FLOAT NULL,
        [MPA_adj] FLOAT NULL,
        [OMA_adj] FLOAT NULL,
        [Other_adj] FLOAT NULL
    );

    --because we are going to use this table a few times its less overhead to generate one summation table then to keep using an aggregation of the TempATRRS_ATRM_CRS_MOS table
    INSERT INTO crunch.TempTraining_Costs_avg
    (
        WeaponSystemName,
        final_crs_type,
        final_MOS,
        final_GradeType,
        final_GradeLevel,
        payplan,
        inv,
        mpa_total_avg_cost,
        oma_total_avg_cost,
        other_total_avg_cost,
        MPA_adj,
        OMA_adj,
        Other_adj
    )
    SELECT a.WeaponSystemName,
           a.final_crs_type,
           a.final_MOS,
           a.final_GradeType,
           a.final_GradeLevel,
           a.payplan,
           a.inv,
           a.mpa_total_avg_cost,
           a.oma_total_avg_cost,
           a.other_total_avg_cost,
           0.0 AS MPA_adj,
           0.0 AS OMA_adj,
           0.0 AS Other_adj
    FROM
    (
        SELECT WeaponSystemName,
               final_crs_type,
               final_MOS,
               final_GradeType,
               final_GradeLevel,
               payplan,
               MAX(inventory) AS inv,
               AVG(MPA_Total_Cost) AS mpa_total_avg_cost,
               AVG(OMA_Total_Cost) AS oma_total_avg_cost,
               AVG(Other_Total_cost) AS other_total_avg_cost
        FROM crunch.TempTraining_Costs_by_version
        GROUP BY WeaponSystemName,
                 final_crs_type,
                 final_MOS,
                 final_GradeType,
                 final_GradeLevel,
                 payplan
    ) AS a;




    -- =============================================
    --Adjust the Average table by bringing in Budget data
    -- =============================================
    --Army budget data gives us an idea of how much is budgeted for training types, we can use this to bring the ATRRS and ATRM data back in line with the budget
    --we could have just used the army budget data but then we'd have the same training amount for every soldier and that's too generic for AMCOS

    DECLARE @OSUT_Total AS FLOAT,
            @OSUT_Budget AS FLOAT,
            @OSUT_Perc AS FLOAT,
            @B_Total AS FLOAT,
            @B_budget AS FLOAT,
            @B_perc AS FLOAT,
            @PC_total AS FLOAT,
            @PC_budget AS FLOAT,
            @PC_perc AS FLOAT,
            @AIT_IET_Total AS FLOAT,
            @AIT_IET_budget AS FLOAT,
            @AIT_IET_Perc AS FLOAT,
            @Training_Budget_Total AS FLOAT,
            @Unallocated_Training_Budget AS FLOAT,
            @unallocated_budget_per_soldier AS FLOAT;


    --Before we do any adjustments we need to implement a rule on reporting codes
    --Per discussion with marsha on 11/14/2018, reporting codes will not get MOS level ATRM/ATRRS costs
    --any MOS level ATRM/ATRRS costs they have will be zero-d out, this is to prevent unnatural spikes of costs (e.g. some reporting code person going to an expensive blackhawk course
    UPDATE crunch.TempTraining_Costs_avg
    SET mpa_total_avg_cost = 0,
        oma_total_avg_cost = 0,
        other_total_avg_cost = 0
    WHERE LEFT(final_MOS, 1) = '0';


    --compute our ATRM/ATRRS generated course totals
    SET @OSUT_Total =
    (
        SELECT SUM(oma_total_avg_cost) + SUM(other_total_avg_cost)
        FROM crunch.TempTraining_Costs_avg
        WHERE final_crs_type IN ( 'OSUT' )
    );
    SET @B_Total =
    (
        SELECT SUM(oma_total_avg_cost) + SUM(other_total_avg_cost)
        FROM crunch.TempTraining_Costs_avg
        WHERE final_crs_type IN ( 'B' )
    );
    SET @PC_total =
    (
        SELECT SUM(oma_total_avg_cost) + SUM(other_total_avg_cost)
        FROM crunch.TempTraining_Costs_avg
        WHERE final_crs_type IN ( 'P', 'C' )
    );
    SET @AIT_IET_Total =
    (
        SELECT SUM(oma_total_avg_cost) + SUM(other_total_avg_cost)
        FROM crunch.TempTraining_Costs_avg
        WHERE final_crs_type IN ( 'IET', 'AIT' )
    );

    --get the budget amounts
    SET @OSUT_Budget =
    (
        SELECT Amount
        FROM crunch.TempArmyBudgetSingleValues
        WHERE Appropriation = 'OMA'
              AND ParameterName = 'Training-OSUT'
    );
    SET @B_budget =
    (
        SELECT Amount
        FROM crunch.TempArmyBudgetSingleValues
        WHERE Appropriation = 'OMA'
              AND ParameterName = 'Training-Recruit'
    );
    SET @PC_budget =
    (
        SELECT Amount
        FROM crunch.TempArmyBudgetSingleValues
        WHERE Appropriation = 'OMA'
              AND ParameterName = 'Training-Professional Development Education'
    );
    SET @AIT_IET_budget =
    (
        SELECT Amount
        FROM crunch.TempArmyBudgetSingleValues
        WHERE Appropriation = 'OMA'
              AND ParameterName = 'Training-Specialized Skill'
    );
    SET @Training_Budget_Total =
    (
        SELECT SUM(Amount)
        FROM crunch.TempArmyBudgetSingleValues
        WHERE Appropriation = 'OMA'
              AND ParameterName IN ( 'Training-OSUT', 'Training-Specialized Skill', 'Training-Support',
                                     'Training-Flight', 'Training-Professional Development Education',
                                     'Training-Recruit'
                                   )
    );

    --compute the factors
    SET @OSUT_Perc = @OSUT_Budget / @OSUT_Total;
    SET @B_perc = @B_budget / @B_Total;
    SET @PC_perc = @PC_budget / @PC_total;
    SET @AIT_IET_Perc = @AIT_IET_budget / @AIT_IET_Total;

    --bring the factors into our table
    UPDATE crunch.TempTraining_Costs_avg
    SET MPA_adj = mpa_total_avg_cost * @OSUT_Perc,
        OMA_adj = oma_total_avg_cost * @OSUT_Perc,
        Other_adj = other_total_avg_cost * @OSUT_Perc
    WHERE final_crs_type IN ( 'OSUT' );

    UPDATE crunch.TempTraining_Costs_avg
    SET MPA_adj = mpa_total_avg_cost * @B_perc,
        OMA_adj = oma_total_avg_cost * @B_perc,
        Other_adj = other_total_avg_cost * @B_perc
    WHERE final_crs_type IN ( 'B' );

    UPDATE crunch.TempTraining_Costs_avg
    SET MPA_adj = mpa_total_avg_cost * @PC_perc,
        OMA_adj = oma_total_avg_cost * @PC_perc,
        Other_adj = other_total_avg_cost * @PC_perc
    WHERE final_crs_type IN ( 'P', 'C' );

    UPDATE crunch.TempTraining_Costs_avg
    SET MPA_adj = mpa_total_avg_cost * @AIT_IET_Perc,
        OMA_adj = oma_total_avg_cost * @AIT_IET_Perc,
        Other_adj = other_total_avg_cost * @AIT_IET_Perc
    WHERE final_crs_type IN ( 'AIT', 'IET' );

    UPDATE crunch.TempTraining_Costs_avg
    SET MPA_adj = mpa_total_avg_cost,
        OMA_adj = oma_total_avg_cost,
        Other_adj = other_total_avg_cost
    WHERE final_crs_type IN ( 'W', 'F', 'O' );

    SET @Unallocated_Training_Budget = @Training_Budget_Total -
                                       (
                                           SELECT SUM(OMA_adj) + SUM(Other_adj) FROM crunch.TempTraining_Costs_avg
                                       );
    SET @unallocated_budget_per_soldier = @Unallocated_Training_Budget /
                                          (
                                              SELECT SUM(Inventory)
                                              FROM data.Inventory
                                              WHERE PayPlan IN ( 'AO', 'AWO', 'AE' )
                                          );




    IF @Debug = 1
    BEGIN
        SELECT 'total table thus far';
        SELECT final_crs_type,
               SUM(mpa_total_avg_cost) AS mpa_total,
               (SUM(oma_total_avg_cost) + SUM(other_total_avg_cost)) AS OMA,
               SUM(MPA_adj) AS mpa_adj,
               (SUM(OMA_adj) + SUM(Other_adj)) AS oma_adj
        FROM crunch.TempTraining_Costs_avg
        GROUP BY final_crs_type;
        SELECT CONCAT('OSUT_Amt ', FORMAT(@OSUT_Total, 'C', 'en-us'));
        SELECT CONCAT('OSUT_Budget', FORMAT(@OSUT_Budget, 'C', 'en-us'));
        SELECT CONCAT('OSUT Perc ', @OSUT_Perc);
        SELECT CONCAT('B_Amt ', FORMAT(@B_Total, 'C', 'en-us'));
        SELECT CONCAT('B_Budget', FORMAT(@B_budget, 'C', 'en-us'));
        SELECT CONCAT('B Perc ', @B_perc);
        SELECT CONCAT('PC_Amt ', FORMAT(@PC_total, 'C', 'en-us'));
        SELECT CONCAT('PC_Budget', FORMAT(@PC_budget, 'C', 'en-us'));
        SELECT CONCAT('PC Perc ', @PC_perc);
        SELECT CONCAT('AIT IET_Amt ', FORMAT(@AIT_IET_Total, 'C', 'en-us'));
        SELECT CONCAT('AIT IET_Budget', FORMAT(@AIT_IET_budget, 'C', 'en-us'));
        SELECT CONCAT('AIT IET Perc ', @AIT_IET_Perc);
        SELECT CONCAT('Training Budget', FORMAT(@Training_Budget_Total, 'C', 'en-us'));
        SELECT CONCAT('Unalocated Training Budget', FORMAT(@Unallocated_Training_Budget, 'C', 'en-us'));
        SELECT CONCAT('Unalocated Training Budget per soldier', FORMAT(@unallocated_budget_per_soldier, 'C', 'en-us'));
    END;

    -- =============================================
    --generate final costs
    -- =============================================
    DROP TABLE IF EXISTS crunch.TempTraining_Costs;
    CREATE TABLE crunch.TempTraining_Costs
    (
        [WeaponSystemName] NVARCHAR(50) NULL,
        [coursetype] NVARCHAR(10) NULL,
        [PayPlan] NVARCHAR(3) NOT NULL,
        [CategoryGroupCode] NVARCHAR(4) NOT NULL,
        [CategorySubGroupCode] NVARCHAR(4) NOT NULL,
        [GradeType] NVARCHAR(3) NOT NULL,
        [GradeLevel] TINYINT NOT NULL,
        [inventory] INT NULL,
        [MPA_MOS] FLOAT NULL,
        [OMA_MOS] FLOAT NULL,
        [Other_MOS] FLOAT NULL,
        [MPA_CMF] FLOAT NULL,
        [OMA_CMF] FLOAT NULL,
        [Other_CMF] FLOAT NULL,
        [MPA_PP] FLOAT NULL,
        [OMA_PP] FLOAT NULL,
        [other_PP] FLOAT NULL,
        [CGLA_MOS_inv] FLOAT NULL,
        [CGLA_CMF_Inv] FLOAT NULL,
        [CGLA_PP_inv] FLOAT NULL,
        [CGLA_MPA] FLOAT NULL,
        [CGLA_OMA] FLOAT NULL,
        [CGLA_Other] FLOAT NULL,
        [RPA_NGPA] FLOAT NULL,
        [OMAR_OMNG] FLOAT NULL,
        [WeaponSystemId] INT NULL
    );

    --we have to start with the inventory table, this is because we may have an MOS with no MOS specific costs but it still should get CMF or PayPlan total costs
    --if we started with the ATRM/ATRRS table we migth miss those
    --then we left join with the summation table, this makes sure multiple entries for Crs Type W (Weapon system) are also included in case thee are costs at the CMF or Pay Plan level

    INSERT INTO crunch.TempTraining_Costs
    (
        PayPlan,
        CategoryGroupCode,
        CategorySubGroupCode,
        GradeType,
        GradeLevel,
        WeaponSystemName,
        coursetype,
        inventory,
        MPA_MOS,
        OMA_MOS,
        Other_MOS,
        MPA_CMF,
        OMA_CMF,
        Other_CMF,
        MPA_PP,
        OMA_PP,
        other_PP,
        CGLA_MOS_inv,
        CGLA_CMF_Inv,
        CGLA_PP_inv,
        CGLA_MPA,
        CGLA_OMA,
        CGLA_Other,
        RPA_NGPA,
        OMAR_OMNG,
        WeaponSystemId
    )
    SELECT a.PayPlan,
           a.CategoryGroupCode,
           a.CategorySubGroupCode,
           a.GradeType,
           a.GradeLevel,
           a.WeaponSystemName,
           a.coursetype,
           a.inventory,
           0.0 AS MPA_MOS,
           0.0 AS OMA_MOS,
           0.0 AS Other_MOS,
           0.0 MPA_CMF,
           0.0 OMA_CMF,
           0.0 Other_CMF,
           0.0 MPA_PP,
           0.0 OMA_PP,
           0.0 other_PP,
           0.0 AS CGLA_MOS_inv,
           0.0 AS CGLA_CMF_Inv,
           0.0 AS CGLA_PP_inv,
           0.0 AS CGLA_MPA,
           0.0 AS CGLA_OMA,
           0.0 AS CGLA_Other,
           0.0 AS RPA_NGPA,
           0.0 AS OMAR_OMNG,
           @int AS WeaponSystemId
    FROM
    (
        SELECT a.*,
               b.coursetype,
               b.WeaponSystemName
        FROM
        (
            SELECT [PayPlan],
                   [CategoryGroupCode],
                   [CategorySubGroupCode],
                   [GradeType],
                   [GradeLevel],
                   SUM(Inventory) AS inventory
            FROM [data].[Inventory]
            WHERE PayPlan IN ( 'AO', 'AWO', 'RO', 'RWO', 'NO', 'NWO', 'NE', 'AE', 'RE' )
            GROUP BY [PayPlan],
                     [CategoryGroupCode],
                     [CategorySubGroupCode],
                     [GradeType],
                     [GradeLevel]
        ) AS a
            FULL OUTER JOIN
            (
                --use our average cost table as the source for all possible course type and wpn combinations
                SELECT payplan,
                       final_crs_type AS coursetype,
                       WeaponSystemName
                FROM crunch.TempTraining_Costs_avg
                WHERE final_crs_type IS NOT NULL
                GROUP BY payplan,
                         final_crs_type,
                         WeaponSystemName
                UNION
                --the following gives us a course type for general training costs from the budget
                SELECT 'AO' AS payplan,
                       'G' AS final_crs_type,
                       NULL AS WeaponSystemName
                UNION
                SELECT 'AE' AS payplan,
                       'G' AS final_crs_type,
                       NULL AS WeaponSystemName
                UNION
                SELECT 'AWO' AS payplan,
                       'G' AS final_crs_type,
                       NULL AS WeaponSystemName
                UNION
                SELECT 'RO' AS payplan,
                       'G' AS final_crs_type,
                       NULL AS WeaponSystemName
                UNION
                SELECT 'RE' AS payplan,
                       'G' AS final_crs_type,
                       NULL AS WeaponSystemName
                UNION
                SELECT 'RWO' AS payplan,
                       'G' AS final_crs_type,
                       NULL AS WeaponSystemName
                UNION
                SELECT 'NO' AS payplan,
                       'G' AS final_crs_type,
                       NULL AS WeaponSystemName
                UNION
                SELECT 'NE' AS payplan,
                       'G' AS final_crs_type,
                       NULL AS WeaponSystemName
                UNION
                SELECT 'NWO' AS payplan,
                       'G' AS final_crs_type,
                       NULL AS WeaponSystemName
                --our business rules indicate that for the active IET is only for officer/warrants
                --but the JBooks have IET costs for the NG/R enlisted so we need to have a way to capture those
                UNION
                SELECT 'RE' AS payplan,
                       'IET' AS final_crs_type,
                       NULL AS WeaponSystemName
                UNION
                SELECT 'NE' AS payplan,
                       'IET' AS final_crs_type,
                       NULL AS WeaponSystemName
            ) AS b
                ON a.PayPlan = b.PayPlan
    ) AS a;





    --generate CGLA inventory at the SUBGROUP level
    --compute my CGLA inventory
    --cgla is the cummulative inventory at or above any one payplan & subgroup combination
    --it is later used to compute CGLA
    UPDATE crunch.TempTraining_Costs
    SET CGLA_MOS_inv = b.inv_cumulative
    FROM crunch.TempTraining_Costs AS a
        INNER JOIN
        (
            --compute the reverse sum which wil later be used to do Cross Grade Level Averaging (CGLA)
            SELECT PayPlan,
                   CategorySubGroupCode,
                   GradeType,
                   GradeLevel,
                   inventory,
                   SUM(inventory) OVER (PARTITION BY PayPlan,
                                                     CategorySubGroupCode
                                        ORDER BY PayPlan,
                                                 CategorySubGroupCode,
                                                 GradeLevel DESC
                                       )
                   + crunch.GetParentInventoryRecursive(PayPlan, CategorySubGroupCode, GradeType, GradeLevel) AS inv_cumulative
            FROM
            (
                SELECT PayPlan,
                       CategorySubGroupCode,
                       GradeType,
                       GradeLevel,
                       SUM(Inventory) AS inventory
                FROM data.Inventory
                GROUP BY PayPlan,
                         CategorySubGroupCode,
                         GradeType,
                         GradeLevel
            ) AS a
            GROUP BY PayPlan,
                     CategorySubGroupCode,
                     GradeType,
                     GradeLevel,
                     inventory
        ) AS b
            ON a.PayPlan = b.PayPlan
               AND a.CategorySubGroupCode = b.CategorySubGroupCode
               AND a.GradeLevel = b.GradeLevel;


    --generate CGLA inventory at the GROUP level
    --compute my CGLA inventory
    --cgla is the cummulative inventory at or above any one payplan & subgroup combination
    --it is later used to compute CGLA
    UPDATE crunch.TempTraining_Costs
    SET CGLA_CMF_Inv = b.inv_cumulative
    FROM crunch.TempTraining_Costs AS a
        INNER JOIN
        (
            --compute the reverse sum which wil later be used to do Cross Grade Level Averaging (CGLA)
            SELECT PayPlan,
                   CategoryGroupCode,
                   GradeType,
                   GradeLevel,
                   inventory,
                   SUM(inventory) OVER (PARTITION BY PayPlan,
                                                     CategoryGroupCode
                                        ORDER BY PayPlan,
                                                 CategoryGroupCode,
                                                 GradeLevel DESC
                                       ) AS inv_cumulative
            FROM
            (
                SELECT PayPlan,
                       CategoryGroupCode,
                       GradeType,
                       GradeLevel,
                       SUM(Inventory) AS inventory
                FROM data.Inventory
                GROUP BY PayPlan,
                         CategoryGroupCode,
                         GradeType,
                         GradeLevel
            ) AS a
            GROUP BY PayPlan,
                     CategoryGroupCode,
                     GradeType,
                     GradeLevel,
                     inventory
        ) AS b
            --no change is needed to this where because only final_mos with a length of 2 (CMF level) will catch on this 'on' clause
            ON a.PayPlan = b.PayPlan
               AND a.CategoryGroupCode = b.CategoryGroupCode
               AND a.GradeLevel = b.GradeLevel;

    --generate CGLA inventory at the PAYPLAN level
    --compute my CGLA inventory
    --cgla is the cummulative inventory at or above any one payplan & subgroup combination
    --it is later used to compute CGLA
    UPDATE crunch.TempTraining_Costs
    SET CGLA_PP_inv = b.inv_cumulative
    FROM crunch.TempTraining_Costs AS a
        INNER JOIN
        (
            --compute the reverse sum which wil later be used to do Cross Grade Level Averaging (CGLA)
            SELECT PayPlan,
                   GradeType,
                   GradeLevel,
                   inventory,
                   SUM(inventory) OVER (PARTITION BY PayPlan ORDER BY PayPlan, GradeLevel DESC) AS inv_cumulative
            FROM
            (
                SELECT PayPlan,
                       GradeType,
                       GradeLevel,
                       SUM(Inventory) AS inventory
                FROM data.Inventory
                GROUP BY PayPlan,
                         GradeType,
                         GradeLevel
            ) AS a
            GROUP BY PayPlan,
                     GradeType,
                     GradeLevel,
                     inventory
        ) AS b
            ON a.PayPlan = b.PayPlan
               AND a.GradeLevel = b.GradeLevel;

    IF @Debug = 1
    BEGIN
        SELECT 'crunch.TempTraining_Costs_avg';
        SELECT WeaponSystemName,
               final_crs_type,
               final_MOS,
               final_GradeType,
               final_GradeLevel,
               payplan,
               inv,
               mpa_total_avg_cost,
               oma_total_avg_cost,
               other_total_avg_cost,
               MPA_adj,
               OMA_adj,
               Other_adj
        FROM crunch.TempTraining_Costs_avg
        WHERE final_GradeLevel = 1
              AND final_MOS = '15A'
              AND payplan = 'RO';
    END;


    IF @Debug = 1
    BEGIN
        SELECT 'Raw data';
        SELECT ATRRS_Num_students,
               ATRRS_CrsType,
               ATRRS_Branch,
               ATRRS_MOS,
               ATRRS_GradeLevel,
               ATRRS_Crs_Title,
               ATRRS_School,
               ATRRS_Component,
               ATRRS_Crs_Num,
               ATRRS_Sch_Code,
               ATRRS_Version_id,
               AmcosVersionId,
               ATRRS_Key,
               ATRM_Key,
               ATRM_Version_id,
               ATRM_Sch_Code,
               ATRM_Crs_Num,
               ATRM_Crs_Title,
               ATRM_Location,
               ATRM_Activity,
               ATRM_Length_wks,
               ATRM_EGRADS,
               ATRM_Modal_Grade,
               ATRM_Frequency,
               ATRM_Flying_Hrs,
               ATRM_TMW_EGRD,
               ATRM_MPA,
               ATRM_OMA,
               ATRM_Other,
               Exception,
               Crs_Type_O,
               Crs_Type_E,
               WeaponSystemName,
               AOC,
               WOMOS,
               MOS,
               O_GradeLevel_Floor,
               O_GradeLevel_Ceiling,
               W_GradeLevel_Floor,
               W_GradeLevel_Ceiling,
               E_GradeLevel_Floor,
               E_GradeLevel_Ceiling,
               final_crs_type,
               final_MOS,
               final_Branch,
               final_Grade,
               final_GradeType,
               final_GradeLevel,
               payplan,
               atrrs_tot_students,
               adj_students,
               running_adj_students,
               inventory,
               inv_add,
               total_inv_add,
               final_adj_inv,
               final_adj_students
        FROM crunch.TempATRRS_ATRM_Crs_MOS
        WHERE final_GradeLevel = 1
              AND final_MOS = '15A'
              AND payplan = 'RO';
    END;


    --bring in the average total costs from crunch.TempTraining_Costs_avg for MOS FOR WEAPON SYSTEM only
    UPDATE crunch.TempTraining_Costs
    SET MPA_MOS = ISNULL(b.MPA_adj, 0),
        OMA_MOS = ISNULL(b.oma_total_avg_cost, 0),
        Other_MOS = ISNULL(b.other_total_avg_cost, 0)
    FROM crunch.TempTraining_Costs AS a
        INNER JOIN crunch.TempTraining_Costs_avg AS b
            ON a.PayPlan = b.payplan
               AND a.CategorySubGroupCode = b.final_MOS
               AND a.GradeLevel = b.final_GradeLevel
               AND a.coursetype = b.final_crs_type
               AND a.WeaponSystemName = b.WeaponSystemName
    WHERE a.coursetype = 'W';

    IF @Debug = 1
    BEGIN
        SELECT 'Before';
        SELECT WeaponSystemName,
               coursetype,
               PayPlan,
               CategoryGroupCode,
               CategorySubGroupCode,
               GradeType,
               GradeLevel,
               inventory,
               MPA_MOS,
               OMA_MOS,
               Other_MOS,
               MPA_CMF,
               OMA_CMF,
               Other_CMF,
               MPA_PP,
               OMA_PP,
               other_PP,
               CGLA_MOS_inv,
               CGLA_CMF_Inv,
               CGLA_PP_inv,
               CGLA_MPA,
               CGLA_OMA,
               CGLA_Other,
               RPA_NGPA,
               OMAR_OMNG,
               WeaponSystemId
        FROM crunch.TempTraining_Costs
        WHERE PayPlan = 'RO'
              AND CategorySubGroupCode = '15A'
              AND GradeLevel = 1;
    END;

    --bring in the average total costs from crunch.TempTraining_Costs_avg for MOS for non-weapon system
    UPDATE crunch.TempTraining_Costs
    SET MPA_MOS = ISNULL(b.MPA_adj, 0),
        OMA_MOS = ISNULL(b.OMA_adj, 0),
        Other_MOS = ISNULL(b.Other_adj, 0)
    FROM crunch.TempTraining_Costs AS a
        INNER JOIN crunch.TempTraining_Costs_avg AS b
            ON a.PayPlan = b.payplan
               AND a.CategorySubGroupCode = b.final_MOS
               AND a.GradeLevel = b.final_GradeLevel
               AND a.coursetype = b.final_crs_type
    WHERE a.coursetype <> 'W';

    IF @Debug = 1
    BEGIN
        SELECT 'After';
        SELECT WeaponSystemName,
               coursetype,
               PayPlan,
               CategoryGroupCode,
               CategorySubGroupCode,
               GradeType,
               GradeLevel,
               inventory,
               MPA_MOS,
               OMA_MOS,
               Other_MOS,
               MPA_CMF,
               OMA_CMF,
               Other_CMF,
               MPA_PP,
               OMA_PP,
               other_PP,
               CGLA_MOS_inv,
               CGLA_CMF_Inv,
               CGLA_PP_inv,
               CGLA_MPA,
               CGLA_OMA,
               CGLA_Other,
               RPA_NGPA,
               OMAR_OMNG,
               WeaponSystemId
        FROM crunch.TempTraining_Costs
        WHERE PayPlan = 'RO'
              AND CategorySubGroupCode = '15A'
              AND GradeLevel = 1;
    END;



    --bring in the average total costs from crunch.TempTraining_Costs_avg for CMF for weapon system only
    UPDATE crunch.TempTraining_Costs
    SET MPA_CMF = ISNULL(b.MPA_adj, 0),
        OMA_CMF = ISNULL(b.OMA_adj, 0),
        Other_CMF = ISNULL(b.Other_adj, 0)
    FROM crunch.TempTraining_Costs AS a
        INNER JOIN crunch.TempTraining_Costs_avg AS b
            ON a.PayPlan = b.payplan
               AND a.CategoryGroupCode = b.final_MOS
               AND a.GradeLevel = b.final_GradeLevel
               AND a.coursetype = b.final_crs_type
               AND a.WeaponSystemName = b.WeaponSystemName
    WHERE a.coursetype = 'W';

    --bring in the average total costs from crunch.TempTraining_Costs_avg for CMF for non-weapon system
    UPDATE crunch.TempTraining_Costs
    SET MPA_CMF = ISNULL(b.MPA_adj, 0),
        OMA_CMF = ISNULL(b.OMA_adj, 0),
        Other_CMF = ISNULL(b.Other_adj, 0)
    FROM crunch.TempTraining_Costs AS a
        INNER JOIN crunch.TempTraining_Costs_avg AS b
            ON a.PayPlan = b.payplan
               AND a.CategoryGroupCode = b.final_MOS
               AND a.GradeLevel = b.final_GradeLevel
               AND a.coursetype = b.final_crs_type
    WHERE a.coursetype <> 'W';


    --bring in the average total costs from crunch.TempTraining_Costs_avg for PP for weapon system only
    UPDATE crunch.TempTraining_Costs
    SET MPA_PP = ISNULL(b.MPA_adj, 0),
        OMA_PP = ISNULL(b.OMA_adj, 0),
        other_PP = ISNULL(b.Other_adj, 0)
    FROM crunch.TempTraining_Costs AS a
        INNER JOIN crunch.TempTraining_Costs_avg AS b
            ON a.PayPlan = b.payplan
               AND a.GradeLevel = b.final_GradeLevel
               AND a.coursetype = b.final_crs_type
               AND a.WeaponSystemName = b.WeaponSystemName
    WHERE b.final_MOS = 'XXX'
          AND a.coursetype = 'W';

    --bring in the average total costs from crunch.TempTraining_Costs_avg for PP for non-weapon system only
    UPDATE crunch.TempTraining_Costs
    SET MPA_PP = ISNULL(b.MPA_adj, 0),
        OMA_PP = ISNULL(b.OMA_adj, 0),
        other_PP = ISNULL(b.Other_adj, 0)
    FROM crunch.TempTraining_Costs AS a
        INNER JOIN crunch.TempTraining_Costs_avg AS b
            ON a.PayPlan = b.payplan
               AND a.GradeLevel = b.final_GradeLevel
               AND a.coursetype = b.final_crs_type
    WHERE b.final_MOS = 'XXX'
          AND a.coursetype <> 'W';


    --bring in the weapon system IDs
    UPDATE crunch.TempTraining_Costs
    SET WeaponSystemId = WeaponSystem.WeaponSystemId
    FROM crunch.TempTraining_Costs AS a
        INNER JOIN lookup.WeaponSystem AS WeaponSystem
            ON a.WeaponSystemName = WeaponSystem.WeaponSystemName
    WHERE a.coursetype = 'W';

    --execute the CGLA math to spread a costs at the SUBGROUP level with WPN system
    UPDATE crunch.TempTraining_Costs
    SET CGLA_MPA = a.CGLA_MPA + ISNULL(b.mpa, 0),
        CGLA_OMA = a.CGLA_OMA + ISNULL(b.oma, 0),
        CGLA_Other = a.CGLA_Other + ISNULL(b.other, 0)
    FROM crunch.TempTraining_Costs AS a
        INNER JOIN
        (
            SELECT *,
                   SUM(MPA_MOS / NULLIF(CGLA_MOS_inv, 0)) OVER (PARTITION BY PayPlan,
                                                                             CategorySubGroupCode,
                                                                             coursetype,
                                                                             WeaponSystemName
                                                                ORDER BY PayPlan,
                                                                         CategorySubGroupCode,
                                                                         coursetype,
                                                                         WeaponSystemName,
                                                                         GradeLevel ASC
                                                               --) AS mpa,
                                                               )
                   + crunch.GetChildTrainingWeaponsRecursive(
                                                                PayPlan,
                                                                CategorySubGroupCode,
                                                                GradeType,
                                                                coursetype,
                                                                WeaponSystemName,
                                                                GradeLevel,
                                                                'TrainingMPA'
                                                            ) AS mpa,
                   SUM(OMA_MOS / NULLIF(CGLA_MOS_inv, 0)) OVER (PARTITION BY PayPlan,
                                                                             CategorySubGroupCode,
                                                                             coursetype,
                                                                             WeaponSystemName
                                                                ORDER BY PayPlan,
                                                                         CategorySubGroupCode,
                                                                         coursetype,
                                                                         WeaponSystemName,
                                                                         GradeLevel ASC
                                                               --) AS oma,
                                                               )
                   + crunch.GetChildTrainingWeaponsRecursive(
                                                                PayPlan,
                                                                CategorySubGroupCode,
                                                                GradeType,
                                                                coursetype,
                                                                WeaponSystemName,
                                                                GradeLevel,
                                                                'TrainingOMA'
                                                            ) AS oma,
                   SUM(Other_MOS / NULLIF(CGLA_MOS_inv, 0)) OVER (PARTITION BY PayPlan,
                                                                               CategorySubGroupCode,
                                                                               coursetype,
                                                                               WeaponSystemName
                                                                  ORDER BY PayPlan,
                                                                           CategorySubGroupCode,
                                                                           coursetype,
                                                                           WeaponSystemName,
                                                                           GradeLevel ASC
                                                                 --) AS other
                                                                 )
                   + crunch.GetChildTrainingWeaponsRecursive(
                                                                PayPlan,
                                                                CategorySubGroupCode,
                                                                GradeType,
                                                                coursetype,
                                                                WeaponSystemName,
                                                                GradeLevel,
                                                                'TrainingOther'
                                                            ) AS other
            FROM crunch.TempTraining_Costs
            WHERE coursetype = 'W'
        ) AS b
            ON a.PayPlan = b.PayPlan
               AND a.CategorySubGroupCode = b.CategorySubGroupCode
               AND a.GradeLevel = b.GradeLevel
               AND a.WeaponSystemName = b.WeaponSystemName
               AND a.coursetype = b.coursetype;


    --execute the CGLA math to spread a costs at the SUBGROUP level without WPN system
    UPDATE crunch.TempTraining_Costs
    SET CGLA_MPA = a.CGLA_MPA + ISNULL(b.mpa, 0),
        CGLA_OMA = a.CGLA_OMA + ISNULL(b.oma, 0),
        CGLA_Other = a.CGLA_Other + ISNULL(b.other, 0)
    FROM crunch.TempTraining_Costs AS a
        INNER JOIN
        (
            SELECT *,
                   SUM(MPA_MOS / NULLIF(CGLA_MOS_inv, 0)) OVER (PARTITION BY PayPlan,
                                                                             CategorySubGroupCode,
                                                                             coursetype
                                                                ORDER BY PayPlan,
                                                                         CategorySubGroupCode,
                                                                         coursetype,
                                                                         GradeLevel ASC
                                                               --) AS mpa,
                                                               )
                   + crunch.GetChildTrainingRecursive(
                                                         PayPlan,
                                                         CategorySubGroupCode,
                                                         GradeType,
                                                         coursetype,
                                                         GradeLevel,
                                                         'TrainingMPA'
                                                     ) AS mpa,
                   SUM(OMA_MOS / NULLIF(CGLA_MOS_inv, 0)) OVER (PARTITION BY PayPlan,
                                                                             CategorySubGroupCode,
                                                                             coursetype
                                                                ORDER BY PayPlan,
                                                                         CategorySubGroupCode,
                                                                         coursetype,
                                                                         GradeLevel ASC
                                                               --) AS oma,
                                                               )
                   + crunch.GetChildTrainingRecursive(
                                                         PayPlan,
                                                         CategorySubGroupCode,
                                                         GradeType,
                                                         coursetype,
                                                         GradeLevel,
                                                         'TrainingOMA'
                                                     ) AS oma,
                   SUM(Other_MOS / NULLIF(CGLA_MOS_inv, 0)) OVER (PARTITION BY PayPlan,
                                                                               CategorySubGroupCode,
                                                                               coursetype
                                                                  ORDER BY PayPlan,
                                                                           CategorySubGroupCode,
                                                                           coursetype,
                                                                           GradeLevel ASC
                                                                 --) AS other
                                                                 )
                   + crunch.GetChildTrainingRecursive(
                                                         PayPlan,
                                                         CategorySubGroupCode,
                                                         GradeType,
                                                         coursetype,
                                                         GradeLevel,
                                                         'TrainingOther'
                                                     ) AS other
            FROM crunch.TempTraining_Costs
            WHERE coursetype <> 'W'
        ) AS b
            ON a.PayPlan = b.PayPlan
               AND a.CategorySubGroupCode = b.CategorySubGroupCode
               AND a.GradeLevel = b.GradeLevel
               AND a.coursetype = b.coursetype;


    --execute the CGLA math to spread a costs at the GROUP level with WPN System
    UPDATE crunch.TempTraining_Costs
    SET CGLA_MPA = a.CGLA_MPA + ISNULL(b.mpa, 0),
        CGLA_OMA = a.CGLA_OMA + ISNULL(b.oma, 0),
        CGLA_Other = a.CGLA_Other + ISNULL(b.other, 0)
    FROM crunch.TempTraining_Costs AS a
        INNER JOIN
        (
            SELECT *,
                   SUM(MPA_CMF / NULLIF(CGLA_CMF_Inv, 0)) OVER (PARTITION BY PayPlan,
                                                                             CategorySubGroupCode,
                                                                             coursetype,
                                                                             WeaponSystemName
                                                                ORDER BY PayPlan,
                                                                         CategorySubGroupCode,
                                                                         coursetype,
                                                                         WeaponSystemName,
                                                                         GradeLevel ASC
                                                               ) AS mpa,
                   SUM(OMA_CMF / NULLIF(CGLA_CMF_Inv, 0)) OVER (PARTITION BY PayPlan,
                                                                             CategorySubGroupCode,
                                                                             coursetype,
                                                                             WeaponSystemName
                                                                ORDER BY PayPlan,
                                                                         CategorySubGroupCode,
                                                                         coursetype,
                                                                         WeaponSystemName,
                                                                         GradeLevel ASC
                                                               ) AS oma,
                   SUM(Other_CMF / NULLIF(CGLA_CMF_Inv, 0)) OVER (PARTITION BY PayPlan,
                                                                               CategorySubGroupCode,
                                                                               coursetype,
                                                                               WeaponSystemName
                                                                  ORDER BY PayPlan,
                                                                           CategorySubGroupCode,
                                                                           coursetype,
                                                                           WeaponSystemName,
                                                                           GradeLevel ASC
                                                                 ) AS other
            FROM crunch.TempTraining_Costs
            WHERE coursetype = 'W'
        ) AS b
            ON a.PayPlan = b.PayPlan
               AND a.CategorySubGroupCode = b.CategorySubGroupCode
               AND a.GradeLevel = b.GradeLevel
               AND a.WeaponSystemName = b.WeaponSystemName
               AND a.coursetype = b.coursetype;


    --execute the CGLA math to spread a costs at the GROUP level without WPN System
    UPDATE crunch.TempTraining_Costs
    SET CGLA_MPA = a.CGLA_MPA + ISNULL(b.mpa, 0),
        CGLA_OMA = a.CGLA_OMA + ISNULL(b.oma, 0),
        CGLA_Other = a.CGLA_Other + ISNULL(b.other, 0)
    FROM crunch.TempTraining_Costs AS a
        INNER JOIN
        (
            SELECT *,
                   SUM(MPA_CMF / NULLIF(CGLA_CMF_Inv, 0)) OVER (PARTITION BY PayPlan,
                                                                             CategorySubGroupCode,
                                                                             coursetype
                                                                ORDER BY PayPlan,
                                                                         CategorySubGroupCode,
                                                                         coursetype,
                                                                         GradeLevel ASC
                                                               ) AS mpa,
                   SUM(OMA_CMF / NULLIF(CGLA_CMF_Inv, 0)) OVER (PARTITION BY PayPlan,
                                                                             CategorySubGroupCode,
                                                                             coursetype
                                                                ORDER BY PayPlan,
                                                                         CategorySubGroupCode,
                                                                         coursetype,
                                                                         GradeLevel ASC
                                                               ) AS oma,
                   SUM(Other_CMF / NULLIF(CGLA_CMF_Inv, 0)) OVER (PARTITION BY PayPlan,
                                                                               CategorySubGroupCode,
                                                                               coursetype
                                                                  ORDER BY PayPlan,
                                                                           CategorySubGroupCode,
                                                                           coursetype,
                                                                           GradeLevel ASC
                                                                 ) AS other
            FROM crunch.TempTraining_Costs
            WHERE coursetype <> 'W'
        ) AS b
            ON a.PayPlan = b.PayPlan
               AND a.CategorySubGroupCode = b.CategorySubGroupCode
               AND a.GradeLevel = b.GradeLevel
               AND a.coursetype = b.coursetype;



    --execute the CGLA math to spread a costs at the PayPlan level with wpn system
    UPDATE crunch.TempTraining_Costs
    SET CGLA_MPA = a.CGLA_MPA + ISNULL(b.mpa, 0),
        CGLA_OMA = a.CGLA_OMA + ISNULL(b.oma, 0),
        CGLA_Other = a.CGLA_Other + ISNULL(b.other, 0)
    FROM crunch.TempTraining_Costs AS a
        INNER JOIN
        (
            SELECT *,
                   SUM(MPA_PP / NULLIF(CGLA_PP_inv, 0)) OVER (PARTITION BY PayPlan,
                                                                           CategorySubGroupCode,
                                                                           coursetype,
                                                                           WeaponSystemName
                                                              ORDER BY PayPlan,
                                                                       CategorySubGroupCode,
                                                                       coursetype,
                                                                       WeaponSystemName,
                                                                       GradeLevel ASC
                                                             ) AS mpa,
                   SUM(OMA_PP / NULLIF(CGLA_PP_inv, 0)) OVER (PARTITION BY PayPlan,
                                                                           CategorySubGroupCode,
                                                                           coursetype,
                                                                           WeaponSystemName
                                                              ORDER BY PayPlan,
                                                                       CategorySubGroupCode,
                                                                       coursetype,
                                                                       WeaponSystemName,
                                                                       GradeLevel ASC
                                                             ) AS oma,
                   SUM(other_PP / NULLIF(CGLA_PP_inv, 0)) OVER (PARTITION BY PayPlan,
                                                                             CategorySubGroupCode,
                                                                             coursetype,
                                                                             WeaponSystemName
                                                                ORDER BY PayPlan,
                                                                         CategorySubGroupCode,
                                                                         coursetype,
                                                                         WeaponSystemName,
                                                                         GradeLevel ASC
                                                               ) AS other
            FROM crunch.TempTraining_Costs
            WHERE coursetype = 'W'
        ) AS b
            ON a.PayPlan = b.PayPlan
               AND a.CategorySubGroupCode = b.CategorySubGroupCode
               AND a.GradeLevel = b.GradeLevel
               AND a.WeaponSystemName = b.WeaponSystemName
               AND a.coursetype = b.coursetype;


    --execute the CGLA math to spread a costs at the PayPlan level without wpn system
    UPDATE crunch.TempTraining_Costs
    SET CGLA_MPA = a.CGLA_MPA + ISNULL(b.mpa, 0),
        CGLA_OMA = a.CGLA_OMA + ISNULL(b.oma, 0),
        CGLA_Other = a.CGLA_Other + ISNULL(b.other, 0)
    FROM crunch.TempTraining_Costs AS a
        INNER JOIN
        (
            SELECT *,
                   SUM(MPA_PP / NULLIF(CGLA_PP_inv, 0)) OVER (PARTITION BY PayPlan,
                                                                           CategorySubGroupCode,
                                                                           coursetype
                                                              ORDER BY PayPlan,
                                                                       CategorySubGroupCode,
                                                                       coursetype,
                                                                       GradeLevel ASC
                                                             ) AS mpa,
                   SUM(OMA_PP / NULLIF(CGLA_PP_inv, 0)) OVER (PARTITION BY PayPlan,
                                                                           CategorySubGroupCode,
                                                                           coursetype
                                                              ORDER BY PayPlan,
                                                                       CategorySubGroupCode,
                                                                       coursetype,
                                                                       GradeLevel ASC
                                                             ) AS oma,
                   SUM(other_PP / NULLIF(CGLA_PP_inv, 0)) OVER (PARTITION BY PayPlan,
                                                                             CategorySubGroupCode,
                                                                             coursetype
                                                                ORDER BY PayPlan,
                                                                         CategorySubGroupCode,
                                                                         coursetype,
                                                                         GradeLevel ASC
                                                               ) AS other
            FROM crunch.TempTraining_Costs
            WHERE coursetype <> 'W'
        ) AS b
            ON a.PayPlan = b.PayPlan
               AND a.CategorySubGroupCode = b.CategorySubGroupCode
               AND a.GradeLevel = b.GradeLevel
               AND a.coursetype = b.coursetype;

    --assign the unallocated training costs to the G coursetype in a Payplan Average (PPA) way but only to the active component, the reserves have their own budget process for G costs
    UPDATE crunch.TempTraining_Costs
    SET CGLA_OMA = CGLA_OMA + @unallocated_budget_per_soldier
    WHERE coursetype = 'G'
          AND PayPlan IN ( 'AO', 'AE', 'AWO' );


    -- =============================================
    --Bring in Army Reserve and National Guard Specific costs
    -- =============================================
    DECLARE @AR_All AS FLOAT;
    DECLARE @NG_All AS FLOAT;
    DECLARE @AR_E AS FLOAT;
    DECLARE @NG_E AS FLOAT;
    SET @AR_All =
    (
        SELECT SUM(Inventory)
        FROM data.Inventory
        WHERE PayPlan IN ( 'RO', 'RWO', 'RE' )
    );
    SET @NG_All =
    (
        SELECT SUM(Inventory)
        FROM data.Inventory
        WHERE PayPlan IN ( 'NO', 'NWO', 'NE' )
    );
    SET @AR_E =
    (
        SELECT SUM(Inventory) FROM data.Inventory WHERE PayPlan IN ( 'RE' )
    );
    SET @NG_E =
    (
        SELECT SUM(Inventory) FROM data.Inventory WHERE PayPlan IN ( 'NE' )
    );

    DECLARE @IET_RPA AS FLOAT,
            @IET_NGPA AS FLOAT,
            @IET_OMAR AS FLOAT,
            @IET_OMNG AS FLOAT,
            @IET_RPA_soldier AS FLOAT,
            @IET_NGPA_soldier AS FLOAT,
            @IET_OMAR_soldier AS FLOAT,
            @IET_OMNG_soldier AS FLOAT,
            @AIT_RPA AS FLOAT,
            @AIT_NGPA AS FLOAT,
            @AIT_OMAR AS FLOAT,
            @AIT_OMNG AS FLOAT,
            @AIT_RPA_soldier AS FLOAT,
            @AIT_NGPA_soldier AS FLOAT,
            @AIT_OMAR_soldier AS FLOAT,
            @AIT_OMNG_soldier AS FLOAT,
            @MOS_Qual_RPA AS FLOAT,
            @MOS_Qual_NGPA AS FLOAT,
            @MOS_Qual_OMAR AS FLOAT,
            @MOS_Qual_OMNG AS FLOAT,
            @MOS_Qual_RPA_soldier AS FLOAT,
            @MOS_Qual_NGPA_soldier AS FLOAT,
            @MOS_Qual_OMAR_soldier AS FLOAT,
            @MOS_Qual_OMNG_soldier AS FLOAT,
            @G_RPA AS FLOAT,
            @G_NGPA AS FLOAT,
            @G_OMAR AS FLOAT,
            @G_OMNG AS FLOAT,
            @G_RPA_soldier AS FLOAT,
            @G_NGPA_soldier AS FLOAT,
            @G_OMAR_soldier AS FLOAT,
            @G_OMNG_soldier AS FLOAT,
            @P_RPA AS FLOAT,
            @P_NGPA AS FLOAT,
            @P_OMAR AS FLOAT,
            @P_OMNG AS FLOAT,
            @P_RPA_soldier AS FLOAT,
            @P_NGPA_soldier AS FLOAT,
            @P_OMAR_soldier AS FLOAT,
            @P_OMNG_soldier AS FLOAT;


    --According to the 2018 NGPA book IET is for " non-prior service enlisted Soldiers attending IET"
    SET @IET_RPA =
    (
        SELECT Amount
        FROM crunch.TempArmyBudgetSingleValues
        WHERE Appropriation = 'RPA'
              AND ParameterName = 'Training-IET'
    );
    SET @IET_OMAR =
    (
        SELECT Amount
        FROM crunch.TempArmyBudgetSingleValues
        WHERE Appropriation = 'OMAR'
              AND ParameterName = 'Training-IET'
    );
    SET @IET_NGPA =
    (
        SELECT Amount
        FROM crunch.TempArmyBudgetSingleValues
        WHERE Appropriation = 'NGPA'
              AND ParameterName = 'Training-IET'
    );
    SET @IET_OMNG =
    (
        SELECT Amount
        FROM crunch.TempArmyBudgetSingleValues
        WHERE Appropriation = 'OMNG'
              AND ParameterName = 'Training-IET'
    );

    SET @IET_RPA_soldier = @IET_RPA / @AR_E;
    SET @IET_OMAR_soldier = @IET_OMAR / @AR_E;
    SET @IET_NGPA_soldier = @IET_NGPA / @NG_E;
    SET @IET_OMNG_soldier = @IET_OMNG / @AR_E;

    UPDATE crunch.TempTraining_Costs
    SET RPA_NGPA = @IET_RPA_soldier,
        OMAR_OMNG = @IET_OMAR_soldier
    WHERE coursetype = 'IET'
          AND PayPlan IN ( 'RE' );
    UPDATE crunch.TempTraining_Costs
    SET RPA_NGPA = @IET_NGPA_soldier,
        OMAR_OMNG = @IET_OMNG_soldier
    WHERE coursetype = 'IET'
          AND PayPlan IN ( 'NE' );

    IF @Debug = 1
    BEGIN
        SELECT CONCAT('IET RPA Budget ', FORMAT(@IET_RPA, 'C', 'en-us'));
        SELECT CONCAT('IET RPA per soldier', FORMAT(@IET_RPA_soldier, 'C', 'en-us'));
        SELECT CONCAT('IET OMAR Budget', FORMAT(@IET_OMAR, 'C', 'en-us'));
        SELECT CONCAT('IET OMAR per soldier', FORMAT(@IET_OMAR_soldier, 'C', 'en-us'));
        SELECT CONCAT('IET NGPA Budget', FORMAT(@IET_NGPA, 'C', 'en-us'));
        SELECT CONCAT('IET NGPA per soldier', FORMAT(@IET_NGPA_soldier, 'C', 'en-us'));
        SELECT CONCAT('IET OMNG Budget', FORMAT(@IET_OMNG, 'C', 'en-us'));
        SELECT CONCAT('IET OMNG per soldier', FORMAT(@IET_OMNG_soldier, 'C', 'en-us'));
    END;

    --According to the 2018 NGPA book initial skills is for all soldiers, however we reclassify O/WO costs as IET since IET is for officers
    SET @AIT_RPA =
    (
        SELECT Amount
        FROM crunch.TempArmyBudgetSingleValues
        WHERE Appropriation = 'RPA'
              AND ParameterName = 'Training-Initial SKills'
    );
    SET @AIT_OMAR =
    (
        SELECT Amount
        FROM crunch.TempArmyBudgetSingleValues
        WHERE Appropriation = 'OMAR'
              AND ParameterName = 'Training-Initial SKills'
    );
    SET @AIT_NGPA =
    (
        SELECT Amount
        FROM crunch.TempArmyBudgetSingleValues
        WHERE Appropriation = 'NGPA'
              AND ParameterName = 'Training-Initial SKills'
    );
    SET @AIT_OMNG =
    (
        SELECT Amount
        FROM crunch.TempArmyBudgetSingleValues
        WHERE Appropriation = 'OMNG'
              AND ParameterName = 'Training-Initial SKills'
    );

    SET @AIT_RPA_soldier = @AIT_RPA / @AR_All;
    SET @AIT_OMAR_soldier = @AIT_OMAR / @AR_All;
    SET @AIT_NGPA_soldier = @AIT_NGPA / @NG_All;
    SET @AIT_OMNG_soldier = @AIT_OMNG / @AR_All;

    UPDATE crunch.TempTraining_Costs
    SET RPA_NGPA = @AIT_RPA_soldier,
        OMAR_OMNG = @AIT_OMAR_soldier
    WHERE coursetype = 'AIT'
          AND PayPlan IN ( 'RE' );
    UPDATE crunch.TempTraining_Costs
    SET RPA_NGPA = @AIT_NGPA_soldier,
        OMAR_OMNG = @AIT_OMNG_soldier
    WHERE coursetype = 'AIT'
          AND PayPlan IN ( 'NE' );
    --reclass O/W costs to IET
    UPDATE crunch.TempTraining_Costs
    SET RPA_NGPA = RPA_NGPA + @AIT_RPA_soldier,
        OMAR_OMNG = OMAR_OMNG + @AIT_OMAR_soldier
    WHERE coursetype = 'IET'
          AND PayPlan IN ( 'RO', 'RWO' );
    UPDATE crunch.TempTraining_Costs
    SET RPA_NGPA = RPA_NGPA + @AIT_NGPA_soldier,
        OMAR_OMNG = OMAR_OMNG + @AIT_OMNG_soldier
    WHERE coursetype = 'IET'
          AND PayPlan IN ( 'NO', 'NWO' );


    IF @Debug = 1
    BEGIN
        SELECT CONCAT('AIT/IET RPA Budget ', FORMAT(@AIT_RPA, 'C', 'en-us'));
        SELECT CONCAT('AIT/IET RPA per soldier', FORMAT(@AIT_RPA_soldier, 'C', 'en-us'));
        SELECT CONCAT('AIT/IET OMAR Budget', FORMAT(@AIT_OMAR, 'C', 'en-us'));
        SELECT CONCAT('AIT/IET OMAR per soldier', FORMAT(@AIT_OMAR_soldier, 'C', 'en-us'));
        SELECT CONCAT('AIT/IET NGPA Budget', FORMAT(@AIT_NGPA, 'C', 'en-us'));
        SELECT CONCAT('AIT/IET NGPA per soldier', FORMAT(@AIT_NGPA_soldier, 'C', 'en-us'));
        SELECT CONCAT('AIT/IET OMNG Budget', FORMAT(@AIT_OMNG, 'C', 'en-us'));
        SELECT CONCAT('AIT/IET OMNG per soldier', FORMAT(@AIT_OMNG_soldier, 'C', 'en-us'));
    END;


    --MOS qual course is AIT for enlisted only
    SET @MOS_Qual_RPA =
    (
        SELECT Amount
        FROM crunch.TempArmyBudgetSingleValues
        WHERE Appropriation = 'RPA'
              AND ParameterName = 'Training-MOS Qualification'
    );
    SET @MOS_Qual_OMAR =
    (
        SELECT Amount
        FROM crunch.TempArmyBudgetSingleValues
        WHERE Appropriation = 'OMAR'
              AND ParameterName = 'Training-MOS Qualification'
    );
    SET @MOS_Qual_NGPA =
    (
        SELECT Amount
        FROM crunch.TempArmyBudgetSingleValues
        WHERE Appropriation = 'NGPA'
              AND ParameterName = 'Training-MOS Qualification'
    );
    SET @MOS_Qual_OMNG =
    (
        SELECT Amount
        FROM crunch.TempArmyBudgetSingleValues
        WHERE Appropriation = 'OMNG'
              AND ParameterName = 'Training-MOS Qualification'
    );

    SET @MOS_Qual_RPA_soldier = @MOS_Qual_RPA / @AR_E;
    SET @MOS_Qual_OMAR_soldier = @MOS_Qual_OMAR / @AR_E;
    SET @MOS_Qual_NGPA_soldier = @MOS_Qual_NGPA / @NG_E;
    SET @MOS_Qual_OMNG_soldier = @MOS_Qual_OMNG / @AR_E;

    UPDATE crunch.TempTraining_Costs
    SET RPA_NGPA = RPA_NGPA + @MOS_Qual_RPA_soldier,
        OMAR_OMNG = OMAR_OMNG + @MOS_Qual_OMAR_soldier
    WHERE coursetype = 'AIT'
          AND PayPlan IN ( 'RE' );
    UPDATE crunch.TempTraining_Costs
    SET RPA_NGPA = RPA_NGPA + @MOS_Qual_NGPA_soldier,
        OMAR_OMNG = OMAR_OMNG + @MOS_Qual_OMNG_soldier
    WHERE coursetype = 'AIT'
          AND PayPlan IN ( 'NE' );



    IF @Debug = 1
    BEGIN
        SELECT CONCAT('MOS_Qual/IET RPA Budget ', FORMAT(@MOS_Qual_RPA, 'C', 'en-us'));
        SELECT CONCAT('MOS_Qual/IET RPA per soldier', FORMAT(@MOS_Qual_RPA_soldier, 'C', 'en-us'));
        SELECT CONCAT('MOS_Qual/IET OMAR Budget', FORMAT(@MOS_Qual_OMAR, 'C', 'en-us'));
        SELECT CONCAT('MOS_Qual/IET OMAR per soldier', FORMAT(@MOS_Qual_OMAR_soldier, 'C', 'en-us'));
        SELECT CONCAT('MOS_Qual/IET NGPA Budget', FORMAT(@MOS_Qual_NGPA, 'C', 'en-us'));
        SELECT CONCAT('MOS_Qual/IET NGPA per soldier', FORMAT(@MOS_Qual_NGPA_soldier, 'C', 'en-us'));
        SELECT CONCAT('MOS_Qual/IET OMNG Budget', FORMAT(@MOS_Qual_OMNG, 'C', 'en-us'));
        SELECT CONCAT('MOS_Qual/IET OMNG per soldier', FORMAT(@MOS_Qual_OMNG_soldier, 'C', 'en-us'));
    END;



    --according to the 2018 NGPA book prof educaiton (under career dev training) is for all soldiers
    SET @P_RPA =
    (
        SELECT Amount
        FROM crunch.TempArmyBudgetSingleValues
        WHERE Appropriation = 'RPA'
              AND ParameterName = 'Training-Professional'
    );
    SET @P_OMAR =
    (
        SELECT Amount
        FROM crunch.TempArmyBudgetSingleValues
        WHERE Appropriation = 'OMAR'
              AND ParameterName = 'Training-Professional'
    );
    SET @P_NGPA =
    (
        SELECT Amount
        FROM crunch.TempArmyBudgetSingleValues
        WHERE Appropriation = 'NGPA'
              AND ParameterName = 'Training-Professional'
    );
    SET @P_OMNG =
    (
        SELECT Amount
        FROM crunch.TempArmyBudgetSingleValues
        WHERE Appropriation = 'OMNG'
              AND ParameterName = 'Training-Professional'
    );

    SET @P_RPA_soldier = @P_RPA / @AR_All;
    SET @P_OMAR_soldier = @P_OMAR / @AR_All;
    SET @P_NGPA_soldier = @P_NGPA / @NG_All;
    SET @P_OMNG_soldier = @P_OMNG / @AR_All;

    UPDATE crunch.TempTraining_Costs
    SET RPA_NGPA = @P_RPA_soldier,
        OMAR_OMNG = @P_OMAR_soldier
    WHERE coursetype = 'P'
          AND PayPlan IN ( 'RE', 'RO', 'RWO' );
    UPDATE crunch.TempTraining_Costs
    SET RPA_NGPA = @P_NGPA_soldier,
        OMAR_OMNG = @P_OMNG_soldier
    WHERE coursetype = 'P'
          AND PayPlan IN ( 'NE', 'NO', 'NWO' );

    IF @Debug = 1
    BEGIN
        SELECT CONCAT('P RPA Budget ', FORMAT(@P_RPA, 'C', 'en-us'));
        SELECT CONCAT('P RPA per soldier', FORMAT(@P_RPA_soldier, 'C', 'en-us'));
        SELECT CONCAT('P OMAR Budget', FORMAT(@P_OMAR, 'C', 'en-us'));
        SELECT CONCAT('P OMAR per soldier', FORMAT(@P_OMAR_soldier, 'C', 'en-us'));
        SELECT CONCAT('P NGPA Budget', FORMAT(@P_NGPA, 'C', 'en-us'));
        SELECT CONCAT('P NGPA per soldier', FORMAT(@P_NGPA_soldier, 'C', 'en-us'));
        SELECT CONCAT('P OMNG Budget', FORMAT(@P_OMNG, 'C', 'en-us'));
        SELECT CONCAT('P OMNG per soldier', FORMAT(@P_OMNG_soldier, 'C', 'en-us'));
    END;

    --the balance is going to go into a General trainnig bucket
    SET @G_RPA =
    (
        SELECT SUM(Amount)
        FROM crunch.TempArmyBudgetSingleValues
        WHERE Appropriation = 'RPA'
              AND ParameterName IN ( 'Training-Support', 'Training-Special Skills Training' )
    );
    SET @G_OMAR =
    (
        SELECT SUM(Amount)
        FROM crunch.TempArmyBudgetSingleValues
        WHERE Appropriation = 'OMAR'
              AND ParameterName IN ( 'Training-Support', 'Training-Special Skills Training' )
    );
    SET @G_NGPA =
    (
        SELECT SUM(Amount)
        FROM crunch.TempArmyBudgetSingleValues
        WHERE Appropriation = 'NGPA'
              AND ParameterName IN ( 'Training-Support', 'Training-Special Skills Training' )
    );
    SET @G_OMNG =
    (
        SELECT SUM(Amount)
        FROM crunch.TempArmyBudgetSingleValues
        WHERE Appropriation = 'OMNG '
              AND ParameterName IN ( 'Training-Support', 'Training-Special Skills Training' )
    );

    SET @G_RPA_soldier = @G_RPA / @AR_All;
    SET @G_OMAR_soldier = @G_OMAR / @AR_All;
    SET @G_NGPA_soldier = @G_NGPA / @NG_All;
    SET @G_OMNG_soldier = @G_OMNG / @AR_All;

    UPDATE crunch.TempTraining_Costs
    SET RPA_NGPA = @G_RPA_soldier,
        OMAR_OMNG = @G_OMAR_soldier
    WHERE coursetype = 'G'
          AND PayPlan IN ( 'RE', 'RO', 'RWO' );
    UPDATE crunch.TempTraining_Costs
    SET RPA_NGPA = @G_NGPA_soldier,
        OMAR_OMNG = @G_OMNG_soldier
    WHERE coursetype = 'G'
          AND PayPlan IN ( 'NE', 'NO', 'NWO' );

    IF @Debug = 1
    BEGIN
        SELECT CONCAT('P RPA Budget ', FORMAT(@G_RPA, 'C', 'en-us'));
        SELECT CONCAT('P RPA per soldier', FORMAT(@G_RPA_soldier, 'C', 'en-us'));
        SELECT CONCAT('P OMAR Budget', FORMAT(@G_OMAR, 'C', 'en-us'));
        SELECT CONCAT('P OMAR per soldier', FORMAT(@G_OMAR_soldier, 'C', 'en-us'));
        SELECT CONCAT('P NGPA Budget', FORMAT(@G_NGPA, 'C', 'en-us'));
        SELECT CONCAT('P NGPA per soldier', FORMAT(@G_NGPA_soldier, 'C', 'en-us'));
        SELECT CONCAT('P OMNG Budget', FORMAT(@G_OMNG, 'C', 'en-us'));
        SELECT CONCAT('P OMNG per soldier', FORMAT(@G_OMNG_soldier, 'C', 'en-us'));
    END;

    --finally we remove all the zero costs so we have a nice concise table in the end
    DELETE FROM crunch.TempTraining_Costs
    WHERE CGLA_MPA = 0
          AND CGLA_OMA = 0
          AND CGLA_Other = 0
          AND RPA_NGPA = 0
          AND OMAR_OMNG = 0;

    IF @Debug = 1
    BEGIN
        SELECT 'the final table before we bring in inventory';
        SELECT ATRRS_Num_students,
               ATRRS_CrsType,
               ATRRS_Branch,
               ATRRS_MOS,
               ATRRS_GradeLevel,
               ATRRS_Crs_Title,
               ATRRS_School,
               ATRRS_Component,
               ATRRS_Crs_Num,
               ATRRS_Sch_Code,
               ATRRS_Version_id,
               AmcosVersionId,
               ATRRS_Key,
               ATRM_Key,
               ATRM_Version_id,
               ATRM_Sch_Code,
               ATRM_Crs_Num,
               ATRM_Crs_Title,
               ATRM_Location,
               ATRM_Activity,
               ATRM_Length_wks,
               ATRM_EGRADS,
               ATRM_Modal_Grade,
               ATRM_Frequency,
               ATRM_Flying_Hrs,
               ATRM_TMW_EGRD,
               ATRM_MPA,
               ATRM_OMA,
               ATRM_Other,
               Exception,
               Crs_Type_O,
               Crs_Type_E,
               WeaponSystemName,
               AOC,
               WOMOS,
               MOS,
               O_GradeLevel_Floor,
               O_GradeLevel_Ceiling,
               W_GradeLevel_Floor,
               W_GradeLevel_Ceiling,
               E_GradeLevel_Floor,
               E_GradeLevel_Ceiling,
               final_crs_type,
               final_MOS,
               final_Branch,
               final_Grade,
               final_GradeType,
               final_GradeLevel,
               payplan,
               atrrs_tot_students,
               adj_students,
               running_adj_students,
               inventory,
               inv_add,
               total_inv_add,
               final_adj_inv,
               final_adj_students
        FROM crunch.TempATRRS_ATRM_Crs_MOS
        --WHERE final_MOS=@MOS AND payplan=@payplan
        ORDER BY final_MOS,
                 final_Grade,
                 ATRRS_Crs_Title;

        SELECT 'crunch.TempATRRS_ATRM_Crs_MOS now with inventory and costs';
        SELECT ATRRS_Num_students,
               ATRRS_CrsType,
               ATRRS_Branch,
               ATRRS_MOS,
               ATRRS_GradeLevel,
               ATRRS_Crs_Title,
               ATRRS_School,
               ATRRS_Component,
               ATRRS_Crs_Num,
               ATRRS_Sch_Code,
               ATRRS_Version_id,
               AmcosVersionId,
               ATRRS_Key,
               ATRM_Key,
               ATRM_Version_id,
               ATRM_Sch_Code,
               ATRM_Crs_Num,
               ATRM_Crs_Title,
               ATRM_Location,
               ATRM_Activity,
               ATRM_Length_wks,
               ATRM_EGRADS,
               ATRM_Modal_Grade,
               ATRM_Frequency,
               ATRM_Flying_Hrs,
               ATRM_TMW_EGRD,
               ATRM_MPA,
               ATRM_OMA,
               ATRM_Other,
               Exception,
               Crs_Type_O,
               Crs_Type_E,
               WeaponSystemName,
               AOC,
               WOMOS,
               MOS,
               O_GradeLevel_Floor,
               O_GradeLevel_Ceiling,
               W_GradeLevel_Floor,
               W_GradeLevel_Ceiling,
               E_GradeLevel_Floor,
               E_GradeLevel_Ceiling,
               final_crs_type,
               final_MOS,
               final_Branch,
               final_Grade,
               final_GradeType,
               final_GradeLevel,
               payplan,
               atrrs_tot_students,
               adj_students,
               running_adj_students,
               inventory,
               inv_add,
               total_inv_add,
               final_adj_inv,
               final_adj_students
        FROM crunch.TempATRRS_ATRM_Crs_MOS
        --WHERE payplan=@payplan --AND final_MOS=@MOS
        ORDER BY final_MOS,
                 final_Grade,
                 ATRRS_Crs_Title,
                 AmcosVersionId;

        SELECT 'crunch.TempTraining_Costs table';
        SELECT WeaponSystemName,
               coursetype,
               PayPlan,
               CategoryGroupCode,
               CategorySubGroupCode,
               GradeType,
               GradeLevel,
               inventory,
               MPA_MOS,
               OMA_MOS,
               Other_MOS,
               MPA_CMF,
               OMA_CMF,
               Other_CMF,
               MPA_PP,
               OMA_PP,
               other_PP,
               CGLA_MOS_inv,
               CGLA_CMF_Inv,
               CGLA_PP_inv,
               CGLA_MPA,
               CGLA_OMA,
               CGLA_Other,
               RPA_NGPA,
               OMAR_OMNG,
               WeaponSystemId
        FROM crunch.TempTraining_Costs;
        --wHERE PayPlan=@payplan AND CategorySubGroupCode=@MOS


        SELECT 'TempTraining_Costs_sum table';
        SELECT AmcosVersionId,
               ATRM_Key,
               ATRRS_Key,
               ATRM_Crs_Title,
               ATRM_Location,
               atrm_mpa,
               atrm_oma,
               atrm_other,
               inventory,
               payplan,
               final_MOS,
               final_crs_type,
               WeaponSystemName,
               final_GradeType,
               final_GradeLevel,
               adj_students,
               MPA_Total_Cost,
               OMA_Total_Cost,
               Other_Total_cost
        FROM crunch.TempTraining_Costs_by_version;
        --WHERE  payplan=@payplan AND final_MOS=@MOS 

        SELECT 'crunch.TempTraining_Costs_avg table';
        SELECT WeaponSystemName,
               final_crs_type,
               final_MOS,
               final_GradeType,
               final_GradeLevel,
               payplan,
               inv,
               mpa_total_avg_cost,
               oma_total_avg_cost,
               other_total_avg_cost,
               MPA_adj,
               OMA_adj,
               Other_adj
        FROM crunch.TempTraining_Costs_avg
        --WHERE  payplan=@payplan AND final_MOS=@MOS 
        ORDER BY final_MOS,
                 final_GradeLevel,
                 payplan;
        SELECT 'the final crunch.TempTraining_Costs now with all training costs by amount';
        SELECT WeaponSystemName,
               coursetype,
               PayPlan,
               CategoryGroupCode,
               CategorySubGroupCode,
               GradeType,
               GradeLevel,
               inventory,
               MPA_MOS,
               OMA_MOS,
               Other_MOS,
               MPA_CMF,
               OMA_CMF,
               Other_CMF,
               MPA_PP,
               OMA_PP,
               other_PP,
               CGLA_MOS_inv,
               CGLA_CMF_Inv,
               CGLA_PP_inv,
               CGLA_MPA,
               CGLA_OMA,
               CGLA_Other,
               RPA_NGPA,
               OMAR_OMNG,
               WeaponSystemId
        FROM crunch.TempTraining_Costs
        --WHERE
        -- ISNULL((CGLA_MPA+CGLA_oma+CGLA_other),0)>0 
        --and
        -- payplan=@payplan AND CategorySubGroupCode=@MOS 
        ORDER BY (CGLA_MPA + CGLA_OMA + CGLA_Other) DESC;

        SELECT 'the final crunch.TempTraining_Costs now with all training costs by order';
        SELECT WeaponSystemName,
               coursetype,
               PayPlan,
               CategoryGroupCode,
               CategorySubGroupCode,
               GradeType,
               GradeLevel,
               inventory,
               MPA_MOS,
               OMA_MOS,
               Other_MOS,
               MPA_CMF,
               OMA_CMF,
               Other_CMF,
               MPA_PP,
               OMA_PP,
               other_PP,
               CGLA_MOS_inv,
               CGLA_CMF_Inv,
               CGLA_PP_inv,
               CGLA_MPA,
               CGLA_OMA,
               CGLA_Other,
               RPA_NGPA,
               OMAR_OMNG,
               WeaponSystemId
        FROM crunch.TempTraining_Costs
        --WHERE 
        --ISNULL((CGLA_MPA+CGLA_oma+CGLA_other),0)>0 
        --AND 
        --payplan=@payplan AND  CategorySubGroupCode=@MOS
        ORDER BY CategorySubGroupCode,
                 GradeLevel,
                 coursetype;

        SELECT 'Check the following table for minimum costs by course type that make sense and are comparable across payplans';
        SELECT PayPlan,
               coursetype,
               MIN(NULLIF(CGLA_MPA, 0)) AS mpa,
               (MIN(NULLIF(CGLA_OMA, 0)) + MIN(NULLIF(CGLA_Other, 0))) AS OMA_Other,
               MIN(NULLIF(RPA_NGPA, 0)) AS RPA_NGPA,
               MIN(NULLIF(OMAR_OMNG, 0)) AS omar_omng
        FROM crunch.TempTraining_Costs
        GROUP BY PayPlan,
                 coursetype;

        SELECT 'Check the following table for minimum costs by payplan that make sense and are comparable across payplans';
        SELECT PayPlan,
               SUM(mpa) AS mpa,
               (SUM(cgla_oma) + SUM(cgla_other)) AS OMA_Other,
               SUM(RPA_NGPA) AS RPA_NGPA,
               SUM(omar_omng) AS omar_omng
        FROM
        (
            SELECT PayPlan,
                   coursetype,
                   MIN(NULLIF(CGLA_MPA, 0)) AS mpa,
                   MIN(NULLIF(CGLA_OMA, 0)) AS cgla_oma,
                   MIN(NULLIF(CGLA_Other, 0)) AS cgla_other,
                   MIN(NULLIF(RPA_NGPA, 0)) AS RPA_NGPA,
                   MIN(NULLIF(OMAR_OMNG, 0)) AS omar_omng
            FROM crunch.TempTraining_Costs
            GROUP BY PayPlan,
                     coursetype
        ) AS a
        GROUP BY PayPlan;

    END;

    IF @Debug = 0
    BEGIN
        -- clear out the existing cost table for all the CE IDs we are about to insert values for
        --AE/AO/AWO: MPA, OMA, OMA_1 for actual and avg costs
        DELETE FROM crunch.Costs_AE
        WHERE CostElementId IN ( 56, 58, 60, 62, 65, 91, 93, 95, 97, 100, 110, 112, 114, 116, 119, 3379, 3381, 3383,
                                 3385, 3387, 3389, 3957, 3958, 3959, 3960, 3961, 3962, 3983, 4022, 4041, 4044, 4059,
                                 4068, 4085, 4086, 4109, 4112, 4127, 4136, 4202, 4203
                               );
        DELETE FROM crunch.Costs_AO
        WHERE CostElementId IN ( 163, 165, 167, 184, 186, 188, 194, 196, 198, 649, 650, 651, 670, 671, 672, 3391, 3393,
                                 3395, 3397, 3399, 3401, 3969, 3977, 3986, 3994, 4006, 4008, 4016, 4021, 4045, 4053,
                                 4062, 4071, 4083, 4087, 4113, 4121, 4130, 4139, 4151, 4153
                               );
        DELETE FROM crunch.Costs_AWO
        WHERE CostElementId IN ( 237, 239, 241, 252, 254, 256, 265, 267, 269, 686, 687, 688, 692, 693, 694, 3403, 3405,
                                 3407, 3409, 3411, 3413, 3970, 3978, 3987, 3995, 4007, 4009, 4017, 4023, 4046, 4054,
                                 4063, 4072, 4084, 4088, 4114, 4122, 4131, 4140, 4152, 4154
                               );
        --NG/R: Have additional APPNsMPA, OMA, OMA_1 for actual and avg costs
        DELETE FROM crunch.Costs_NE
        WHERE CostElementId IN ( 309, 313, 318, 322, 347, 352, 3415, 3417, 3419, 3421, 3423, 3425, 3967, 3971, 3984,
                                 3993, 4004, 4010, 4019, 4028, 4033, 4034, 4037, 4039, 4042, 4047, 4060, 4070, 4081,
                                 4092, 4095, 4097, 4098, 4100, 4103, 4105, 4108, 4110, 4115, 4128, 4138, 4149, 4158,
                                 4162, 4168, 4173, 4176, 4177, 4183
                               );
        DELETE FROM crunch.Costs_NO
        WHERE CostElementId IN ( 369, 371, 373, 378, 380, 382, 400, 404, 406, 3029, 3031, 3033, 3035, 3037, 3039, 3427,
                                 3429, 3431, 3433, 3471, 3472, 3972, 3979, 3990, 3996, 4000, 4011, 4018, 4027, 4048,
                                 4057, 4066, 4075, 4077, 4093, 4116, 4125, 4134, 4143, 4145, 4159, 4161, 4167, 4178,
                                 4184, 4208, 4210
                               );
        DELETE FROM crunch.Costs_NWO
        WHERE CostElementId IN ( 420, 422, 424, 429, 431, 433, 440, 444, 446, 3041, 3043, 3045, 3047, 3049, 3051, 3435,
                                 3437, 3439, 3441, 3475, 3476, 3973, 3980, 3991, 3997, 4001, 4012, 4020, 4029, 4049,
                                 4058, 4067, 4076, 4078, 4094, 4117, 4126, 4135, 4144, 4146, 4160, 4163, 4169, 4179,
                                 4185, 4209, 4211
                               );
        DELETE FROM crunch.Costs_RE
        WHERE CostElementId IN ( 473, 477, 482, 486, 511, 516, 3443, 3445, 3447, 3449, 3451, 3453, 3968, 3974, 3985,
                                 3992, 4005, 4013, 4025, 4031, 4035, 4036, 4038, 4040, 4043, 4050, 4061, 4069, 4082,
                                 4089, 4096, 4099, 4101, 4102, 4104, 4106, 4107, 4111, 4118, 4129, 4137, 4150, 4155,
                                 4165, 4171, 4174, 4175, 4180, 4186
                               );
        DELETE FROM crunch.Costs_RO
        WHERE CostElementId IN ( 533, 535, 537, 542, 544, 546, 564, 568, 570, 655, 656, 657, 673, 674, 675, 3455, 3457,
                                 3459, 3461, 3479, 3480, 3975, 3981, 3988, 3998, 4002, 4014, 4024, 4030, 4051, 4055,
                                 4064, 4073, 4079, 4090, 4119, 4123, 4132, 4141, 4147, 4156, 4164, 4170, 4181, 4187,
                                 4204, 4206
                               );
        DELETE FROM crunch.Costs_RWO
        WHERE CostElementId IN ( 584, 586, 588, 593, 595, 597, 604, 608, 610, 3017, 3019, 3021, 3023, 3025, 3027, 3463,
                                 3465, 3467, 3469, 3483, 3484, 3976, 3982, 3989, 3999, 4003, 4015, 4026, 4032, 4052,
                                 4056, 4065, 4074, 4080, 4091, 4120, 4124, 4133, 4142, 4148, 4157, 4166, 4172, 4182,
                                 4188, 4205, 4207
                               );



        DECLARE @CrunchTime SMALLDATETIME = CONVERT(SMALLDATETIME, GETDATE());

        BEGIN
            --##########################  Actual cost of Basic Training #################################
            -- ### ENLISTED ###
            -- ## MPA ##
            --Active
            INSERT INTO crunch.Costs_AE
            (
                PayPlan,
                CMF,
                MOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   3957,
                   GradeType,
                   GradeLevel,
                   -1,
                   MPA_PP + MPA_CMF + MPA_MOS,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'AE'
                  AND coursetype = 'B';
            --NG
            INSERT INTO crunch.Costs_NE
            (
                PayPlan,
                CMF,
                MOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   3967,
                   GradeType,
                   GradeLevel,
                   -1,
                   MPA_PP + MPA_CMF + MPA_MOS,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'NE'
                  AND coursetype = 'B';
            --Reserve
            INSERT INTO crunch.Costs_RE
            (
                PayPlan,
                CMF,
                MOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   3968,
                   GradeType,
                   GradeLevel,
                   -1,
                   MPA_PP + MPA_CMF + MPA_MOS,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'RE'
                  AND coursetype = 'B';
            -- ## OMA ##
            --Active
            INSERT INTO crunch.Costs_AE
            (
                PayPlan,
                CMF,
                MOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   4041,
                   GradeType,
                   GradeLevel,
                   -1,
                   OMA_PP + OMA_CMF + OMA_MOS,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'AE'
                  AND coursetype = 'B';
            --NG
            INSERT INTO crunch.Costs_NE
            (
                PayPlan,
                CMF,
                MOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   4042,
                   GradeType,
                   GradeLevel,
                   -1,
                   OMA_PP + OMA_CMF + OMA_MOS,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'NE'
                  AND coursetype = 'B';
            --Reserve
            INSERT INTO crunch.Costs_RE
            (
                PayPlan,
                CMF,
                MOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   4043,
                   GradeType,
                   GradeLevel,
                   -1,
                   OMA_PP + OMA_CMF + OMA_MOS,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'RE'
                  AND coursetype = 'B';
            -- ## OMA_1 ##
            --Active
            INSERT INTO crunch.Costs_AE
            (
                PayPlan,
                CMF,
                MOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   4109,
                   GradeType,
                   GradeLevel,
                   -1,
                   other_PP + Other_CMF + Other_MOS,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'AE'
                  AND coursetype = 'B';
            --NG
            INSERT INTO crunch.Costs_NE
            (
                PayPlan,
                CMF,
                MOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   4110,
                   GradeType,
                   GradeLevel,
                   -1,
                   other_PP + Other_CMF + Other_MOS,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'NE'
                  AND coursetype = 'B';
            --Reserve
            INSERT INTO crunch.Costs_RE
            (
                PayPlan,
                CMF,
                MOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   4111,
                   GradeType,
                   GradeLevel,
                   -1,
                   other_PP + Other_CMF + Other_MOS,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'RE'
                  AND coursetype = 'B';




            --##########################  Actual cost of Career Training #################################
            -- ### ENLISTED ###
            -- ## MPA ##
            --Active
            INSERT INTO crunch.Costs_AE
            (
                PayPlan,
                CMF,
                MOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   3958,
                   GradeType,
                   GradeLevel,
                   -1,
                   MPA_PP + MPA_CMF + MPA_MOS,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'AE'
                  AND coursetype = 'C';
            --NG
            INSERT INTO crunch.Costs_NE
            (
                PayPlan,
                CMF,
                MOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   3971,
                   GradeType,
                   GradeLevel,
                   -1,
                   MPA_PP + MPA_CMF + MPA_MOS,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'NE'
                  AND coursetype = 'C';
            --Reserve
            INSERT INTO crunch.Costs_RE
            (
                PayPlan,
                CMF,
                MOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   3974,
                   GradeType,
                   GradeLevel,
                   -1,
                   MPA_PP + MPA_CMF + MPA_MOS,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'RE'
                  AND coursetype = 'C';
            -- ## OMA ##
            --Active
            INSERT INTO crunch.Costs_AE
            (
                PayPlan,
                CMF,
                MOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   4044,
                   GradeType,
                   GradeLevel,
                   -1,
                   OMA_PP + OMA_CMF + OMA_MOS,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'AE'
                  AND coursetype = 'C';
            --NG
            INSERT INTO crunch.Costs_NE
            (
                PayPlan,
                CMF,
                MOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   4047,
                   GradeType,
                   GradeLevel,
                   -1,
                   OMA_PP + OMA_CMF + OMA_MOS,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'NE'
                  AND coursetype = 'C';
            --Reserve
            INSERT INTO crunch.Costs_RE
            (
                PayPlan,
                CMF,
                MOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   4050,
                   GradeType,
                   GradeLevel,
                   -1,
                   OMA_PP + OMA_CMF + OMA_MOS,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'RE'
                  AND coursetype = 'C';
            -- ## OMA_1 ##
            --Active
            INSERT INTO crunch.Costs_AE
            (
                PayPlan,
                CMF,
                MOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   4112,
                   GradeType,
                   GradeLevel,
                   -1,
                   other_PP + Other_CMF + Other_MOS,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'AE'
                  AND coursetype = 'C';
            --NG
            INSERT INTO crunch.Costs_NE
            (
                PayPlan,
                CMF,
                MOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   4115,
                   GradeType,
                   GradeLevel,
                   -1,
                   other_PP + Other_CMF + Other_MOS,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'NE'
                  AND coursetype = 'C';
            --Reserve
            INSERT INTO crunch.Costs_RE
            (
                PayPlan,
                CMF,
                MOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   4118,
                   GradeType,
                   GradeLevel,
                   -1,
                   other_PP + Other_CMF + Other_MOS,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'RE'
                  AND coursetype = 'C';

            -- ### Officer ###
            -- ## MPA ##
            --Active
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
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   3969,
                   GradeType,
                   GradeLevel,
                   -1,
                   MPA_PP + MPA_CMF + MPA_MOS,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'AO'
                  AND coursetype = 'C';
            --NG
            INSERT INTO crunch.Costs_NO
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
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   3972,
                   GradeType,
                   GradeLevel,
                   -1,
                   MPA_PP + MPA_CMF + MPA_MOS,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'NO'
                  AND coursetype = 'C';
            --Reserve
            INSERT INTO crunch.Costs_RO
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
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   3975,
                   GradeType,
                   GradeLevel,
                   -1,
                   MPA_PP + MPA_CMF + MPA_MOS,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'RO'
                  AND coursetype = 'C';
            -- ## OMA ##
            --Active
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
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   4045,
                   GradeType,
                   GradeLevel,
                   -1,
                   OMA_PP + OMA_CMF + OMA_MOS,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'AO'
                  AND coursetype = 'C';
            --NG
            INSERT INTO crunch.Costs_NO
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
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   4048,
                   GradeType,
                   GradeLevel,
                   -1,
                   OMA_PP + OMA_CMF + OMA_MOS,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'NO'
                  AND coursetype = 'C';
            --Reserve
            INSERT INTO crunch.Costs_RO
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
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   4051,
                   GradeType,
                   GradeLevel,
                   -1,
                   OMA_PP + OMA_CMF + OMA_MOS,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'RO'
                  AND coursetype = 'C';
            -- ## OMA_1 ##
            --Active
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
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   4113,
                   GradeType,
                   GradeLevel,
                   -1,
                   other_PP + Other_CMF + Other_MOS,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'AO'
                  AND coursetype = 'C';
            --NG
            INSERT INTO crunch.Costs_NO
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
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   4116,
                   GradeType,
                   GradeLevel,
                   -1,
                   other_PP + Other_CMF + Other_MOS,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'NO'
                  AND coursetype = 'C';
            --Reserve
            INSERT INTO crunch.Costs_RO
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
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   4119,
                   GradeType,
                   GradeLevel,
                   -1,
                   other_PP + Other_CMF + Other_MOS,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'RO'
                  AND coursetype = 'C';

            -- ### Warrant ###
            -- ## MPA ##
            --Active
            INSERT INTO crunch.Costs_AWO
            (
                PayPlan,
                Branch,
                WOMOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   3970,
                   GradeType,
                   GradeLevel,
                   -1,
                   MPA_PP + MPA_CMF + MPA_MOS,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'AWO'
                  AND coursetype = 'C';
            --NG
            INSERT INTO crunch.Costs_NWO
            (
                PayPlan,
                Branch,
                WOMOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   3973,
                   GradeType,
                   GradeLevel,
                   -1,
                   MPA_PP + MPA_CMF + MPA_MOS,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'NWO'
                  AND coursetype = 'C';
            --Reserve
            INSERT INTO crunch.Costs_RWO
            (
                PayPlan,
                Branch,
                WOMOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   3976,
                   GradeType,
                   GradeLevel,
                   -1,
                   MPA_PP + MPA_CMF + MPA_MOS,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'RWO'
                  AND coursetype = 'C';
            -- ## OMA ##
            --Active
            INSERT INTO crunch.Costs_AWO
            (
                PayPlan,
                Branch,
                WOMOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   4046,
                   GradeType,
                   GradeLevel,
                   -1,
                   OMA_PP + OMA_CMF + OMA_MOS,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'AWO'
                  AND coursetype = 'C';
            --NG
            INSERT INTO crunch.Costs_NWO
            (
                PayPlan,
                Branch,
                WOMOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   4049,
                   GradeType,
                   GradeLevel,
                   -1,
                   OMA_PP + OMA_CMF + OMA_MOS,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'NWO'
                  AND coursetype = 'C';
            --Reserve
            INSERT INTO crunch.Costs_RWO
            (
                PayPlan,
                Branch,
                WOMOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   4052,
                   GradeType,
                   GradeLevel,
                   -1,
                   OMA_PP + OMA_CMF + OMA_MOS,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'RWO'
                  AND coursetype = 'C';
            -- ## OMA_1 ##
            --Active
            INSERT INTO crunch.Costs_AWO
            (
                PayPlan,
                Branch,
                WOMOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   4114,
                   GradeType,
                   GradeLevel,
                   -1,
                   other_PP + Other_CMF + Other_MOS,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'AWO'
                  AND coursetype = 'C';
            --NG
            INSERT INTO crunch.Costs_NWO
            (
                PayPlan,
                Branch,
                WOMOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   4117,
                   GradeType,
                   GradeLevel,
                   -1,
                   other_PP + Other_CMF + Other_MOS,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'NWO'
                  AND coursetype = 'C';
            --Reserve
            INSERT INTO crunch.Costs_RWO
            (
                PayPlan,
                Branch,
                WOMOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   4120,
                   GradeType,
                   GradeLevel,
                   -1,
                   other_PP + Other_CMF + Other_MOS,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'RWO'
                  AND coursetype = 'C';


            --##########################  Actual cost of Initial Entry Training #################################
            -- ### Officer ###
            -- ## MPA ##
            --Active
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
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   3977,
                   GradeType,
                   GradeLevel,
                   -1,
                   MPA_PP + MPA_CMF + MPA_MOS,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'AO'
                  AND coursetype = 'IET';
            --NG
            INSERT INTO crunch.Costs_NO
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
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   3979,
                   GradeType,
                   GradeLevel,
                   -1,
                   MPA_PP + MPA_CMF + MPA_MOS,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'NO'
                  AND coursetype = 'IET';
            --Reserve
            INSERT INTO crunch.Costs_RO
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
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   3981,
                   GradeType,
                   GradeLevel,
                   -1,
                   MPA_PP + MPA_CMF + MPA_MOS,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'RO'
                  AND coursetype = 'IET';
            -- ## OMA ##
            --Active
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
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   4053,
                   GradeType,
                   GradeLevel,
                   -1,
                   OMA_PP + OMA_CMF + OMA_MOS,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'AO'
                  AND coursetype = 'IET';
            --NG
            INSERT INTO crunch.Costs_NO
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
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   4057,
                   GradeType,
                   GradeLevel,
                   -1,
                   OMA_PP + OMA_CMF + OMA_MOS,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'NO'
                  AND coursetype = 'IET';
            --Reserve
            INSERT INTO crunch.Costs_RO
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
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   4055,
                   GradeType,
                   GradeLevel,
                   -1,
                   OMA_PP + OMA_CMF + OMA_MOS,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'RO'
                  AND coursetype = 'IET';
            -- ## OMA_1 ##
            --Active
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
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   4121,
                   GradeType,
                   GradeLevel,
                   -1,
                   other_PP + Other_CMF + Other_MOS,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'AO'
                  AND coursetype = 'IET';
            --NG
            INSERT INTO crunch.Costs_NO
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
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   4125,
                   GradeType,
                   GradeLevel,
                   -1,
                   other_PP + Other_CMF + Other_MOS,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'NO'
                  AND coursetype = 'IET';
            --Reserve
            INSERT INTO crunch.Costs_RO
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
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   4123,
                   GradeType,
                   GradeLevel,
                   -1,
                   other_PP + Other_CMF + Other_MOS,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'RO'
                  AND coursetype = 'IET';

            -- ### Warrant ###
            -- ## MPA ##
            --Active
            INSERT INTO crunch.Costs_AWO
            (
                PayPlan,
                Branch,
                WOMOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   3978,
                   GradeType,
                   GradeLevel,
                   -1,
                   MPA_PP + MPA_CMF + MPA_MOS,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'AWO'
                  AND coursetype = 'IET';
            --NG
            INSERT INTO crunch.Costs_NWO
            (
                PayPlan,
                Branch,
                WOMOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   3980,
                   GradeType,
                   GradeLevel,
                   -1,
                   MPA_PP + MPA_CMF + MPA_MOS,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'NWO'
                  AND coursetype = 'IET';
            --Reserve
            INSERT INTO crunch.Costs_RWO
            (
                PayPlan,
                Branch,
                WOMOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   3982,
                   GradeType,
                   GradeLevel,
                   -1,
                   MPA_PP + MPA_CMF + MPA_MOS,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'RWO'
                  AND coursetype = 'IET';
            -- ## OMA ##
            --Active
            INSERT INTO crunch.Costs_AWO
            (
                PayPlan,
                Branch,
                WOMOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   4054,
                   GradeType,
                   GradeLevel,
                   -1,
                   OMA_PP + OMA_CMF + OMA_MOS,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'AWO'
                  AND coursetype = 'IET';
            --NG
            INSERT INTO crunch.Costs_NWO
            (
                PayPlan,
                Branch,
                WOMOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   4058,
                   GradeType,
                   GradeLevel,
                   -1,
                   OMA_PP + OMA_CMF + OMA_MOS,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'NWO'
                  AND coursetype = 'IET';
            --Reserve
            INSERT INTO crunch.Costs_RWO
            (
                PayPlan,
                Branch,
                WOMOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   4056,
                   GradeType,
                   GradeLevel,
                   -1,
                   OMA_PP + OMA_CMF + OMA_MOS,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'RWO'
                  AND coursetype = 'IET';
            -- ## OMA_1 ##
            --Active
            INSERT INTO crunch.Costs_AWO
            (
                PayPlan,
                Branch,
                WOMOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   4122,
                   GradeType,
                   GradeLevel,
                   -1,
                   other_PP + Other_CMF + Other_MOS,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'AWO'
                  AND coursetype = 'IET';
            --NG
            INSERT INTO crunch.Costs_NWO
            (
                PayPlan,
                Branch,
                WOMOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   4126,
                   GradeType,
                   GradeLevel,
                   -1,
                   other_PP + Other_CMF + Other_MOS,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'NWO'
                  AND coursetype = 'IET';
            --Reserve
            INSERT INTO crunch.Costs_RWO
            (
                PayPlan,
                Branch,
                WOMOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   4124,
                   GradeType,
                   GradeLevel,
                   -1,
                   other_PP + Other_CMF + Other_MOS,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'RWO'
                  AND coursetype = 'IET';

            --##########################  Actual cost of Initial Skill Training #################################
            -- ### ENLISTED ###
            -- ## MPA ##
            --Active
            INSERT INTO crunch.Costs_AE
            (
                PayPlan,
                CMF,
                MOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   3959,
                   GradeType,
                   GradeLevel,
                   -1,
                   MPA_PP + MPA_CMF + MPA_MOS,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'AE'
                  AND coursetype = 'AIT';
            --NG
            INSERT INTO crunch.Costs_NE
            (
                PayPlan,
                CMF,
                MOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   3984,
                   GradeType,
                   GradeLevel,
                   -1,
                   MPA_PP + MPA_CMF + MPA_MOS,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'NE'
                  AND coursetype = 'AIT';
            --Reserve
            INSERT INTO crunch.Costs_RE
            (
                PayPlan,
                CMF,
                MOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   3985,
                   GradeType,
                   GradeLevel,
                   -1,
                   MPA_PP + MPA_CMF + MPA_MOS,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'RE'
                  AND coursetype = 'AIT';
            -- ## OMA ##
            --Active
            INSERT INTO crunch.Costs_AE
            (
                PayPlan,
                CMF,
                MOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   4059,
                   GradeType,
                   GradeLevel,
                   -1,
                   OMA_PP + OMA_CMF + OMA_MOS,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'AE'
                  AND coursetype = 'AIT';
            --NG
            INSERT INTO crunch.Costs_NE
            (
                PayPlan,
                CMF,
                MOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   4060,
                   GradeType,
                   GradeLevel,
                   -1,
                   OMA_PP + OMA_CMF + OMA_MOS,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'NE'
                  AND coursetype = 'AIT';
            --Reserve
            INSERT INTO crunch.Costs_RE
            (
                PayPlan,
                CMF,
                MOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   4061,
                   GradeType,
                   GradeLevel,
                   -1,
                   OMA_PP + OMA_CMF + OMA_MOS,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'RE'
                  AND coursetype = 'AIT';
            -- ## OMA_1 ##
            --Active
            INSERT INTO crunch.Costs_AE
            (
                PayPlan,
                CMF,
                MOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   4127,
                   GradeType,
                   GradeLevel,
                   -1,
                   other_PP + Other_CMF + Other_MOS,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'AE'
                  AND coursetype = 'AIT';
            --NG
            INSERT INTO crunch.Costs_NE
            (
                PayPlan,
                CMF,
                MOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   4128,
                   GradeType,
                   GradeLevel,
                   -1,
                   other_PP + Other_CMF + Other_MOS,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'NE'
                  AND coursetype = 'AIT';
            --Reserve
            INSERT INTO crunch.Costs_RE
            (
                PayPlan,
                CMF,
                MOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   4129,
                   GradeType,
                   GradeLevel,
                   -1,
                   other_PP + Other_CMF + Other_MOS,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'RE'
                  AND coursetype = 'AIT';


            --##########################  Actual cost of Officer's Undergraduate Pilot Training #################################
            -- ### Officer ###
            -- ## MPA ##
            --Active
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
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   3986,
                   GradeType,
                   GradeLevel,
                   -1,
                   MPA_PP + MPA_CMF + MPA_MOS,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'AO'
                  AND coursetype = 'F';
            --NG
            INSERT INTO crunch.Costs_NO
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
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   3990,
                   GradeType,
                   GradeLevel,
                   -1,
                   MPA_PP + MPA_CMF + MPA_MOS,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'NO'
                  AND coursetype = 'F';
            --Reserve
            INSERT INTO crunch.Costs_RO
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
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   3988,
                   GradeType,
                   GradeLevel,
                   -1,
                   MPA_PP + MPA_CMF + MPA_MOS,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'RO'
                  AND coursetype = 'F';
            -- ## OMA ##
            --Active
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
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   4062,
                   GradeType,
                   GradeLevel,
                   -1,
                   OMA_PP + OMA_CMF + OMA_MOS,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'AO'
                  AND coursetype = 'F';
            --NG
            INSERT INTO crunch.Costs_NO
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
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   4066,
                   GradeType,
                   GradeLevel,
                   -1,
                   OMA_PP + OMA_CMF + OMA_MOS,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'NO'
                  AND coursetype = 'F';
            --Reserve
            INSERT INTO crunch.Costs_RO
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
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   4064,
                   GradeType,
                   GradeLevel,
                   -1,
                   OMA_PP + OMA_CMF + OMA_MOS,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'RO'
                  AND coursetype = 'F';
            -- ## OMA_1 ##
            --Active
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
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   4130,
                   GradeType,
                   GradeLevel,
                   -1,
                   other_PP + Other_CMF + Other_MOS,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'AO'
                  AND coursetype = 'F';
            --NG
            INSERT INTO crunch.Costs_NO
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
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   4134,
                   GradeType,
                   GradeLevel,
                   -1,
                   other_PP + Other_CMF + Other_MOS,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'NO'
                  AND coursetype = 'F';
            --Reserve
            INSERT INTO crunch.Costs_RO
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
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   4132,
                   GradeType,
                   GradeLevel,
                   -1,
                   other_PP + Other_CMF + Other_MOS,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'RO'
                  AND coursetype = 'F';

            -- ### Warrant ###
            -- ## MPA ##
            --Active
            INSERT INTO crunch.Costs_AWO
            (
                PayPlan,
                Branch,
                WOMOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   3987,
                   GradeType,
                   GradeLevel,
                   -1,
                   MPA_PP + MPA_CMF + MPA_MOS,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'AWO'
                  AND coursetype = 'F';
            --NG
            INSERT INTO crunch.Costs_NWO
            (
                PayPlan,
                Branch,
                WOMOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   3991,
                   GradeType,
                   GradeLevel,
                   -1,
                   MPA_PP + MPA_CMF + MPA_MOS,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'NWO'
                  AND coursetype = 'F';
            --Reserve
            INSERT INTO crunch.Costs_RWO
            (
                PayPlan,
                Branch,
                WOMOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   3989,
                   GradeType,
                   GradeLevel,
                   -1,
                   MPA_PP + MPA_CMF + MPA_MOS,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'RWO'
                  AND coursetype = 'F';
            -- ## OMA ##
            --Active
            INSERT INTO crunch.Costs_AWO
            (
                PayPlan,
                Branch,
                WOMOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   4063,
                   GradeType,
                   GradeLevel,
                   -1,
                   OMA_PP + OMA_CMF + OMA_MOS,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'AWO'
                  AND coursetype = 'F';
            --NG
            INSERT INTO crunch.Costs_NWO
            (
                PayPlan,
                Branch,
                WOMOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   4067,
                   GradeType,
                   GradeLevel,
                   -1,
                   OMA_PP + OMA_CMF + OMA_MOS,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'NWO'
                  AND coursetype = 'F';
            --Reserve
            INSERT INTO crunch.Costs_RWO
            (
                PayPlan,
                Branch,
                WOMOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   4065,
                   GradeType,
                   GradeLevel,
                   -1,
                   OMA_PP + OMA_CMF + OMA_MOS,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'RWO'
                  AND coursetype = 'F';
            -- ## OMA_1 ##
            --Active
            INSERT INTO crunch.Costs_AWO
            (
                PayPlan,
                Branch,
                WOMOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   4131,
                   GradeType,
                   GradeLevel,
                   -1,
                   other_PP + Other_CMF + Other_MOS,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'AWO'
                  AND coursetype = 'F';
            --NG
            INSERT INTO crunch.Costs_NWO
            (
                PayPlan,
                Branch,
                WOMOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   4135,
                   GradeType,
                   GradeLevel,
                   -1,
                   other_PP + Other_CMF + Other_MOS,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'NWO'
                  AND coursetype = 'F';
            --Reserve
            INSERT INTO crunch.Costs_RWO
            (
                PayPlan,
                Branch,
                WOMOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   4133,
                   GradeType,
                   GradeLevel,
                   -1,
                   other_PP + Other_CMF + Other_MOS,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'RWO'
                  AND coursetype = 'F';


            --##########################  Actual cost of One Station Unit Training #################################
            -- ### ENLISTED ###
            -- ## MPA ##
            --Active
            INSERT INTO crunch.Costs_AE
            (
                PayPlan,
                CMF,
                MOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   3960,
                   GradeType,
                   GradeLevel,
                   -1,
                   MPA_PP + MPA_CMF + MPA_MOS,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'AE'
                  AND coursetype = 'OSUT';
            --NG
            INSERT INTO crunch.Costs_NE
            (
                PayPlan,
                CMF,
                MOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   3993,
                   GradeType,
                   GradeLevel,
                   -1,
                   MPA_PP + MPA_CMF + MPA_MOS,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'NE'
                  AND coursetype = 'OSUT';
            --Reserve
            INSERT INTO crunch.Costs_RE
            (
                PayPlan,
                CMF,
                MOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   3992,
                   GradeType,
                   GradeLevel,
                   -1,
                   MPA_PP + MPA_CMF + MPA_MOS,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'RE'
                  AND coursetype = 'OSUT';
            -- ## OMA ##
            --Active
            INSERT INTO crunch.Costs_AE
            (
                PayPlan,
                CMF,
                MOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   4068,
                   GradeType,
                   GradeLevel,
                   -1,
                   OMA_PP + OMA_CMF + OMA_MOS,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'AE'
                  AND coursetype = 'OSUT';
            --NG
            INSERT INTO crunch.Costs_NE
            (
                PayPlan,
                CMF,
                MOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   4070,
                   GradeType,
                   GradeLevel,
                   -1,
                   OMA_PP + OMA_CMF + OMA_MOS,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'NE'
                  AND coursetype = 'OSUT';
            --Reserve
            INSERT INTO crunch.Costs_RE
            (
                PayPlan,
                CMF,
                MOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   4069,
                   GradeType,
                   GradeLevel,
                   -1,
                   OMA_PP + OMA_CMF + OMA_MOS,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'RE'
                  AND coursetype = 'OSUT';
            -- ## OMA_1 ##
            --Active
            INSERT INTO crunch.Costs_AE
            (
                PayPlan,
                CMF,
                MOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   4136,
                   GradeType,
                   GradeLevel,
                   -1,
                   other_PP + Other_CMF + Other_MOS,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'AE'
                  AND coursetype = 'OSUT';
            --NG
            INSERT INTO crunch.Costs_NE
            (
                PayPlan,
                CMF,
                MOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   4138,
                   GradeType,
                   GradeLevel,
                   -1,
                   other_PP + Other_CMF + Other_MOS,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'NE'
                  AND coursetype = 'OSUT';
            --Reserve
            INSERT INTO crunch.Costs_RE
            (
                PayPlan,
                CMF,
                MOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   4137,
                   GradeType,
                   GradeLevel,
                   -1,
                   other_PP + Other_CMF + Other_MOS,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'RE'
                  AND coursetype = 'OSUT';





            --##########################  Actual cost of Other Flight Training #################################
            -- ### Officer ###
            -- ## MPA ##
            --Active
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
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   3994,
                   GradeType,
                   GradeLevel,
                   -1,
                   MPA_PP + MPA_CMF + MPA_MOS,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'AO'
                  AND coursetype = 'O';
            --NG
            INSERT INTO crunch.Costs_NO
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
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   3996,
                   GradeType,
                   GradeLevel,
                   -1,
                   MPA_PP + MPA_CMF + MPA_MOS,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'NO'
                  AND coursetype = 'O';
            --Reserve
            INSERT INTO crunch.Costs_RO
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
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   3998,
                   GradeType,
                   GradeLevel,
                   -1,
                   MPA_PP + MPA_CMF + MPA_MOS,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'RO'
                  AND coursetype = 'O';
            -- ## OMA ##
            --Active
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
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   4071,
                   GradeType,
                   GradeLevel,
                   -1,
                   OMA_PP + OMA_CMF + OMA_MOS,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'AO'
                  AND coursetype = 'O';
            --NG
            INSERT INTO crunch.Costs_NO
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
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   4075,
                   GradeType,
                   GradeLevel,
                   -1,
                   OMA_PP + OMA_CMF + OMA_MOS,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'NO'
                  AND coursetype = 'O';
            --Reserve
            INSERT INTO crunch.Costs_RO
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
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   4073,
                   GradeType,
                   GradeLevel,
                   -1,
                   OMA_PP + OMA_CMF + OMA_MOS,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'RO'
                  AND coursetype = 'O';
            -- ## Other ##
            --Active
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
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   4139,
                   GradeType,
                   GradeLevel,
                   -1,
                   other_PP + Other_CMF + Other_MOS,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'AO'
                  AND coursetype = 'O';
            --NG
            INSERT INTO crunch.Costs_NO
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
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   4143,
                   GradeType,
                   GradeLevel,
                   -1,
                   other_PP + Other_CMF + Other_MOS,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'NO'
                  AND coursetype = 'O';
            --Reserve
            INSERT INTO crunch.Costs_RO
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
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   4141,
                   GradeType,
                   GradeLevel,
                   -1,
                   other_PP + Other_CMF + Other_MOS,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'RO'
                  AND coursetype = 'O';

            -- ### Warrant ###
            -- ## MPA ##
            --Active
            INSERT INTO crunch.Costs_AWO
            (
                PayPlan,
                Branch,
                WOMOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   3995,
                   GradeType,
                   GradeLevel,
                   -1,
                   MPA_PP + MPA_CMF + MPA_MOS,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'AWO'
                  AND coursetype = 'O';
            --NG
            INSERT INTO crunch.Costs_NWO
            (
                PayPlan,
                Branch,
                WOMOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   3997,
                   GradeType,
                   GradeLevel,
                   -1,
                   MPA_PP + MPA_CMF + MPA_MOS,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'NWO'
                  AND coursetype = 'O';
            --Reserve
            INSERT INTO crunch.Costs_RWO
            (
                PayPlan,
                Branch,
                WOMOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   3999,
                   GradeType,
                   GradeLevel,
                   -1,
                   MPA_PP + MPA_CMF + MPA_MOS,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'RWO'
                  AND coursetype = 'O';
            -- ## OMA ##
            --Active
            INSERT INTO crunch.Costs_AWO
            (
                PayPlan,
                Branch,
                WOMOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   4072,
                   GradeType,
                   GradeLevel,
                   -1,
                   OMA_PP + OMA_CMF + OMA_MOS,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'AWO'
                  AND coursetype = 'O';
            --NG
            INSERT INTO crunch.Costs_NWO
            (
                PayPlan,
                Branch,
                WOMOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   4076,
                   GradeType,
                   GradeLevel,
                   -1,
                   OMA_PP + OMA_CMF + OMA_MOS,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'NWO'
                  AND coursetype = 'O';
            --Reserve
            INSERT INTO crunch.Costs_RWO
            (
                PayPlan,
                Branch,
                WOMOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   4074,
                   GradeType,
                   GradeLevel,
                   -1,
                   OMA_PP + OMA_CMF + OMA_MOS,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'RWO'
                  AND coursetype = 'O';
            -- ## OMA_1 ##
            --Active
            INSERT INTO crunch.Costs_AWO
            (
                PayPlan,
                Branch,
                WOMOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   4140,
                   GradeType,
                   GradeLevel,
                   -1,
                   other_PP + Other_CMF + Other_MOS,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'AWO'
                  AND coursetype = 'O';
            --NG
            INSERT INTO crunch.Costs_NWO
            (
                PayPlan,
                Branch,
                WOMOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   4144,
                   GradeType,
                   GradeLevel,
                   -1,
                   other_PP + Other_CMF + Other_MOS,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'NWO'
                  AND coursetype = 'O';
            --Reserve
            INSERT INTO crunch.Costs_RWO
            (
                PayPlan,
                Branch,
                WOMOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   4142,
                   GradeType,
                   GradeLevel,
                   -1,
                   other_PP + Other_CMF + Other_MOS,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'RWO'
                  AND coursetype = 'O';




            --##########################  Actual cost of Professional Training #################################
            -- ### ENLISTED ###
            -- ## MPA ##
            --Active
            INSERT INTO crunch.Costs_AE
            (
                PayPlan,
                CMF,
                MOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   3961,
                   GradeType,
                   GradeLevel,
                   -1,
                   MPA_PP + MPA_CMF + MPA_MOS,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'AE'
                  AND coursetype = 'P';
            --NG
            INSERT INTO crunch.Costs_NE
            (
                PayPlan,
                CMF,
                MOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   4004,
                   GradeType,
                   GradeLevel,
                   -1,
                   MPA_PP + MPA_CMF + MPA_MOS,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'NE'
                  AND coursetype = 'P';
            --Reserve
            INSERT INTO crunch.Costs_RE
            (
                PayPlan,
                CMF,
                MOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   4005,
                   GradeType,
                   GradeLevel,
                   -1,
                   MPA_PP + MPA_CMF + MPA_MOS,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'RE'
                  AND coursetype = 'P';
            -- ## OMA ##
            --Active
            INSERT INTO crunch.Costs_AE
            (
                PayPlan,
                CMF,
                MOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   4085,
                   GradeType,
                   GradeLevel,
                   -1,
                   OMA_PP + OMA_CMF + OMA_MOS,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'AE'
                  AND coursetype = 'P';
            --NG
            INSERT INTO crunch.Costs_NE
            (
                PayPlan,
                CMF,
                MOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   4081,
                   GradeType,
                   GradeLevel,
                   -1,
                   OMA_PP + OMA_CMF + OMA_MOS,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'NE'
                  AND coursetype = 'P';
            --Reserve
            INSERT INTO crunch.Costs_RE
            (
                PayPlan,
                CMF,
                MOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   4082,
                   GradeType,
                   GradeLevel,
                   -1,
                   OMA_PP + OMA_CMF + OMA_MOS,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'RE'
                  AND coursetype = 'P';
            -- ## OMA_1 ##
            --Active
            INSERT INTO crunch.Costs_AE
            (
                PayPlan,
                CMF,
                MOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   4202,
                   GradeType,
                   GradeLevel,
                   -1,
                   other_PP + Other_CMF + Other_MOS,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'AE'
                  AND coursetype = 'P';
            --NG
            INSERT INTO crunch.Costs_NE
            (
                PayPlan,
                CMF,
                MOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   4149,
                   GradeType,
                   GradeLevel,
                   -1,
                   other_PP + Other_CMF + Other_MOS,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'NE'
                  AND coursetype = 'P';
            --Reserve
            INSERT INTO crunch.Costs_RE
            (
                PayPlan,
                CMF,
                MOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   4150,
                   GradeType,
                   GradeLevel,
                   -1,
                   other_PP + Other_CMF + Other_MOS,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'RE'
                  AND coursetype = 'P';

            -- ### Officer ###
            -- ## MPA ##
            --Active
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
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   4006,
                   GradeType,
                   GradeLevel,
                   -1,
                   MPA_PP + MPA_CMF + MPA_MOS,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'AO'
                  AND coursetype = 'P';
            --NG
            INSERT INTO crunch.Costs_NO
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
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   4000,
                   GradeType,
                   GradeLevel,
                   -1,
                   MPA_PP + MPA_CMF + MPA_MOS,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'NO'
                  AND coursetype = 'P';
            --Reserve
            INSERT INTO crunch.Costs_RO
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
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   4002,
                   GradeType,
                   GradeLevel,
                   -1,
                   MPA_PP + MPA_CMF + MPA_MOS,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'RO'
                  AND coursetype = 'P';
            -- ## OMA ##
            --Active
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
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   4083,
                   GradeType,
                   GradeLevel,
                   -1,
                   OMA_PP + OMA_CMF + OMA_MOS,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'AO'
                  AND coursetype = 'P';
            --NG
            INSERT INTO crunch.Costs_NO
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
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   4077,
                   GradeType,
                   GradeLevel,
                   -1,
                   OMA_PP + OMA_CMF + OMA_MOS,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'NO'
                  AND coursetype = 'P';
            --Reserve
            INSERT INTO crunch.Costs_RO
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
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   4079,
                   GradeType,
                   GradeLevel,
                   -1,
                   OMA_PP + OMA_CMF + OMA_MOS,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'RO'
                  AND coursetype = 'P';
            -- ## OMA ##
            --Active
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
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   4151,
                   GradeType,
                   GradeLevel,
                   -1,
                   other_PP + Other_CMF + Other_MOS,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'AO'
                  AND coursetype = 'P';
            --NG
            INSERT INTO crunch.Costs_NO
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
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   4145,
                   GradeType,
                   GradeLevel,
                   -1,
                   other_PP + Other_CMF + Other_MOS,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'NO'
                  AND coursetype = 'P';
            --Reserve
            INSERT INTO crunch.Costs_RO
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
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   4147,
                   GradeType,
                   GradeLevel,
                   -1,
                   other_PP + Other_CMF + Other_MOS,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'RO'
                  AND coursetype = 'P';

            -- ### Warrant ###
            -- ## MPA ##
            --Active
            INSERT INTO crunch.Costs_AWO
            (
                PayPlan,
                Branch,
                WOMOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   4007,
                   GradeType,
                   GradeLevel,
                   -1,
                   MPA_PP + MPA_CMF + MPA_MOS,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'AWO'
                  AND coursetype = 'P';
            --NG
            INSERT INTO crunch.Costs_NWO
            (
                PayPlan,
                Branch,
                WOMOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   4001,
                   GradeType,
                   GradeLevel,
                   -1,
                   MPA_PP + MPA_CMF + MPA_MOS,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'NWO'
                  AND coursetype = 'P';
            --Reserve
            INSERT INTO crunch.Costs_RWO
            (
                PayPlan,
                Branch,
                WOMOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   4003,
                   GradeType,
                   GradeLevel,
                   -1,
                   MPA_PP + MPA_CMF + MPA_MOS,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'RWO'
                  AND coursetype = 'P';
            -- ## OMA ##
            --Active
            INSERT INTO crunch.Costs_AWO
            (
                PayPlan,
                Branch,
                WOMOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   4084,
                   GradeType,
                   GradeLevel,
                   -1,
                   OMA_PP + OMA_CMF + OMA_MOS,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'AWO'
                  AND coursetype = 'P';
            --NG
            INSERT INTO crunch.Costs_NWO
            (
                PayPlan,
                Branch,
                WOMOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   4078,
                   GradeType,
                   GradeLevel,
                   -1,
                   OMA_PP + OMA_CMF + OMA_MOS,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'NWO'
                  AND coursetype = 'P';
            --Reserve
            INSERT INTO crunch.Costs_RWO
            (
                PayPlan,
                Branch,
                WOMOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   4080,
                   GradeType,
                   GradeLevel,
                   -1,
                   OMA_PP + OMA_CMF + OMA_MOS,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'RWO'
                  AND coursetype = 'P';
            -- ## OMA ##
            --Active
            INSERT INTO crunch.Costs_AWO
            (
                PayPlan,
                Branch,
                WOMOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   4152,
                   GradeType,
                   GradeLevel,
                   -1,
                   other_PP + Other_CMF + Other_MOS,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'AWO'
                  AND coursetype = 'P';
            --NG
            INSERT INTO crunch.Costs_NWO
            (
                PayPlan,
                Branch,
                WOMOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   4146,
                   GradeType,
                   GradeLevel,
                   -1,
                   other_PP + Other_CMF + Other_MOS,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'NWO'
                  AND coursetype = 'P';
            --Reserve
            INSERT INTO crunch.Costs_RWO
            (
                PayPlan,
                Branch,
                WOMOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   4148,
                   GradeType,
                   GradeLevel,
                   -1,
                   other_PP + Other_CMF + Other_MOS,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'RWO'
                  AND coursetype = 'P';



            --##########################  Actual cost of Weapon System Training #################################
            -- ### ENLISTED ###
            -- ## MPA ##
            --Active
            INSERT INTO crunch.Costs_AE
            (
                PayPlan,
                CMF,
                MOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   3962,
                   GradeType,
                   GradeLevel,
                   WeaponSystemId,
                   MPA_PP + MPA_CMF + MPA_MOS,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'AE'
                  AND coursetype = 'W';
            --NG
            INSERT INTO crunch.Costs_NE
            (
                PayPlan,
                CMF,
                MOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   4010,
                   GradeType,
                   GradeLevel,
                   WeaponSystemId,
                   MPA_PP + MPA_CMF + MPA_MOS,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'NE'
                  AND coursetype = 'W';
            --Reserve
            INSERT INTO crunch.Costs_RE
            (
                PayPlan,
                CMF,
                MOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   4013,
                   GradeType,
                   GradeLevel,
                   WeaponSystemId,
                   MPA_PP + MPA_CMF + MPA_MOS,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'RE'
                  AND coursetype = 'W';
            -- ## OMA ##
            --Active
            INSERT INTO crunch.Costs_AE
            (
                PayPlan,
                CMF,
                MOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   4086,
                   GradeType,
                   GradeLevel,
                   WeaponSystemId,
                   OMA_PP + OMA_CMF + OMA_MOS,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'AE'
                  AND coursetype = 'W';
            --NG
            INSERT INTO crunch.Costs_NE
            (
                PayPlan,
                CMF,
                MOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   4092,
                   GradeType,
                   GradeLevel,
                   WeaponSystemId,
                   OMA_PP + OMA_CMF + OMA_MOS,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'NE'
                  AND coursetype = 'W';
            --Reserve
            INSERT INTO crunch.Costs_RE
            (
                PayPlan,
                CMF,
                MOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   4089,
                   GradeType,
                   GradeLevel,
                   WeaponSystemId,
                   OMA_PP + OMA_CMF + OMA_MOS,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'RE'
                  AND coursetype = 'W';
            -- ## OMA_1 ##
            --Active
            INSERT INTO crunch.Costs_AE
            (
                PayPlan,
                CMF,
                MOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   4203,
                   GradeType,
                   GradeLevel,
                   WeaponSystemId,
                   other_PP + Other_CMF + Other_MOS,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'AE'
                  AND coursetype = 'W';
            --NG
            INSERT INTO crunch.Costs_NE
            (
                PayPlan,
                CMF,
                MOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   4158,
                   GradeType,
                   GradeLevel,
                   WeaponSystemId,
                   other_PP + Other_CMF + Other_MOS,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'NE'
                  AND coursetype = 'W';
            --Reserve
            INSERT INTO crunch.Costs_RE
            (
                PayPlan,
                CMF,
                MOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   4155,
                   GradeType,
                   GradeLevel,
                   WeaponSystemId,
                   other_PP + Other_CMF + Other_MOS,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'RE'
                  AND coursetype = 'W';

            -- ### Officer ###
            -- ## MPA ##
            --Active
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
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   4008,
                   GradeType,
                   GradeLevel,
                   WeaponSystemId,
                   MPA_PP + MPA_CMF + MPA_MOS,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'AO'
                  AND coursetype = 'W';
            --NG
            INSERT INTO crunch.Costs_NO
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
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   4011,
                   GradeType,
                   GradeLevel,
                   WeaponSystemId,
                   MPA_PP + MPA_CMF + MPA_MOS,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'NO'
                  AND coursetype = 'W';
            --Reserve
            INSERT INTO crunch.Costs_RO
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
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   4014,
                   GradeType,
                   GradeLevel,
                   WeaponSystemId,
                   MPA_PP + MPA_CMF + MPA_MOS,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'RO'
                  AND coursetype = 'W';
            -- ## OMA ##
            --Active
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
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   4087,
                   GradeType,
                   GradeLevel,
                   WeaponSystemId,
                   OMA_PP + OMA_CMF + OMA_MOS,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'AO'
                  AND coursetype = 'W';
            --NG
            INSERT INTO crunch.Costs_NO
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
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   4093,
                   GradeType,
                   GradeLevel,
                   WeaponSystemId,
                   OMA_PP + OMA_CMF + OMA_MOS,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'NO'
                  AND coursetype = 'W';
            --Reserve
            INSERT INTO crunch.Costs_RO
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
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   4090,
                   GradeType,
                   GradeLevel,
                   WeaponSystemId,
                   OMA_PP + OMA_CMF + OMA_MOS,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'RO'
                  AND coursetype = 'W';
            -- ## OMA_1 ##
            --Active
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
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   4153,
                   GradeType,
                   GradeLevel,
                   WeaponSystemId,
                   other_PP + Other_CMF + Other_MOS,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'AO'
                  AND coursetype = 'W';
            --NG
            INSERT INTO crunch.Costs_NO
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
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   4159,
                   GradeType,
                   GradeLevel,
                   WeaponSystemId,
                   other_PP + Other_CMF + Other_MOS,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'NO'
                  AND coursetype = 'W';
            --Reserve
            INSERT INTO crunch.Costs_RO
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
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   4156,
                   GradeType,
                   GradeLevel,
                   WeaponSystemId,
                   other_PP + Other_CMF + Other_MOS,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'RO'
                  AND coursetype = 'W';

            -- ### Warrant ###
            -- ## MPA ##
            --Active
            INSERT INTO crunch.Costs_AWO
            (
                PayPlan,
                Branch,
                WOMOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   4009,
                   GradeType,
                   GradeLevel,
                   WeaponSystemId,
                   MPA_PP + MPA_CMF + MPA_MOS,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'AWO'
                  AND coursetype = 'W';
            --NG
            INSERT INTO crunch.Costs_NWO
            (
                PayPlan,
                Branch,
                WOMOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   4012,
                   GradeType,
                   GradeLevel,
                   WeaponSystemId,
                   MPA_PP + MPA_CMF + MPA_MOS,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'NWO'
                  AND coursetype = 'W';
            --Reserve
            INSERT INTO crunch.Costs_RWO
            (
                PayPlan,
                Branch,
                WOMOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   4015,
                   GradeType,
                   GradeLevel,
                   WeaponSystemId,
                   MPA_PP + MPA_CMF + MPA_MOS,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'RWO'
                  AND coursetype = 'W';
            -- ## OMA ##
            --Active
            INSERT INTO crunch.Costs_AWO
            (
                PayPlan,
                Branch,
                WOMOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   4088,
                   GradeType,
                   GradeLevel,
                   WeaponSystemId,
                   OMA_PP + OMA_CMF + OMA_MOS,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'AWO'
                  AND coursetype = 'W';
            --NG
            INSERT INTO crunch.Costs_NWO
            (
                PayPlan,
                Branch,
                WOMOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   4094,
                   GradeType,
                   GradeLevel,
                   WeaponSystemId,
                   OMA_PP + OMA_CMF + OMA_MOS,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'NWO'
                  AND coursetype = 'W';
            --Reserve
            INSERT INTO crunch.Costs_RWO
            (
                PayPlan,
                Branch,
                WOMOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   4091,
                   GradeType,
                   GradeLevel,
                   WeaponSystemId,
                   OMA_PP + OMA_CMF + OMA_MOS,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'RWO'
                  AND coursetype = 'W';
            -- ## OMA_1 ##
            --Active
            INSERT INTO crunch.Costs_AWO
            (
                PayPlan,
                Branch,
                WOMOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   4154,
                   GradeType,
                   GradeLevel,
                   WeaponSystemId,
                   other_PP + Other_CMF + Other_MOS,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'AWO'
                  AND coursetype = 'W';
            --NG
            INSERT INTO crunch.Costs_NWO
            (
                PayPlan,
                Branch,
                WOMOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   4160,
                   GradeType,
                   GradeLevel,
                   WeaponSystemId,
                   other_PP + Other_CMF + Other_MOS,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'NWO'
                  AND coursetype = 'W';
            --Reserve
            INSERT INTO crunch.Costs_RWO
            (
                PayPlan,
                Branch,
                WOMOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   4157,
                   GradeType,
                   GradeLevel,
                   WeaponSystemId,
                   other_PP + Other_CMF + Other_MOS,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'RWO'
                  AND coursetype = 'W';








            --##########################  Avg cost of Basic Training #################################
            -- ### ENLISTED ###
            -- ## MPA ##
            --Active
            INSERT INTO crunch.Costs_AE
            (
                PayPlan,
                CMF,
                MOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   56,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_MPA,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'AE'
                  AND coursetype = 'B';
            --NG
            INSERT INTO crunch.Costs_NE
            (
                PayPlan,
                CMF,
                MOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   4034,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_MPA,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'NE'
                  AND coursetype = 'B';
            --Reserve
            INSERT INTO crunch.Costs_RE
            (
                PayPlan,
                CMF,
                MOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   4035,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_MPA,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'RE'
                  AND coursetype = 'B';
            -- ## OMA ##
            --Active
            INSERT INTO crunch.Costs_AE
            (
                PayPlan,
                CMF,
                MOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   91,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_OMA,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'AE'
                  AND coursetype = 'B';
            --NG
            INSERT INTO crunch.Costs_NE
            (
                PayPlan,
                CMF,
                MOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   4105,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_OMA,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'NE'
                  AND coursetype = 'B';
            --Reserve
            INSERT INTO crunch.Costs_RE
            (
                PayPlan,
                CMF,
                MOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   4106,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_OMA,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'RE'
                  AND coursetype = 'B';
            -- ## OMA_1 ##
            --Active
            INSERT INTO crunch.Costs_AE
            (
                PayPlan,
                CMF,
                MOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   110,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_Other,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'AE'
                  AND coursetype = 'B';
            --NG
            INSERT INTO crunch.Costs_NE
            (
                PayPlan,
                CMF,
                MOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   4173,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_Other,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'NE'
                  AND coursetype = 'B';
            --Reserve
            INSERT INTO crunch.Costs_RE
            (
                PayPlan,
                CMF,
                MOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   4174,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_Other,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'RE'
                  AND coursetype = 'B';



            --##########################  Avg cost of Career Training #################################
            -- ### ENLISTED ###
            -- ## MPA ##
            --Active
            INSERT INTO crunch.Costs_AE
            (
                PayPlan,
                CMF,
                MOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   58,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_MPA,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'AE'
                  AND coursetype = 'C';
            --NG
            INSERT INTO crunch.Costs_NE
            (
                PayPlan,
                CMF,
                MOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   347,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_MPA,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'NE'
                  AND coursetype = 'C';
            --Reserve
            INSERT INTO crunch.Costs_RE
            (
                PayPlan,
                CMF,
                MOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   511,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_MPA,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'RE'
                  AND coursetype = 'C';
            -- ## OMA ##
            --Active
            INSERT INTO crunch.Costs_AE
            (
                PayPlan,
                CMF,
                MOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   93,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_OMA,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'AE'
                  AND coursetype = 'C';
            --NG
            INSERT INTO crunch.Costs_NE
            (
                PayPlan,
                CMF,
                MOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   309,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_OMA,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'NE'
                  AND coursetype = 'C';
            --Reserve
            INSERT INTO crunch.Costs_RE
            (
                PayPlan,
                CMF,
                MOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   473,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_OMA,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'RE'
                  AND coursetype = 'C';
            -- ## OMA_1 ##
            --Active
            INSERT INTO crunch.Costs_AE
            (
                PayPlan,
                CMF,
                MOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   112,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_Other,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'AE'
                  AND coursetype = 'C';
            --NG
            INSERT INTO crunch.Costs_NE
            (
                PayPlan,
                CMF,
                MOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   318,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_Other,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'NE'
                  AND coursetype = 'C';
            --Reserve
            INSERT INTO crunch.Costs_RE
            (
                PayPlan,
                CMF,
                MOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   482,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_Other,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'RE'
                  AND coursetype = 'C';

            -- ### Officer ###
            -- ## MPA ##
            --Active
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
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   163,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_MPA,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'AO'
                  AND coursetype = 'C';
            --NG
            INSERT INTO crunch.Costs_NO
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
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   400,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_MPA,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'NO'
                  AND coursetype = 'C';
            --Reserve
            INSERT INTO crunch.Costs_RO
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
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   564,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_MPA,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'RO'
                  AND coursetype = 'C';
            -- ## OMA ##
            --Active
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
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   184,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_OMA,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'AO'
                  AND coursetype = 'C';
            --NG
            INSERT INTO crunch.Costs_NO
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
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   369,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_OMA,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'NO'
                  AND coursetype = 'C';
            --Reserve
            INSERT INTO crunch.Costs_RO
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
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   533,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_OMA,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'RO'
                  AND coursetype = 'C';
            -- ## OMA_1 ##
            --Active
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
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   194,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_Other,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'AO'
                  AND coursetype = 'C';
            --NG
            INSERT INTO crunch.Costs_NO
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
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   378,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_Other,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'NO'
                  AND coursetype = 'C';
            --Reserve
            INSERT INTO crunch.Costs_RO
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
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   542,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_Other,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'RO'
                  AND coursetype = 'C';

            -- ### Warrant ###
            -- ## MPA ##
            --Active
            INSERT INTO crunch.Costs_AWO
            (
                PayPlan,
                Branch,
                WOMOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   237,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_MPA,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'AWO'
                  AND coursetype = 'C';
            --NG
            INSERT INTO crunch.Costs_NWO
            (
                PayPlan,
                Branch,
                WOMOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   440,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_MPA,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'NWO'
                  AND coursetype = 'C';
            --Reserve
            INSERT INTO crunch.Costs_RWO
            (
                PayPlan,
                Branch,
                WOMOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   604,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_MPA,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'RWO'
                  AND coursetype = 'C';
            -- ## OMA ##
            --Active
            INSERT INTO crunch.Costs_AWO
            (
                PayPlan,
                Branch,
                WOMOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   252,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_OMA,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'AWO'
                  AND coursetype = 'C';
            --NG
            INSERT INTO crunch.Costs_NWO
            (
                PayPlan,
                Branch,
                WOMOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   420,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_OMA,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'NWO'
                  AND coursetype = 'C';
            --Reserve
            INSERT INTO crunch.Costs_RWO
            (
                PayPlan,
                Branch,
                WOMOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   584,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_OMA,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'RWO'
                  AND coursetype = 'C';
            -- ## OMA_1 ##
            --Active
            INSERT INTO crunch.Costs_AWO
            (
                PayPlan,
                Branch,
                WOMOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   265,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_Other,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'AWO'
                  AND coursetype = 'C';
            --NG
            INSERT INTO crunch.Costs_NWO
            (
                PayPlan,
                Branch,
                WOMOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   429,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_Other,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'NWO'
                  AND coursetype = 'C';
            --Reserve
            INSERT INTO crunch.Costs_RWO
            (
                PayPlan,
                Branch,
                WOMOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   593,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_Other,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'RWO'
                  AND coursetype = 'C';



            --##########################  Avg cost of General Training #################################
            -- ### ENLISTED ###
            -- ## MPA/RPA/NGPA ##
            --Active
            INSERT INTO crunch.Costs_AE
            (
                PayPlan,
                CMF,
                MOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   3983,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_MPA,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'AE'
                  AND coursetype = 'G';
            --NG
            INSERT INTO crunch.Costs_NE
            (
                PayPlan,
                CMF,
                MOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   4019,
                   GradeType,
                   GradeLevel,
                   -1,
                   RPA_NGPA,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'NE'
                  AND coursetype = 'G';
            --Reserve
            INSERT INTO crunch.Costs_RE
            (
                PayPlan,
                CMF,
                MOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   4031,
                   GradeType,
                   GradeLevel,
                   -1,
                   RPA_NGPA,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'RE'
                  AND coursetype = 'G';
            -- ## OMA/OMAR/OMNG ##
            --Active
            INSERT INTO crunch.Costs_AE
            (
                PayPlan,
                CMF,
                MOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   4022,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_OMA,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'AE'
                  AND coursetype = 'G';
            --NG
            INSERT INTO crunch.Costs_NE
            (
                PayPlan,
                CMF,
                MOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   4028,
                   GradeType,
                   GradeLevel,
                   -1,
                   OMAR_OMNG,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'NE'
                  AND coursetype = 'G';
            --Reserve
            INSERT INTO crunch.Costs_RE
            (
                PayPlan,
                CMF,
                MOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   4025,
                   GradeType,
                   GradeLevel,
                   -1,
                   OMAR_OMNG,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'RE'
                  AND coursetype = 'G';


            -- ### Officer ###
            -- ## MPA ##
            --Active
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
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   4016,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_MPA,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'AO'
                  AND coursetype = 'G';
            --NG
            INSERT INTO crunch.Costs_NO
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
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   4018,
                   GradeType,
                   GradeLevel,
                   -1,
                   RPA_NGPA,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'NO'
                  AND coursetype = 'G';
            --Reserve
            INSERT INTO crunch.Costs_RO
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
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   4030,
                   GradeType,
                   GradeLevel,
                   -1,
                   RPA_NGPA,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'RO'
                  AND coursetype = 'G';
            -- ## OMA ##
            --Active
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
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   4021,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_OMA,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'AO'
                  AND coursetype = 'G';
            --NG
            INSERT INTO crunch.Costs_NO
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
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   4027,
                   GradeType,
                   GradeLevel,
                   -1,
                   OMAR_OMNG,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'NO'
                  AND coursetype = 'G';
            --Reserve
            INSERT INTO crunch.Costs_RO
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
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   4024,
                   GradeType,
                   GradeLevel,
                   -1,
                   OMAR_OMNG,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'RO'
                  AND coursetype = 'G';


            -- ### Warrant ###
            -- ## MPA ##
            --Active
            INSERT INTO crunch.Costs_AWO
            (
                PayPlan,
                Branch,
                WOMOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   4017,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_MPA,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'AWO'
                  AND coursetype = 'G';
            --NG
            INSERT INTO crunch.Costs_NWO
            (
                PayPlan,
                Branch,
                WOMOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   4020,
                   GradeType,
                   GradeLevel,
                   -1,
                   RPA_NGPA,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'NWO'
                  AND coursetype = 'G';
            --Reserve
            INSERT INTO crunch.Costs_RWO
            (
                PayPlan,
                Branch,
                WOMOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   4032,
                   GradeType,
                   GradeLevel,
                   -1,
                   RPA_NGPA,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'RWO'
                  AND coursetype = 'G';
            -- ## OMA ##
            --Active
            INSERT INTO crunch.Costs_AWO
            (
                PayPlan,
                Branch,
                WOMOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   4023,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_OMA,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'AWO'
                  AND coursetype = 'G';
            --NG
            INSERT INTO crunch.Costs_NWO
            (
                PayPlan,
                Branch,
                WOMOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   4029,
                   GradeType,
                   GradeLevel,
                   -1,
                   OMAR_OMNG,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'NWO'
                  AND coursetype = 'G';
            --Reserve
            INSERT INTO crunch.Costs_RWO
            (
                PayPlan,
                Branch,
                WOMOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   4026,
                   GradeType,
                   GradeLevel,
                   -1,
                   OMAR_OMNG,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'RWO'
                  AND coursetype = 'G';


            --##########################  Avg cost of Initial Entry Training #################################
            -- ### ENLISTED ### - NOTE enlisted costs are only for NG/R since they come directly from the JBooks
            --## RPA/NGPA ##
            --NG
            INSERT INTO crunch.Costs_NE
            (
                PayPlan,
                CMF,
                MOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   4033,
                   GradeType,
                   GradeLevel,
                   -1,
                   RPA_NGPA,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'NE'
                  AND coursetype = 'IET';
            --Reserve
            INSERT INTO crunch.Costs_RE
            (
                PayPlan,
                CMF,
                MOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   4040,
                   GradeType,
                   GradeLevel,
                   -1,
                   RPA_NGPA,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'RE'
                  AND coursetype = 'IET';
            --## OMAR/OMNG ##
            --NG
            INSERT INTO crunch.Costs_NE
            (
                PayPlan,
                CMF,
                MOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   4039,
                   GradeType,
                   GradeLevel,
                   -1,
                   OMAR_OMNG,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'NE'
                  AND coursetype = 'IET';
            --Reserve
            INSERT INTO crunch.Costs_RE
            (
                PayPlan,
                CMF,
                MOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   4038,
                   GradeType,
                   GradeLevel,
                   -1,
                   OMAR_OMNG,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'RE'
                  AND coursetype = 'IET';


            -- ### Officer ###
            -- ## MPA ##
            --Active
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
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   3391,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_MPA,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'AO'
                  AND coursetype = 'IET';
            --NG
            INSERT INTO crunch.Costs_NO
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
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   3427,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_MPA,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'NO'
                  AND coursetype = 'IET';
            --Reserve
            INSERT INTO crunch.Costs_RO
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
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   3461,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_MPA,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'RO'
                  AND coursetype = 'IET';
            -- ## OMA ##
            --Active
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
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   3395,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_OMA,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'AO'
                  AND coursetype = 'IET';
            --NG
            INSERT INTO crunch.Costs_NO
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
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   3429,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_OMA,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'NO'
                  AND coursetype = 'IET';
            --Reserve
            INSERT INTO crunch.Costs_RO
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
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   3455,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_OMA,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'RO'
                  AND coursetype = 'IET';
            -- ## Other ##
            --Active
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
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   3399,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_Other,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'AO'
                  AND coursetype = 'IET';
            --NG
            INSERT INTO crunch.Costs_NO
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
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   3431,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_Other,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'NO'
                  AND coursetype = 'IET';
            --Reserve
            INSERT INTO crunch.Costs_RO
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
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   3457,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_Other,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'RO'
                  AND coursetype = 'IET';



            -- ### Warrant ###
            -- ## MPA ##
            --Active
            INSERT INTO crunch.Costs_AWO
            (
                PayPlan,
                Branch,
                WOMOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   3403,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_MPA,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'AWO'
                  AND coursetype = 'IET';
            --NG
            INSERT INTO crunch.Costs_NWO
            (
                PayPlan,
                Branch,
                WOMOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   3435,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_MPA,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'NWO'
                  AND coursetype = 'IET';
            --Reserve
            INSERT INTO crunch.Costs_RWO
            (
                PayPlan,
                Branch,
                WOMOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   3469,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_MPA,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'RWO'
                  AND coursetype = 'IET';
            -- ## OMA ##
            --Active
            INSERT INTO crunch.Costs_AWO
            (
                PayPlan,
                Branch,
                WOMOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   3407,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_OMA,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'AWO'
                  AND coursetype = 'IET';
            --NG
            INSERT INTO crunch.Costs_NWO
            (
                PayPlan,
                Branch,
                WOMOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   3437,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_OMA,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'NWO'
                  AND coursetype = 'IET';
            --Reserve
            INSERT INTO crunch.Costs_RWO
            (
                PayPlan,
                Branch,
                WOMOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   3463,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_OMA,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'RWO'
                  AND coursetype = 'IET';
            -- ## Other ##
            --Active
            INSERT INTO crunch.Costs_AWO
            (
                PayPlan,
                Branch,
                WOMOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   3411,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_Other,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'AWO'
                  AND coursetype = 'IET';
            --NG
            INSERT INTO crunch.Costs_NWO
            (
                PayPlan,
                Branch,
                WOMOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   3439,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_Other,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'NWO'
                  AND coursetype = 'IET';
            --Reserve
            INSERT INTO crunch.Costs_RWO
            (
                PayPlan,
                Branch,
                WOMOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   3465,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_Other,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'RWO'
                  AND coursetype = 'IET';




            --##########################  Avg cost of Initial Skill Training #################################
            -- ### ENLISTED ###
            -- ## MPA ##
            --Active
            INSERT INTO crunch.Costs_AE
            (
                PayPlan,
                CMF,
                MOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   60,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_MPA,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'AE'
                  AND coursetype = 'AIT';
            --NG
            INSERT INTO crunch.Costs_NE
            (
                PayPlan,
                CMF,
                MOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   4095,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_MPA,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'NE'
                  AND coursetype = 'AIT';
            --Reserve
            INSERT INTO crunch.Costs_RE
            (
                PayPlan,
                CMF,
                MOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   4096,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_MPA,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'RE'
                  AND coursetype = 'AIT';
            -- ## OMA ##
            --Active
            INSERT INTO crunch.Costs_AE
            (
                PayPlan,
                CMF,
                MOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   95,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_OMA,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'AE'
                  AND coursetype = 'AIT';
            --NG
            INSERT INTO crunch.Costs_NE
            (
                PayPlan,
                CMF,
                MOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   4098,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_OMA,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'NE'
                  AND coursetype = 'AIT';
            --Reserve
            INSERT INTO crunch.Costs_RE
            (
                PayPlan,
                CMF,
                MOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   4099,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_OMA,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'RE'
                  AND coursetype = 'AIT';
            -- ## OMA_1 ##
            --Active
            INSERT INTO crunch.Costs_AE
            (
                PayPlan,
                CMF,
                MOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   114,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_Other,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'AE'
                  AND coursetype = 'AIT';
            --NG
            INSERT INTO crunch.Costs_NE
            (
                PayPlan,
                CMF,
                MOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   4100,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_Other,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'NE'
                  AND coursetype = 'AIT';
            --Reserve
            INSERT INTO crunch.Costs_RE
            (
                PayPlan,
                CMF,
                MOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   4101,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_Other,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'RE'
                  AND coursetype = 'AIT';

            --## RPA/NGPA ##
            --NG
            INSERT INTO crunch.Costs_NE
            (
                PayPlan,
                CMF,
                MOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   4097,
                   GradeType,
                   GradeLevel,
                   -1,
                   RPA_NGPA,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'NE'
                  AND coursetype = 'AIT';
            --Reserve
            INSERT INTO crunch.Costs_RE
            (
                PayPlan,
                CMF,
                MOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   4104,
                   GradeType,
                   GradeLevel,
                   -1,
                   RPA_NGPA,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'RE'
                  AND coursetype = 'AIT';
            --## OMAR/OMNG ##
            --NG
            INSERT INTO crunch.Costs_NE
            (
                PayPlan,
                CMF,
                MOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   4103,
                   GradeType,
                   GradeLevel,
                   -1,
                   OMAR_OMNG,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'NE'
                  AND coursetype = 'AIT';
            --Reserve
            INSERT INTO crunch.Costs_RE
            (
                PayPlan,
                CMF,
                MOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   4102,
                   GradeType,
                   GradeLevel,
                   -1,
                   OMAR_OMNG,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'RE'
                  AND coursetype = 'AIT';




            --##########################  Avg cost of Officer's Undergraduate Pilot Training #################################
            -- ### Officer ###
            -- ## MPA ##
            --Active
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
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   670,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_MPA,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'AO'
                  AND coursetype = 'F';
            --NG
            INSERT INTO crunch.Costs_NO
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
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   3029,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_MPA,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'NO'
                  AND coursetype = 'F';
            --Reserve
            INSERT INTO crunch.Costs_RO
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
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   673,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_MPA,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'RO'
                  AND coursetype = 'F';
            -- ## OMA ##
            --Active
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
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   671,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_OMA,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'AO'
                  AND coursetype = 'F';
            --NG
            INSERT INTO crunch.Costs_NO
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
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   3031,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_OMA,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'NO'
                  AND coursetype = 'F';
            --Reserve
            INSERT INTO crunch.Costs_RO
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
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   674,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_OMA,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'RO'
                  AND coursetype = 'F';
            -- ## OMA ##
            --Active
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
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   672,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_Other,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'AO'
                  AND coursetype = 'F';
            --NG
            INSERT INTO crunch.Costs_NO
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
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   3033,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_Other,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'NO'
                  AND coursetype = 'F';
            --Reserve
            INSERT INTO crunch.Costs_RO
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
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   675,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_Other,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'RO'
                  AND coursetype = 'F';

            -- ### Warrant ###
            -- ## MPA ##
            --Active
            INSERT INTO crunch.Costs_AWO
            (
                PayPlan,
                Branch,
                WOMOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   692,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_MPA,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'AWO'
                  AND coursetype = 'F';
            --NG
            INSERT INTO crunch.Costs_NWO
            (
                PayPlan,
                Branch,
                WOMOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   3041,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_MPA,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'NWO'
                  AND coursetype = 'F';
            --Reserve
            INSERT INTO crunch.Costs_RWO
            (
                PayPlan,
                Branch,
                WOMOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   3017,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_MPA,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'RWO'
                  AND coursetype = 'F';
            -- ## OMA ##
            --Active
            INSERT INTO crunch.Costs_AWO
            (
                PayPlan,
                Branch,
                WOMOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   693,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_OMA,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'AWO'
                  AND coursetype = 'F';
            --NG
            INSERT INTO crunch.Costs_NWO
            (
                PayPlan,
                Branch,
                WOMOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   3043,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_OMA,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'NWO'
                  AND coursetype = 'F';
            --Reserve
            INSERT INTO crunch.Costs_RWO
            (
                PayPlan,
                Branch,
                WOMOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   3019,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_OMA,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'RWO'
                  AND coursetype = 'F';
            -- ## OMA_1 ##
            --Active
            INSERT INTO crunch.Costs_AWO
            (
                PayPlan,
                Branch,
                WOMOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   694,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_Other,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'AWO'
                  AND coursetype = 'F';
            --NG
            INSERT INTO crunch.Costs_NWO
            (
                PayPlan,
                Branch,
                WOMOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   3045,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_Other,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'NWO'
                  AND coursetype = 'F';
            --Reserve
            INSERT INTO crunch.Costs_RWO
            (
                PayPlan,
                Branch,
                WOMOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   3021,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_Other,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'RWO'
                  AND coursetype = 'F';


            --##########################  Avg cost of One Station Unit Training #################################
            -- ### ENLISTED ###
            -- ## MPA ##
            --Active
            INSERT INTO crunch.Costs_AE
            (
                PayPlan,
                CMF,
                MOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   62,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_MPA,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'AE'
                  AND coursetype = 'OSUT';
            --NG
            INSERT INTO crunch.Costs_NE
            (
                PayPlan,
                CMF,
                MOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   4037,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_MPA,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'NE'
                  AND coursetype = 'OSUT';
            --Reserve
            INSERT INTO crunch.Costs_RE
            (
                PayPlan,
                CMF,
                MOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   4036,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_MPA,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'RE'
                  AND coursetype = 'OSUT';
            -- ## OMA ##
            --Active
            INSERT INTO crunch.Costs_AE
            (
                PayPlan,
                CMF,
                MOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   97,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_OMA,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'AE'
                  AND coursetype = 'OSUT';
            --NG
            INSERT INTO crunch.Costs_NE
            (
                PayPlan,
                CMF,
                MOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   4108,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_OMA,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'NE'
                  AND coursetype = 'OSUT';
            --Reserve
            INSERT INTO crunch.Costs_RE
            (
                PayPlan,
                CMF,
                MOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   4107,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_OMA,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'RE'
                  AND coursetype = 'OSUT';
            -- ## OMA_1 ##
            --Active
            INSERT INTO crunch.Costs_AE
            (
                PayPlan,
                CMF,
                MOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   116,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_Other,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'AE'
                  AND coursetype = 'OSUT';
            --NG
            INSERT INTO crunch.Costs_NE
            (
                PayPlan,
                CMF,
                MOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   4176,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_Other,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'NE'
                  AND coursetype = 'OSUT';
            --Reserve
            INSERT INTO crunch.Costs_RE
            (
                PayPlan,
                CMF,
                MOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   4175,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_Other,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'RE'
                  AND coursetype = 'OSUT';





            --##########################  Avg cost of Other Flight Training #################################
            -- ### Officer ###
            -- ## MPA ##
            --Active
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
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   649,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_MPA,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'AO'
                  AND coursetype = 'O';
            --NG
            INSERT INTO crunch.Costs_NO
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
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   3035,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_MPA,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'NO'
                  AND coursetype = 'O';
            --Reserve
            INSERT INTO crunch.Costs_RO
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
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   655,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_MPA,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'RO'
                  AND coursetype = 'O';
            -- ## OMA ##
            --Active
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
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   650,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_OMA,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'AO'
                  AND coursetype = 'O';
            --NG
            INSERT INTO crunch.Costs_NO
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
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   3037,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_OMA,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'NO'
                  AND coursetype = 'O';
            --Reserve
            INSERT INTO crunch.Costs_RO
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
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   656,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_OMA,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'RO'
                  AND coursetype = 'O';
            -- ## Other ##
            --Active
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
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   651,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_Other,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'AO'
                  AND coursetype = 'O';
            --NG
            INSERT INTO crunch.Costs_NO
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
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   3039,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_Other,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'NO'
                  AND coursetype = 'O';
            --Reserve
            INSERT INTO crunch.Costs_RO
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
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   657,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_Other,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'RO'
                  AND coursetype = 'O';

            -- ### Warrant ###
            -- ## MPA ##
            --Active
            INSERT INTO crunch.Costs_AWO
            (
                PayPlan,
                Branch,
                WOMOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   686,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_MPA,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'AWO'
                  AND coursetype = 'O';
            --NG
            INSERT INTO crunch.Costs_NWO
            (
                PayPlan,
                Branch,
                WOMOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   3047,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_MPA,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'NWO'
                  AND coursetype = 'O';
            --Reserve
            INSERT INTO crunch.Costs_RWO
            (
                PayPlan,
                Branch,
                WOMOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   3023,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_MPA,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'RWO'
                  AND coursetype = 'O';
            -- ## OMA ##
            --Active
            INSERT INTO crunch.Costs_AWO
            (
                PayPlan,
                Branch,
                WOMOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   687,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_OMA,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'AWO'
                  AND coursetype = 'O';
            --NG
            INSERT INTO crunch.Costs_NWO
            (
                PayPlan,
                Branch,
                WOMOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   3049,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_OMA,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'NWO'
                  AND coursetype = 'O';
            --Reserve
            INSERT INTO crunch.Costs_RWO
            (
                PayPlan,
                Branch,
                WOMOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   3025,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_OMA,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'RWO'
                  AND coursetype = 'O';
            -- ## Other ##
            --Active
            INSERT INTO crunch.Costs_AWO
            (
                PayPlan,
                Branch,
                WOMOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   688,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_Other,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'AWO'
                  AND coursetype = 'O';
            --NG
            INSERT INTO crunch.Costs_NWO
            (
                PayPlan,
                Branch,
                WOMOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   3051,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_Other,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'NWO'
                  AND coursetype = 'O';
            --Reserve
            INSERT INTO crunch.Costs_RWO
            (
                PayPlan,
                Branch,
                WOMOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   3027,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_Other,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'RWO'
                  AND coursetype = 'O';





            --##########################  Avg cost of Professional Training #################################
            -- ### ENLISTED ###
            --## RPA/NGPA ##
            --NG
            INSERT INTO crunch.Costs_NE
            (
                PayPlan,
                CMF,
                MOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   4162,
                   GradeType,
                   GradeLevel,
                   -1,
                   RPA_NGPA,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'NE'
                  AND coursetype = 'P';
            --Reserve
            INSERT INTO crunch.Costs_RE
            (
                PayPlan,
                CMF,
                MOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   4171,
                   GradeType,
                   GradeLevel,
                   -1,
                   RPA_NGPA,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'RE'
                  AND coursetype = 'P';
            --## OMAR/OMNG ##
            --NG
            INSERT INTO crunch.Costs_NE
            (
                PayPlan,
                CMF,
                MOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   4168,
                   GradeType,
                   GradeLevel,
                   -1,
                   OMAR_OMNG,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'NE'
                  AND coursetype = 'P';
            --Reserve
            INSERT INTO crunch.Costs_RE
            (
                PayPlan,
                CMF,
                MOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   4165,
                   GradeType,
                   GradeLevel,
                   -1,
                   OMAR_OMNG,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'RE'
                  AND coursetype = 'P';


            -- ## MPA ##
            --Active
            INSERT INTO crunch.Costs_AE
            (
                PayPlan,
                CMF,
                MOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   3379,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_MPA,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'AE'
                  AND coursetype = 'P';
            --NG
            INSERT INTO crunch.Costs_NE
            (
                PayPlan,
                CMF,
                MOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   3423,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_MPA,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'NE'
                  AND coursetype = 'P';
            --Reserve
            INSERT INTO crunch.Costs_RE
            (
                PayPlan,
                CMF,
                MOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   3451,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_MPA,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'RE'
                  AND coursetype = 'P';
            -- ## OMA ##
            --Active
            INSERT INTO crunch.Costs_AE
            (
                PayPlan,
                CMF,
                MOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   3383,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_OMA,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'AE'
                  AND coursetype = 'P';
            --NG
            INSERT INTO crunch.Costs_NE
            (
                PayPlan,
                CMF,
                MOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   3415,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_OMA,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'NE'
                  AND coursetype = 'P';
            --Reserve
            INSERT INTO crunch.Costs_RE
            (
                PayPlan,
                CMF,
                MOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   3443,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_OMA,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'RE'
                  AND coursetype = 'P';
            -- ## OMA_1 ##
            --Active
            INSERT INTO crunch.Costs_AE
            (
                PayPlan,
                CMF,
                MOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   3387,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_Other,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'AE'
                  AND coursetype = 'P';
            --NG
            INSERT INTO crunch.Costs_NE
            (
                PayPlan,
                CMF,
                MOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   3419,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_Other,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'NE'
                  AND coursetype = 'P';
            --Reserve
            INSERT INTO crunch.Costs_RE
            (
                PayPlan,
                CMF,
                MOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   3447,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_Other,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'RE'
                  AND coursetype = 'P';

            -- ### Officer ###
            --## RPA/NGPA ##
            --NG
            INSERT INTO crunch.Costs_NO
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
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   4161,
                   GradeType,
                   GradeLevel,
                   -1,
                   RPA_NGPA,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'NO'
                  AND coursetype = 'P';
            --Reserve
            INSERT INTO crunch.Costs_RO
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
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   4170,
                   GradeType,
                   GradeLevel,
                   -1,
                   RPA_NGPA,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'RO'
                  AND coursetype = 'P';
            --## OMAR/OMNG ##
            --NG
            INSERT INTO crunch.Costs_NO
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
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   4167,
                   GradeType,
                   GradeLevel,
                   -1,
                   OMAR_OMNG,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'NO'
                  AND coursetype = 'P';
            --Reserve
            INSERT INTO crunch.Costs_RO
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
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   4164,
                   GradeType,
                   GradeLevel,
                   -1,
                   OMAR_OMNG,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'RO'
                  AND coursetype = 'P';


            -- ## MPA ##
            --Active
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
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   165,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_MPA,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'AO'
                  AND coursetype = 'P';
            --NG
            INSERT INTO crunch.Costs_NO
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
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   404,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_MPA,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'NO'
                  AND coursetype = 'P';
            --Reserve
            INSERT INTO crunch.Costs_RO
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
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   568,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_MPA,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'RO'
                  AND coursetype = 'P';
            -- ## OMA ##
            --Active
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
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   186,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_OMA,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'AO'
                  AND coursetype = 'P';
            --NG
            INSERT INTO crunch.Costs_NO
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
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   371,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_OMA,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'NO'
                  AND coursetype = 'P';
            --Reserve
            INSERT INTO crunch.Costs_RO
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
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   535,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_OMA,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'RO'
                  AND coursetype = 'P';
            -- ## OMA_1 ##
            --Active
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
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   196,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_Other,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'AO'
                  AND coursetype = 'P';
            --NG
            INSERT INTO crunch.Costs_NO
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
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   380,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_Other,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'NO'
                  AND coursetype = 'P';
            --Reserve
            INSERT INTO crunch.Costs_RO
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
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   544,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_Other,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'RO'
                  AND coursetype = 'P';

            -- ### Warrant ###
            --## RPA/NGPA ##
            --NG
            INSERT INTO crunch.Costs_NWO
            (
                PayPlan,
                Branch,
                WOMOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   4163,
                   GradeType,
                   GradeLevel,
                   -1,
                   RPA_NGPA,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'NWO'
                  AND coursetype = 'P';
            --Reserve
            INSERT INTO crunch.Costs_RWO
            (
                PayPlan,
                Branch,
                WOMOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   4172,
                   GradeType,
                   GradeLevel,
                   -1,
                   RPA_NGPA,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'RWO'
                  AND coursetype = 'P';
            --## OMAR/OMNG ##
            --NG
            INSERT INTO crunch.Costs_NWO
            (
                PayPlan,
                Branch,
                WOMOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   4169,
                   GradeType,
                   GradeLevel,
                   -1,
                   OMAR_OMNG,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'NWO'
                  AND coursetype = 'P';
            --Reserve
            INSERT INTO crunch.Costs_RWO
            (
                PayPlan,
                Branch,
                WOMOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   4166,
                   GradeType,
                   GradeLevel,
                   -1,
                   OMAR_OMNG,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'RWO'
                  AND coursetype = 'P';

            -- ## MPA ##
            --Active
            INSERT INTO crunch.Costs_AWO
            (
                PayPlan,
                Branch,
                WOMOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   239,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_MPA,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'AWO'
                  AND coursetype = 'P';
            --NG
            INSERT INTO crunch.Costs_NWO
            (
                PayPlan,
                Branch,
                WOMOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   444,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_MPA,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'NWO'
                  AND coursetype = 'P';
            --Reserve
            INSERT INTO crunch.Costs_RWO
            (
                PayPlan,
                Branch,
                WOMOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   608,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_MPA,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'RWO'
                  AND coursetype = 'P';
            -- ## OMA ##
            --Active
            INSERT INTO crunch.Costs_AWO
            (
                PayPlan,
                Branch,
                WOMOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   254,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_OMA,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'AWO'
                  AND coursetype = 'P';
            --NG
            INSERT INTO crunch.Costs_NWO
            (
                PayPlan,
                Branch,
                WOMOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   422,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_OMA,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'NWO'
                  AND coursetype = 'P';
            --Reserve
            INSERT INTO crunch.Costs_RWO
            (
                PayPlan,
                Branch,
                WOMOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   586,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_OMA,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'RWO'
                  AND coursetype = 'P';
            -- ## OMA ##
            --Active
            INSERT INTO crunch.Costs_AWO
            (
                PayPlan,
                Branch,
                WOMOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   267,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_Other,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'AWO'
                  AND coursetype = 'P';
            --NG
            INSERT INTO crunch.Costs_NWO
            (
                PayPlan,
                Branch,
                WOMOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   431,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_Other,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'NWO'
                  AND coursetype = 'P';
            --Reserve
            INSERT INTO crunch.Costs_RWO
            (
                PayPlan,
                Branch,
                WOMOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   595,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_Other,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'RWO'
                  AND coursetype = 'P';





            --##########################  Actual cost of Weapon System Training #################################
            -- ### ENLISTED ###
            -- ## MPA ##
            --Active
            INSERT INTO crunch.Costs_AE
            (
                PayPlan,
                CMF,
                MOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   3381,
                   GradeType,
                   GradeLevel,
                   WeaponSystemId,
                   CGLA_MPA,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'AE'
                  AND coursetype = 'W';
            --NG
            INSERT INTO crunch.Costs_NE
            (
                PayPlan,
                CMF,
                MOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   3417,
                   GradeType,
                   GradeLevel,
                   WeaponSystemId,
                   CGLA_MPA,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'NE'
                  AND coursetype = 'W';
            --Reserve
            INSERT INTO crunch.Costs_RE
            (
                PayPlan,
                CMF,
                MOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   3453,
                   GradeType,
                   GradeLevel,
                   WeaponSystemId,
                   CGLA_MPA,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'RE'
                  AND coursetype = 'W';
            -- ## OMA ##
            --Active
            INSERT INTO crunch.Costs_AE
            (
                PayPlan,
                CMF,
                MOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   3385,
                   GradeType,
                   GradeLevel,
                   WeaponSystemId,
                   CGLA_OMA,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'AE'
                  AND coursetype = 'W';
            --NG
            INSERT INTO crunch.Costs_NE
            (
                PayPlan,
                CMF,
                MOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   3421,
                   GradeType,
                   GradeLevel,
                   WeaponSystemId,
                   CGLA_OMA,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'NE'
                  AND coursetype = 'W';
            --Reserve
            INSERT INTO crunch.Costs_RE
            (
                PayPlan,
                CMF,
                MOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   3445,
                   GradeType,
                   GradeLevel,
                   WeaponSystemId,
                   CGLA_OMA,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'RE'
                  AND coursetype = 'W';
            -- ## OMA_1 ##
            --Active
            INSERT INTO crunch.Costs_AE
            (
                PayPlan,
                CMF,
                MOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   3389,
                   GradeType,
                   GradeLevel,
                   WeaponSystemId,
                   CGLA_Other,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'AE'
                  AND coursetype = 'W';
            --NG
            INSERT INTO crunch.Costs_NE
            (
                PayPlan,
                CMF,
                MOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   3425,
                   GradeType,
                   GradeLevel,
                   WeaponSystemId,
                   CGLA_Other,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'NE'
                  AND coursetype = 'W';
            --Reserve
            INSERT INTO crunch.Costs_RE
            (
                PayPlan,
                CMF,
                MOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   3449,
                   GradeType,
                   GradeLevel,
                   WeaponSystemId,
                   CGLA_Other,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'RE'
                  AND coursetype = 'W';

            -- ### Officer ###
            -- ## MPA ##
            --Active
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
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   3393,
                   GradeType,
                   GradeLevel,
                   WeaponSystemId,
                   CGLA_MPA,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'AO'
                  AND coursetype = 'W';
            --NG
            INSERT INTO crunch.Costs_NO
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
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   3471,
                   GradeType,
                   GradeLevel,
                   WeaponSystemId,
                   CGLA_MPA,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'NO'
                  AND coursetype = 'W';
            --Reserve
            INSERT INTO crunch.Costs_RO
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
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   3479,
                   GradeType,
                   GradeLevel,
                   WeaponSystemId,
                   CGLA_MPA,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'RO'
                  AND coursetype = 'W';
            -- ## OMA ##
            --Active
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
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   3397,
                   GradeType,
                   GradeLevel,
                   WeaponSystemId,
                   CGLA_OMA,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'AO'
                  AND coursetype = 'W';
            --NG
            INSERT INTO crunch.Costs_NO
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
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   3472,
                   GradeType,
                   GradeLevel,
                   WeaponSystemId,
                   CGLA_OMA,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'NO'
                  AND coursetype = 'W';
            --Reserve
            INSERT INTO crunch.Costs_RO
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
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   3480,
                   GradeType,
                   GradeLevel,
                   WeaponSystemId,
                   CGLA_OMA,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'RO'
                  AND coursetype = 'W';
            -- ## OMA_1 ##
            --Active
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
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   3401,
                   GradeType,
                   GradeLevel,
                   WeaponSystemId,
                   CGLA_Other,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'AO'
                  AND coursetype = 'W';
            --NG
            INSERT INTO crunch.Costs_NO
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
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   3433,
                   GradeType,
                   GradeLevel,
                   WeaponSystemId,
                   CGLA_Other,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'NO'
                  AND coursetype = 'W';
            --Reserve
            INSERT INTO crunch.Costs_RO
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
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   3459,
                   GradeType,
                   GradeLevel,
                   WeaponSystemId,
                   CGLA_Other,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'RO'
                  AND coursetype = 'W';

            -- ### Warrant ###
            -- ## MPA ##
            --Active
            INSERT INTO crunch.Costs_AWO
            (
                PayPlan,
                Branch,
                WOMOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   3405,
                   GradeType,
                   GradeLevel,
                   WeaponSystemId,
                   CGLA_MPA,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'AWO'
                  AND coursetype = 'W';
            --NG
            INSERT INTO crunch.Costs_NWO
            (
                PayPlan,
                Branch,
                WOMOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   3475,
                   GradeType,
                   GradeLevel,
                   WeaponSystemId,
                   CGLA_MPA,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'NWO'
                  AND coursetype = 'W';
            --Reserve
            INSERT INTO crunch.Costs_RWO
            (
                PayPlan,
                Branch,
                WOMOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   3483,
                   GradeType,
                   GradeLevel,
                   WeaponSystemId,
                   CGLA_MPA,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'RWO'
                  AND coursetype = 'W';
            -- ## OMA ##
            --Active
            INSERT INTO crunch.Costs_AWO
            (
                PayPlan,
                Branch,
                WOMOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   3409,
                   GradeType,
                   GradeLevel,
                   WeaponSystemId,
                   CGLA_OMA,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'AWO'
                  AND coursetype = 'W';
            --NG
            INSERT INTO crunch.Costs_NWO
            (
                PayPlan,
                Branch,
                WOMOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   3476,
                   GradeType,
                   GradeLevel,
                   WeaponSystemId,
                   CGLA_OMA,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'NWO'
                  AND coursetype = 'W';
            --Reserve
            INSERT INTO crunch.Costs_RWO
            (
                PayPlan,
                Branch,
                WOMOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   3484,
                   GradeType,
                   GradeLevel,
                   WeaponSystemId,
                   CGLA_OMA,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'RWO'
                  AND coursetype = 'W';
            -- ## OMA_1 ##
            --Active
            INSERT INTO crunch.Costs_AWO
            (
                PayPlan,
                Branch,
                WOMOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   3413,
                   GradeType,
                   GradeLevel,
                   WeaponSystemId,
                   CGLA_Other,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'AWO'
                  AND coursetype = 'W';
            --NG
            INSERT INTO crunch.Costs_NWO
            (
                PayPlan,
                Branch,
                WOMOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   3441,
                   GradeType,
                   GradeLevel,
                   WeaponSystemId,
                   CGLA_Other,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'NWO'
                  AND coursetype = 'W';
            --Reserve
            INSERT INTO crunch.Costs_RWO
            (
                PayPlan,
                Branch,
                WOMOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   3467,
                   GradeType,
                   GradeLevel,
                   WeaponSystemId,
                   CGLA_Other,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'RWO'
                  AND coursetype = 'W';



            --##########################  Avg cost of Training #################################
            -- ### ENLISTED ###
            --## RPA/NGPA ##
            --NG
            INSERT INTO crunch.Costs_NE
            (
                PayPlan,
                CMF,
                MOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   4177,
                   GradeType,
                   GradeLevel,
                   -1,
                   SUM(RPA_NGPA),
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'NE'
            GROUP BY PayPlan,
                     CategoryGroupCode,
                     CategorySubGroupCode,
                     GradeType,
                     GradeLevel;
            --Reserve
            INSERT INTO crunch.Costs_RE
            (
                PayPlan,
                CMF,
                MOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   4186,
                   GradeType,
                   GradeLevel,
                   -1,
                   SUM(RPA_NGPA),
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'RE'
            GROUP BY PayPlan,
                     CategoryGroupCode,
                     CategorySubGroupCode,
                     GradeType,
                     GradeLevel;
            --## OMAR/OMNG ##
            --NG
            INSERT INTO crunch.Costs_NE
            (
                PayPlan,
                CMF,
                MOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   4183,
                   GradeType,
                   GradeLevel,
                   -1,
                   SUM(OMAR_OMNG),
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'NE'
            GROUP BY PayPlan,
                     CategoryGroupCode,
                     CategorySubGroupCode,
                     GradeType,
                     GradeLevel;
            --Reserve
            INSERT INTO crunch.Costs_RE
            (
                PayPlan,
                CMF,
                MOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   4180,
                   GradeType,
                   GradeLevel,
                   -1,
                   SUM(OMAR_OMNG),
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'RE'
            GROUP BY PayPlan,
                     CategoryGroupCode,
                     CategorySubGroupCode,
                     GradeType,
                     GradeLevel;


            -- ## MPA ##
            --Active
            INSERT INTO crunch.Costs_AE
            (
                PayPlan,
                CMF,
                MOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   65,
                   GradeType,
                   GradeLevel,
                   -1,
                   SUM(CGLA_MPA),
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'AE'
            GROUP BY PayPlan,
                     CategoryGroupCode,
                     CategorySubGroupCode,
                     GradeType,
                     GradeLevel;
            --NG
            INSERT INTO crunch.Costs_NE
            (
                PayPlan,
                CMF,
                MOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   352,
                   GradeType,
                   GradeLevel,
                   -1,
                   SUM(CGLA_MPA),
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'NE'
            GROUP BY PayPlan,
                     CategoryGroupCode,
                     CategorySubGroupCode,
                     GradeType,
                     GradeLevel;
            --Reserve
            INSERT INTO crunch.Costs_RE
            (
                PayPlan,
                CMF,
                MOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   516,
                   GradeType,
                   GradeLevel,
                   -1,
                   SUM(CGLA_MPA),
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'RE'
            GROUP BY PayPlan,
                     CategoryGroupCode,
                     CategorySubGroupCode,
                     GradeType,
                     GradeLevel;
            -- ## OMA ##
            --Active
            INSERT INTO crunch.Costs_AE
            (
                PayPlan,
                CMF,
                MOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   100,
                   GradeType,
                   GradeLevel,
                   -1,
                   SUM(CGLA_OMA),
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'AE'
            GROUP BY PayPlan,
                     CategoryGroupCode,
                     CategorySubGroupCode,
                     GradeType,
                     GradeLevel;
            --NG
            INSERT INTO crunch.Costs_NE
            (
                PayPlan,
                CMF,
                MOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   313,
                   GradeType,
                   GradeLevel,
                   -1,
                   SUM(CGLA_OMA),
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'NE'
            GROUP BY PayPlan,
                     CategoryGroupCode,
                     CategorySubGroupCode,
                     GradeType,
                     GradeLevel;
            --Reserve
            INSERT INTO crunch.Costs_RE
            (
                PayPlan,
                CMF,
                MOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   477,
                   GradeType,
                   GradeLevel,
                   -1,
                   SUM(CGLA_OMA),
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'RE'
            GROUP BY PayPlan,
                     CategoryGroupCode,
                     CategorySubGroupCode,
                     GradeType,
                     GradeLevel;
            -- ## OMA_1 ##
            --Active
            INSERT INTO crunch.Costs_AE
            (
                PayPlan,
                CMF,
                MOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   119,
                   GradeType,
                   GradeLevel,
                   -1,
                   SUM(CGLA_Other),
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'AE'
            GROUP BY PayPlan,
                     CategoryGroupCode,
                     CategorySubGroupCode,
                     GradeType,
                     GradeLevel;
            --NG
            INSERT INTO crunch.Costs_NE
            (
                PayPlan,
                CMF,
                MOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   322,
                   GradeType,
                   GradeLevel,
                   -1,
                   SUM(CGLA_Other),
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'NE'
            GROUP BY PayPlan,
                     CategoryGroupCode,
                     CategorySubGroupCode,
                     GradeType,
                     GradeLevel;
            --Reserve
            INSERT INTO crunch.Costs_RE
            (
                PayPlan,
                CMF,
                MOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   486,
                   GradeType,
                   GradeLevel,
                   -1,
                   SUM(CGLA_Other),
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'RE'
            GROUP BY PayPlan,
                     CategoryGroupCode,
                     CategorySubGroupCode,
                     GradeType,
                     GradeLevel;

            -- ### OFFICER ###
            --## RPA/NGPA ##
            --NG
            INSERT INTO crunch.Costs_NO
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
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   4178,
                   GradeType,
                   GradeLevel,
                   -1,
                   SUM(RPA_NGPA),
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'NO'
            GROUP BY PayPlan,
                     CategoryGroupCode,
                     CategorySubGroupCode,
                     GradeType,
                     GradeLevel;
            --Reserve
            INSERT INTO crunch.Costs_RO
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
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   4187,
                   GradeType,
                   GradeLevel,
                   -1,
                   SUM(RPA_NGPA),
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'RO'
            GROUP BY PayPlan,
                     CategoryGroupCode,
                     CategorySubGroupCode,
                     GradeType,
                     GradeLevel;
            --## OMAR/OMNG ##
            --NG
            INSERT INTO crunch.Costs_NO
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
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   4184,
                   GradeType,
                   GradeLevel,
                   -1,
                   SUM(OMAR_OMNG),
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'NO'
            GROUP BY PayPlan,
                     CategoryGroupCode,
                     CategorySubGroupCode,
                     GradeType,
                     GradeLevel;
            --Reserve
            INSERT INTO crunch.Costs_RO
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
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   4181,
                   GradeType,
                   GradeLevel,
                   -1,
                   SUM(OMAR_OMNG),
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'RO'
            GROUP BY PayPlan,
                     CategoryGroupCode,
                     CategorySubGroupCode,
                     GradeType,
                     GradeLevel;


            -- ## MPA ##
            --Active
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
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   167,
                   GradeType,
                   GradeLevel,
                   -1,
                   SUM(CGLA_MPA),
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'AO'
            GROUP BY PayPlan,
                     CategoryGroupCode,
                     CategorySubGroupCode,
                     GradeType,
                     GradeLevel;
            --NG
            INSERT INTO crunch.Costs_NO
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
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   406,
                   GradeType,
                   GradeLevel,
                   -1,
                   SUM(CGLA_MPA),
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'NO'
            GROUP BY PayPlan,
                     CategoryGroupCode,
                     CategorySubGroupCode,
                     GradeType,
                     GradeLevel;
            --Reserve
            INSERT INTO crunch.Costs_RO
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
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   570,
                   GradeType,
                   GradeLevel,
                   -1,
                   SUM(CGLA_MPA),
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'RO'
            GROUP BY PayPlan,
                     CategoryGroupCode,
                     CategorySubGroupCode,
                     GradeType,
                     GradeLevel;
            -- ## OMA ##
            --Active
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
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   188,
                   GradeType,
                   GradeLevel,
                   -1,
                   SUM(CGLA_OMA),
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'AO'
            GROUP BY PayPlan,
                     CategoryGroupCode,
                     CategorySubGroupCode,
                     GradeType,
                     GradeLevel;
            --NG
            INSERT INTO crunch.Costs_NO
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
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   373,
                   GradeType,
                   GradeLevel,
                   -1,
                   SUM(CGLA_OMA),
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'NO'
            GROUP BY PayPlan,
                     CategoryGroupCode,
                     CategorySubGroupCode,
                     GradeType,
                     GradeLevel;
            --Reserve
            INSERT INTO crunch.Costs_RO
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
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   537,
                   GradeType,
                   GradeLevel,
                   -1,
                   SUM(CGLA_OMA),
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'RO'
            GROUP BY PayPlan,
                     CategoryGroupCode,
                     CategorySubGroupCode,
                     GradeType,
                     GradeLevel;
            -- ## OMA_1 ##
            --Active
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
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   198,
                   GradeType,
                   GradeLevel,
                   -1,
                   SUM(CGLA_Other),
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'AO'
            GROUP BY PayPlan,
                     CategoryGroupCode,
                     CategorySubGroupCode,
                     GradeType,
                     GradeLevel;
            --NG
            INSERT INTO crunch.Costs_NO
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
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   382,
                   GradeType,
                   GradeLevel,
                   -1,
                   SUM(CGLA_Other),
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'NO'
            GROUP BY PayPlan,
                     CategoryGroupCode,
                     CategorySubGroupCode,
                     GradeType,
                     GradeLevel;
            --Reserve
            INSERT INTO crunch.Costs_RO
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
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   546,
                   GradeType,
                   GradeLevel,
                   -1,
                   SUM(CGLA_Other),
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'RO'
            GROUP BY PayPlan,
                     CategoryGroupCode,
                     CategorySubGroupCode,
                     GradeType,
                     GradeLevel;

            -- ### Warrant ###
            --## RPA/NGPA ##
            --NG
            INSERT INTO crunch.Costs_NWO
            (
                PayPlan,
                Branch,
                WOMOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   4179,
                   GradeType,
                   GradeLevel,
                   -1,
                   SUM(RPA_NGPA),
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'NWO'
            GROUP BY PayPlan,
                     CategoryGroupCode,
                     CategorySubGroupCode,
                     GradeType,
                     GradeLevel;
            --Reserve
            INSERT INTO crunch.Costs_RWO
            (
                PayPlan,
                Branch,
                WOMOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   4188,
                   GradeType,
                   GradeLevel,
                   -1,
                   SUM(RPA_NGPA),
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'RWO'
            GROUP BY PayPlan,
                     CategoryGroupCode,
                     CategorySubGroupCode,
                     GradeType,
                     GradeLevel;
            --## OMAR/OMNG ##
            --NG
            INSERT INTO crunch.Costs_NWO
            (
                PayPlan,
                Branch,
                WOMOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   4185,
                   GradeType,
                   GradeLevel,
                   -1,
                   SUM(OMAR_OMNG),
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'NWO'
            GROUP BY PayPlan,
                     CategoryGroupCode,
                     CategorySubGroupCode,
                     GradeType,
                     GradeLevel;
            --Reserve
            INSERT INTO crunch.Costs_RWO
            (
                PayPlan,
                Branch,
                WOMOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   4182,
                   GradeType,
                   GradeLevel,
                   -1,
                   SUM(OMAR_OMNG),
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'RWO'
            GROUP BY PayPlan,
                     CategoryGroupCode,
                     CategorySubGroupCode,
                     GradeType,
                     GradeLevel;


            -- ## MPA ##
            --Active
            INSERT INTO crunch.Costs_AWO
            (
                PayPlan,
                Branch,
                WOMOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   241,
                   GradeType,
                   GradeLevel,
                   -1,
                   SUM(CGLA_MPA),
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'AWO'
            GROUP BY PayPlan,
                     CategoryGroupCode,
                     CategorySubGroupCode,
                     GradeType,
                     GradeLevel;
            --NG
            INSERT INTO crunch.Costs_NWO
            (
                PayPlan,
                Branch,
                WOMOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   446,
                   GradeType,
                   GradeLevel,
                   -1,
                   SUM(CGLA_MPA),
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'NWO'
            GROUP BY PayPlan,
                     CategoryGroupCode,
                     CategorySubGroupCode,
                     GradeType,
                     GradeLevel;
            --Reserve
            INSERT INTO crunch.Costs_RWO
            (
                PayPlan,
                Branch,
                WOMOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   610,
                   GradeType,
                   GradeLevel,
                   -1,
                   SUM(CGLA_MPA),
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'RWO'
            GROUP BY PayPlan,
                     CategoryGroupCode,
                     CategorySubGroupCode,
                     GradeType,
                     GradeLevel;
            -- ## OMA ##
            --Active
            INSERT INTO crunch.Costs_AWO
            (
                PayPlan,
                Branch,
                WOMOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   256,
                   GradeType,
                   GradeLevel,
                   -1,
                   SUM(CGLA_OMA),
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'AWO'
            GROUP BY PayPlan,
                     CategoryGroupCode,
                     CategorySubGroupCode,
                     GradeType,
                     GradeLevel;
            --NG
            INSERT INTO crunch.Costs_NWO
            (
                PayPlan,
                Branch,
                WOMOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   424,
                   GradeType,
                   GradeLevel,
                   -1,
                   SUM(CGLA_OMA),
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'NWO'
            GROUP BY PayPlan,
                     CategoryGroupCode,
                     CategorySubGroupCode,
                     GradeType,
                     GradeLevel;
            --Reserve
            INSERT INTO crunch.Costs_RWO
            (
                PayPlan,
                Branch,
                WOMOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   588,
                   GradeType,
                   GradeLevel,
                   -1,
                   SUM(CGLA_OMA),
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'RWO'
            GROUP BY PayPlan,
                     CategoryGroupCode,
                     CategorySubGroupCode,
                     GradeType,
                     GradeLevel;
            -- ## OMA_1 ##
            --Active
            INSERT INTO crunch.Costs_AWO
            (
                PayPlan,
                Branch,
                WOMOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   269,
                   GradeType,
                   GradeLevel,
                   -1,
                   SUM(CGLA_Other),
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'AWO'
            GROUP BY PayPlan,
                     CategoryGroupCode,
                     CategorySubGroupCode,
                     GradeType,
                     GradeLevel;
            --NG
            INSERT INTO crunch.Costs_NWO
            (
                PayPlan,
                Branch,
                WOMOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   433,
                   GradeType,
                   GradeLevel,
                   -1,
                   SUM(CGLA_Other),
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'NWO'
            GROUP BY PayPlan,
                     CategoryGroupCode,
                     CategorySubGroupCode,
                     GradeType,
                     GradeLevel;
            --Reserve
            INSERT INTO crunch.Costs_RWO
            (
                PayPlan,
                Branch,
                WOMOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   597,
                   GradeType,
                   GradeLevel,
                   -1,
                   SUM(CGLA_Other),
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'RWO'
            GROUP BY PayPlan,
                     CategoryGroupCode,
                     CategorySubGroupCode,
                     GradeType,
                     GradeLevel;

            INSERT INTO crunch.Costs_NO
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
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   4208,
                   GradeType,
                   GradeLevel,
                   -1,
                   RPA_NGPA,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'NO'
                  AND coursetype = 'IET';

            INSERT INTO crunch.Costs_NO
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
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   4210,
                   GradeType,
                   GradeLevel,
                   -1,
                   OMAR_OMNG,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'NO'
                  AND coursetype = 'IET';

            INSERT INTO crunch.Costs_NWO
            (
                PayPlan,
                Branch,
                WOMOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   4209,
                   GradeType,
                   GradeLevel,
                   -1,
                   RPA_NGPA,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'NWO'
                  AND coursetype = 'IET';

            INSERT INTO crunch.Costs_NWO
            (
                PayPlan,
                Branch,
                WOMOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   4211,
                   GradeType,
                   GradeLevel,
                   -1,
                   OMAR_OMNG,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'NWO'
                  AND coursetype = 'IET';

            INSERT INTO crunch.Costs_RO
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
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   4204,
                   GradeType,
                   GradeLevel,
                   -1,
                   RPA_NGPA,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'RO'
                  AND coursetype = 'IET';

            INSERT INTO crunch.Costs_RO
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
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   4206,
                   GradeType,
                   GradeLevel,
                   -1,
                   OMAR_OMNG,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'RO'
                  AND coursetype = 'IET';

            INSERT INTO crunch.Costs_RWO
            (
                PayPlan,
                Branch,
                WOMOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   4205,
                   GradeType,
                   GradeLevel,
                   -1,
                   RPA_NGPA,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'RWO'
                  AND coursetype = 'IET';

            INSERT INTO crunch.Costs_RWO
            (
                PayPlan,
                Branch,
                WOMOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubGroupCode,
                   4207,
                   GradeType,
                   GradeLevel,
                   -1,
                   OMAR_OMNG,
                   @CrunchTime
            FROM crunch.TempTraining_Costs
            WHERE PayPlan = 'RWO'
                  AND coursetype = 'IET';

        END;
    END;


--this is a relic, leaving it in here just for reference as we finalize the SP

--DELETE FROM crunch. PreCrunchCosts WHERE costelementcategory LIKE '%Training Costs%' 

--DECLARE @binname AS NVARCHAR(10) = 'proposed'

--INSERT INTO crunch.PreCrunchCosts
--SELECT * 
--FROM
--(
--select @binname as bin, payplan, categorygroupcode as cmf, categorysubgroupcode as aoc, 'MPA' as 'Appropriation', 'Training Costs' as category, coursetype as 'CEname', gradetype, gradelevel , cgla_mpa as Amount from crunch.TempTraining_Costs
--union
--select @binname as bin, payplan, categorygroupcode as cmf, categorysubgroupcode as aoc, 'OMA' as 'Appropriation', 'Training Costs' as category, coursetype as 'CEname', gradetype, gradelevel , cgla_oma as Amount from crunch.TempTraining_Costs
--union
--select @binname as bin, payplan, categorygroupcode as cmf, categorysubgroupcode as aoc, 'Other' as 'Appropriation', 'Training Costs' as category, coursetype as 'CEname', gradetype, gradelevel , cgla_other as Amount from crunch.TempTraining_Costs
--union
--select @binname as bin, payplan, categorygroupcode as cmf, categorysubgroupcode as aoc, 'MPA' as 'Appropriation', 'Training Costs' as category,  'Avg Cost of Training' as 'CEname', gradetype, gradelevel , sum(cgla_mpa) as Amount
-- from crunch.TempTraining_Costs
-- group by payplan, categorygroupcode, categorysubgroupcode,  gradetype, gradelevel

-- union
--select @binname as bin, payplan, categorygroupcode as cmf, categorysubgroupcode as aoc, 'OMA' as 'Appropriation', 'Training Costs' as category,  'Avg Cost of Training' as 'CEname', gradetype, gradelevel , sum(cgla_oma) as Amount
-- from crunch.TempTraining_Costs
-- group by payplan, categorygroupcode, categorysubgroupcode,  gradetype, gradelevel

-- union
--select @binname as bin, payplan, categorygroupcode as cmf, categorysubgroupcode as aoc, 'Other' as 'Appropriation', 'Training Costs' as category,  'Avg Cost of Training' as 'CEname', gradetype, gradelevel , sum(cgla_other) as Amount
-- from crunch.TempTraining_Costs
-- group by payplan, categorygroupcode, categorysubgroupcode,  gradetype, gradelevel
-- ) 

-- AS a 
END;