
-- =============================================
-- Author:Dan Hogan	
-- Create date: July 2018
-- Description:	Training calculation to replace amortization
-- 8/5/2019 - adjusted due to finding the following errors
--      adjusted the calculation to add a sum before average costs were computed

-- =============================================

CREATE PROCEDURE [crunch].[CostOfTraining]
    @AmcosVersionId INT = -1,
    @CrunchTime AS SMALLDATETIME = NULL,
    @Debug AS BIT = 0
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @MessageText NVARCHAR(100);
    DECLARE @IsValidAmcosVersion BIT = crunch.ValidateAmcosVersion(@AmcosVersionId);
    IF (@IsValidAmcosVersion = 0)
        RETURN 0;
    IF (@CrunchTime IS NULL)
        SET @CrunchTime = CONVERT(SMALLDATETIME, GETDATE());

    TRUNCATE TABLE crunch_temp.ATRM;
    TRUNCATE TABLE crunch_temp.ATRRS;
    TRUNCATE TABLE crunch_temp.Training_xwalk_atrrs_atrm;
    TRUNCATE TABLE crunch_temp.Training_xwalk_atrrs_crstype_mos;
    TRUNCATE TABLE crunch_temp.ATRRSOfficerBranchCodes;
    TRUNCATE TABLE crunch_temp.MilitaryConversions;
    TRUNCATE TABLE crunch_temp.ATRRS_ATRM_Raw;
    TRUNCATE TABLE crunch_temp.AtrrsAtrmCourseMos;
    TRUNCATE TABLE crunch_temp.TrainingCostsByVersion;
    TRUNCATE TABLE crunch_temp.TrainingCostsAverage;
    TRUNCATE TABLE crunch_temp.TrainingCosts;

    INSERT INTO crunch_temp.ATRM
    (
        SchoolCode,
        CourseNumber,
        CourseTitle,
        CourseLengthWeeks,
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
              WHERE AmcosVersionId <= @AmcosVersionId
              GROUP BY AmcosVersionId
              ORDER BY AmcosVersionId DESC
          );
    INSERT INTO crunch_temp.ATRRS
    (
        CPBRANCH,
        SchoolCode,
        SchoolName,
        CRSPH,
        CourseTitle,
        PGRAD,
        PMOSEN4,
        CRMGOF,
        CRSTYPE,
        NumberOfStudents,
        AmcosVersionId
    )
    SELECT CPBRANCH,
           SchoolCode,
           SchoolName,
           CourseNumber,
           CourseTitle,
           PGRAD,
           PMOSEN4,
           CRMGOF,
           CRSTYPE,
           NumberOfStudents,
           AmcosVersionId
    FROM load_training.ATRRS
    WHERE AmcosVersionId IN
          (
              SELECT TOP (3)
                     AmcosVersionId
              FROM load_training.ATRM
              WHERE AmcosVersionId <= @AmcosVersionId
              GROUP BY AmcosVersionId
              ORDER BY AmcosVersionId DESC
          );

    --3/8/2024 we have a bunch of 38Bs who are going to courses their mos doesn't belong in
    --but for the below particular course we don't want to prescribe the MOS because a number of 68s go to this course
    --so we add this line of code to target non 68s/18Ds, when we rewrite this into glue we need to have tiers instead
    --of the all or nothing, e.g. right now its ATRRS, all, or specific MOS, we need a group gate
    --such that if the ATRRS value doesn't meet the right group then it gets converted to a group or subgroup
    UPDATE crunch_temp.ATRRS
    SET PMOSEN4 = '68W'
    WHERE SchoolCode = '0081'
          AND CRSPH = '6H-F35/300-F38'
          AND LEFT(PMOSEN4, 2) <> '68'
          AND LEFT(PMOSEN4, 3) <> '18D'
          AND LEFT(PGRAD, 1) = 'E';
    INSERT INTO crunch_temp.Training_xwalk_atrrs_atrm
    (
        ATRM_Key,
        ATRRS_Key,
        AmcosVersionId
    )
    SELECT ATRM_Key,
           ATRRS_Key,
           AmcosVersionId
    FROM xwalk.ATRRSATRMCrosswalk
    WHERE AmcosVersionId IN
          (
              SELECT TOP (3)
                     AmcosVersionId
              FROM load_training.ATRM
              WHERE AmcosVersionId <= @AmcosVersionId
              GROUP BY AmcosVersionId
              ORDER BY AmcosVersionId DESC
          );
    INSERT INTO crunch_temp.Training_xwalk_atrrs_crstype_mos
    (
        ATRRS_SchoolCode,
        ATRRS_CourseNumber,
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
    SELECT ATRRS_SchoolCode,
           ATRRS_CourseNumber,
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
              WHERE AmcosVersionId <= @AmcosVersionId
              GROUP BY AmcosVersionId
              ORDER BY AmcosVersionId DESC
          );
    INSERT INTO crunch_temp.ATRRSOfficerBranchCodes
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
              WHERE AmcosVersionId <= @AmcosVersionId
              GROUP BY AmcosVersionId
              ORDER BY AmcosVersionId DESC
          );
    INSERT INTO crunch_temp.MilitaryConversions
    (
        OldMOS,
        Grade,
        NewMOS,
        GradeLevel,
        AmcosVersionId
    )
    SELECT WOMOSOld,
           grade,
           WOMOSNew,
           a.GradeLevel,
           AmcosVersionId
    FROM
    (
        SELECT 'W' AS grade,
               WOMOSOld,
               GradeLevel,
               WOMOSNew,
               AmcosVersionId
        FROM lookup.WOMOSConversion
        UNION
        SELECT 'E' AS grade,
               MOSOld,
               GradeLevel,
               MOSNew,
               AmcosVersionId
        FROM lookup.MOSConversion
        UNION
        SELECT 'A' AS grade,
               AOCOld,
               GradeLevel,
               AOCNew,
               AmcosVersionId
        FROM lookup.AOCConversion
    ) AS a
    WHERE AmcosVersionId IN
          (
              SELECT TOP (3)
                     AmcosVersionId
              FROM load_training.ATRM
              WHERE AmcosVersionId <= @AmcosVersionId
              GROUP BY AmcosVersionId
              ORDER BY AmcosVersionId DESC
          );

    /* old code
        --we only care about the latest valid MOSes for this we only pull one version unlike the above tables
        DROP TABLE IF EXISTS crunch_temp.MOSAOC_Validation;
        CREATE TABLE crunch_temp.MOSAOC_Validation
        (
            [MOS] NVARCHAR(4) NULL,
            [GradeType] NVARCHAR(3) NULL,
            [GradeLevel] TINYINT NULL,
            [AmcosVersionId] INT NULL,
            [Value] CHAR(1) NULL
        );

        INSERT INTO crunch_temp.MOSAOC_Validation
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

        */
    DECLARE @Exception AS NVARCHAR(50);
    INSERT INTO crunch_temp.ATRRS_ATRM_Raw
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
        ATRM_CourseLengthWeeks,
        ATRM_CourseTitle,
        ATRM_CourseNumber,
        ATRM_SchoolCode,
        ATRM_VersionId,
        ATRM_Key,
        ATRRS_Key,
        AmcosVersionId,
        ATRRS_VersionId,
        ATRRS_SchoolCode,
        ATRRS_CourseNumber,
        ATRRS_Component,
        ATRRS_School,
        ATRRS_CourseTitle,
        ATRRS_GradeLevel,
        ATRRS_MOS,
        ATRRS_Branch,
        ATRRS_CrsType,
        ATRRS_NumberOfStudents
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
           a.ATRM_CourseLengthWeeks,
           a.ATRM_CourseTitle,
           a.ATRM_CourseNumber,
           a.ATRM_SchoolCode,
           a.ATRM_VersionId,
           a.ATRM_Key,
           a.ATRRS_Key,
           a.AmcosVersionId,
           a.ATRRS_VersionId,
           a.ATRRS_SchoolCode,
           a.ATRRS_CourseNumber,
           a.ATRRS_Component,
           a.ATRRS_SchoolName,
           a.ATRRS_CourseTitle,
           a.ATRRS_GradeLevel,
           a.ATRRS_MOS,
           a.ATRRS_Branch,
           a.ATRRS_CrsType,
           a.ATRRS_NumberOfStudents
    FROM
    (
        SELECT @Exception AS [Exception],
               a.*,
               b.AmcosVersionId AS ATRRS_VersionId,
               b.SchoolCode AS ATRRS_SchoolCode,
               b.[CRSPH] AS ATRRS_CourseNumber,
               b.CPBRANCH AS ATRRS_Component,
               b.SchoolName AS ATRRS_SchoolName,
               b.CourseTitle AS ATRRS_CourseTitle,
               b.PGRAD AS ATRRS_GradeLevel,
               b.PMOSEN4 AS ATRRS_MOS,
               b.CRMGOF AS ATRRS_Branch,
               b.CRSTYPE AS ATRRS_CrsType,
               b.NumberOfStudents AS ATRRS_NumberOfStudents
        FROM
        (
            SELECT a.*,
                   b.AmcosVersionId AS ATRM_VersionId,
                   b.SchoolCode AS ATRM_SchoolCode,
                   b.CourseNumber AS ATRM_CourseNumber,
                   b.CourseTitle AS [ATRM_CourseTitle],
                   b.CourseLengthWeeks AS ATRM_CourseLengthWeeks,
                   b.EGRADS AS ATRM_EGRADS,
                   b.[Modal Grade] AS ATRM_Modal_Grade,
                   b.Frequency AS ATRM_Frequency,
                   b.[Flying Hours] AS ATRM_Flying_Hrs,
                   b.[TMW/EGRAD] AS ATRM_TMW_EGRD,
                   b.MPA AS ATRM_MPA,
                   b.[OMA CIV] + b.[OMA Non-Pay] AS ATRM_OMA,
                   b.Other AS ATRM_Other
            FROM crunch_temp.Training_xwalk_atrrs_atrm AS a
                FULL OUTER JOIN crunch_temp.ATRM AS b
                    ON a.ATRM_Key = (CONCAT(b.SchoolCode, b.CourseNumber))
                       AND a.AmcosVersionId = b.AmcosVersionId
        ) AS a
            FULL OUTER JOIN crunch_temp.ATRRS AS b
                ON a.ATRRS_Key = (CONCAT(b.SchoolCode, b.[CRSPH]))
                   AND b.AmcosVersionId = a.AmcosVersionId
    ) AS a;

    --there are business rules that determine which ATRM courses should be excluded
    --we implement them here
    UPDATE crunch_temp.ATRRS_ATRM_Raw
    SET Exception = 'Exclude'
    FROM crunch_temp.ATRRS_ATRM_Raw AS a
    WHERE
        --general exclude, need to find the business reason why for this 
        RIGHT(a.ATRM_CourseNumber, 3) = '(X)'
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
        OR a.ATRM_SchoolCode LIKE '%S&F%'
        OR a.ATRM_SchoolCode LIKE '%SF%'
        --exclude because its a training class for another service
        OR a.ATRM_CourseNumber LIKE '%(OS) (CT)%'
        OR RIGHT(a.ATRM_CourseNumber, 4) = '(OS)'
        --exclude because it is a foreign weapon sytem
        OR a.ATRM_CourseNumber LIKE '%MI-17%'
        OR a.ATRM_CourseTitle LIKE '%MI-17%'
        OR a.ATRRS_CourseTitle LIKE '%MI-17%'
        --officer candidate school is captured in officer acq so back it out of training
        --but we need to make sure we don't knock out warrant officer candidate school as that is NOT in officer acq per Marsha
        OR
        (
            a.ATRRS_CourseTitle LIKE '%officer candidate%'
            AND ATRRS_CourseTitle NOT LIKE '%warrant%'
        )
        --direction commisioning training which is captured in officer acq
        OR a.ATRRS_CourseTitle LIKE '%DIRECT COMMISSION%'
        --atrrs records where the gradelevel can be converted to a integer are civilians (e.g. 03, 04, etc) and should be excluded; whereas O4, W4 military and are fine to go through
        OR ISNUMERIC(a.ATRRS_GradeLevel) = 1
        --the following exclusions are because the ATRM model has some 'main' courses and some 'detachment' courses with the same key (crs and sch code), without this exclusion we'd double count
        --those costs because they don't  each have a single corresponding course link in ATRS
        OR
        (
            ATRM_SchoolCode = '091S'
            AND ATRM_Activity LIKE '%detachment%'
        );
    IF @Debug = 1
    BEGIN
        --check for multiple entries which would cause problems with joins and calculations later
        SELECT 'for this script to work right there must be 1 and only 1 ATRM sch and course combination in the ATRM table, if this table is not empty that means we need to look at an exclusion so we are not double counting';
        SELECT ATRM.AmcosVersionId,
               ATRM.SchoolCode,
               ATRM.CourseNumber,
               ATRM.CourseTitle,
               ATRM.Activity,
               ATRM.CourseLengthWeeks,
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
        FROM crunch_temp.ATRM AS ATRM
            INNER JOIN
            (
                SELECT *,
                       COUNT(a.CourseNumber) AS mycount
                FROM
                (
                    SELECT a.AmcosVersionId,
                           a.SchoolCode,
                           a.CourseNumber
                    FROM crunch_temp.ATRM AS a
                        LEFT JOIN crunch_temp.ATRRS_ATRM_Raw AS b
                            ON a.AmcosVersionId = b.AmcosVersionId
                               AND a.SchoolCode = b.ATRM_SchoolCode
                               AND a.CourseNumber = b.ATRM_CourseNumber
                    WHERE b.Exception IS NULL
                    GROUP BY a.AmcosVersionId,
                             a.SchoolCode,
                             a.CourseNumber
                ) AS a
                GROUP BY AmcosVersionId,
                         a.SchoolCode,
                         a.CourseNumber
            ) AS b
                ON ATRM.SchoolCode = b.SchoolCode
                   AND ATRM.CourseNumber = b.CourseNumber
                   AND ATRM.AmcosVersionId = b.AmcosVersionId
        WHERE b.mycount >= 2
        ORDER BY ATRM.AmcosVersionId,
                 ATRM.SchoolCode,
                 ATRM.CourseNumber;
        SELECT 'for this script to work right there must be 1 and only 1 ATRM school/course combination to ATRRS school/course, review the folowing and make deletions in the xwalk table';
        SELECT Exception,
               AmcosVersionId,
               ATRM_Key,
               ATRRS_Key,
               ATRM_SchoolCode,
               ATRM_CourseNumber,
               ATRM_CourseTitle,
               ATRM_Activity,
               ATRRS_SchoolCode,
               ATRRS_CourseNumber,
               ATRRS_School,
               ATRRS_CourseTitle
        FROM crunch_temp.ATRRS_ATRM_Raw
        WHERE CONCAT(ATRM_Key, AmcosVersionId)IN
              (
                  SELECT CONCAT([ATRM_Key], AmcosVersionId)
                  FROM crunch_temp.Training_xwalk_atrrs_atrm
                  GROUP BY [ATRM_Key],
                           AmcosVersionId
                  HAVING COUNT([ATRM_Key]) >= 2
              )
              OR CONCAT(ATRRS_Key, AmcosVersionId)IN
                 (
                     SELECT CONCAT([ATRRS_Key], AmcosVersionId)
                     FROM crunch_temp.Training_xwalk_atrrs_atrm
                     GROUP BY [ATRRS_Key],
                              AmcosVersionId
                     HAVING COUNT([ATRRS_Key]) >= 2
                 )
        GROUP BY Exception,
                 AmcosVersionId,
                 ATRM_Key,
                 ATRRS_Key,
                 ATRM_SchoolCode,
                 ATRM_CourseNumber,
                 ATRM_CourseTitle,
                 ATRM_Activity,
                 ATRRS_SchoolCode,
                 ATRRS_CourseNumber,
                 ATRRS_School,
                 ATRRS_CourseTitle
        ORDER BY ATRM_Key,
                 ATRRS_Key;

        -- 1/2/2020 - removed as AmcosVersionId will mean there are always duplicates, added a AmcosVersionId join when this table is used later
        --SELECT 'CIRCLE BACK ON THE FOLLOWING SCRIPT, IT MAY NOT BE A PROBLEM/NEEDED';
        --SELECT 'for this script to work right there must be 1 and only 1 CMF entry in the ATRRS Officer Branch table so this table should be empty';
        --SELECT a.CMF,
        --       a.Branch,
        --       a.definition,
        --       a.AmcosVersionId
        --FROM crunch_temp.ATRRSOfficerBranchCodes AS a
        --    INNER JOIN
        --    (
        --        SELECT CMF,
        --               AmcosVersionId,
        --               COUNT(CMF) AS mycount
        --        FROM crunch_temp.ATRRSOfficerBranchCodes
        --        GROUP BY CMF,
        --                 AmcosVersionId
        --        HAVING COUNT(CMF) > 1
        --    ) AS b
        --        ON a.CMF = b.CMF
        --           AND a.AmcosVersionId = b.AmcosVersionId;

        --check the mappings for issues
        SELECT 'the following mappings have issues because you have a xwalk entry which does not map to anything, every entry in the xwalk table should map to something';
        SELECT Exception,
               ATRM_Other,
               ATRM_OMA,
               ATRM_MPA,
               ATRM_TMW_EGRD,
               ATRM_Flying_Hrs,
               ATRM_Frequency,
               ATRM_Modal_Grade,
               ATRM_EGRADS,
               ATRM_CourseLengthWeeks,
               ATRM_Activity,
               ATRM_CourseTitle,
               ATRM_CourseNumber,
               ATRM_SchoolCode,
               ATRM_VersionId,
               ATRM_Key,
               ATRRS_Key,
               AmcosVersionId,
               ATRRS_VersionId,
               ATRRS_SchoolCode,
               ATRRS_CourseNumber,
               ATRRS_Component,
               ATRRS_School,
               ATRRS_CourseTitle,
               ATRRS_GradeLevel,
               ATRRS_MOS,
               ATRRS_Branch,
               ATRRS_CrsType,
               ATRRS_NumberOfStudents
        FROM crunch_temp.ATRRS_ATRM_Raw
        WHERE (
                  ATRRS_Key IS NOT NULL
                  AND ATRRS_CourseNumber IS NULL
              )
              OR
              (
                  ATRM_Key IS NOT NULL
                  AND ATRM_CourseNumber IS NULL
              );
        SELECT 'for this script to work right there must be 1 and only 1 ATRRS course type entry so the below query should be empty';
        SELECT AmcosVersionId,
               ATRRS_SchoolCode,
               ATRRS_CourseNumber,
               COUNT(ATRRS_CourseNumber) AS mycount
        FROM crunch_temp.Training_xwalk_atrrs_crstype_mos
        GROUP BY AmcosVersionId,
                 ATRRS_SchoolCode,
                 ATRRS_CourseNumber
        HAVING COUNT(ATRRS_CourseNumber) >= 2;

        --check these records to make sure nothing is excluded that shouldn't have been
        SELECT 'exclude list';
        SELECT *
        FROM crunch_temp.ATRRS_ATRM_Raw
        WHERE Exception = 'Exclude'
        ORDER BY ATRM_SchoolCode,
                 ATRM_CourseNumber,
                 ATRRS_SchoolCode,
                 ATRRS_CourseNumber;

        --check these records to make sure we can't do anymore mapping
        --note that all we care about are non-mapped ATRM records, this is because if we don't have an
        --ATRM cost then we can't do anything with the ATRRS data so we focus only on ATRM
        SELECT 'use excel fuzzylookup, or similiar technique, to see if there any more matches between the following unmatched ATRM, then ATRRS records';
        SELECT ATRM_VersionId,
               ATRM_Key,
               ATRM_SchoolCode,
               ATRM_CourseNumber,
               ATRM_Activity,
               ATRM_CourseTitle
        FROM crunch_temp.ATRRS_ATRM_Raw
        WHERE AmcosVersionId IS NULL
              AND Exception IS NULL
        GROUP BY ATRM_VersionId,
                 ATRM_Key,
                 ATRM_SchoolCode,
                 ATRM_CourseNumber,
                 ATRM_Activity,
                 ATRM_CourseTitle;
        SELECT ATRRS_VersionId,
               ATRRS_Key,
               ATRRS_SchoolCode,
               ATRRS_CourseNumber,
               ATRRS_School,
               ATRRS_CourseTitle
        FROM crunch_temp.ATRRS_ATRM_Raw
        WHERE AmcosVersionId IS NULL
              AND Exception IS NULL
        GROUP BY ATRRS_VersionId,
                 ATRRS_Key,
                 ATRRS_SchoolCode,
                 ATRRS_CourseNumber,
                 ATRRS_School,
                 ATRRS_CourseTitle;

    --  SELECT concat (sch,crsph), sch, crsph,defsch, crstitle FROM crunch.training_atrrs WHERE 
    --	  CONCAT (sch,crsph) not IN (SELECT atrrs_key FROM crunch.training_xwalk_atrrs_atrm WHERE AmcosVersionId=-1)
    --	  AND AmcosVersionId=-1
    --	  GROUP BY sch,crsph, defsch, crstitle

    --	  SELECT CONCAT([sch code], [course number]), [sch code], [course number], [course title], activity FROM crunch.training_atrm WHERE
    --      CONCAT([sch code], [course number]) NOT IN  (SELECT atrrs_key from crunch.training_xwalk_atrrs_atrm WHERE AmcosVersionId=-1 )
    --	  AND AmcosVersionId=-1
    --	  GROUP BY [sch code], [course number], [course title], activity
    END;

    /* Bring in the course and MOS/AOC/WOMOS mappings */
    INSERT INTO crunch_temp.AtrrsAtrmCourseMos
    (
        ATRRS_NumberOfStudents,
        ATRRS_CrsType,
        ATRRS_Branch,
        ATRRS_MOS,
        ATRRS_GradeLevel,
        ATRRS_CourseTitle,
        ATRRS_School,
        ATRRS_Component,
        ATRRS_CourseNumber,
        ATRRS_SchoolCode,
        ATRRS_VersionId,
        AmcosVersionId,
        ATRRS_Key,
        ATRM_Key,
        ATRM_VersionId,
        ATRM_SchoolCode,
        ATRM_CourseNumber,
        ATRM_CourseTitle,
        ATRM_Activity,
        ATRM_CourseLengthWeeks,
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
        CourseTypeFinal,
        MOSFinal,
        BranchFinal,
        GradeFinal,
        GradeTypeFinal,
        GradeLevelFinal,
        PayPlan,
        atrrs_tot_students,
        NumberOfStudentsAdjusted,
        running_adj_students,
        Inventory,
        InventoryAdjustment,
        total_inv_add,
        final_adj_inv,
        final_adj_students
    )
    SELECT a.ATRRS_NumberOfStudents,
           a.ATRRS_CrsType,
           a.ATRRS_Branch,
           a.ATRRS_MOS,
           a.ATRRS_GradeLevel,
           a.ATRRS_CourseTitle,
           a.ATRRS_School,
           a.ATRRS_Component,
           a.ATRRS_CourseNumber,
           a.ATRRS_SchoolCode,
           a.ATRRS_VersionId,
           a.AmcosVersionId,
           a.ATRRS_Key,
           a.ATRM_Key,
           a.ATRM_VersionId,
           a.ATRM_SchoolCode,
           a.ATRM_CourseNumber,
           a.ATRM_CourseTitle,
           a.ATRM_Activity,
           a.ATRM_CourseLengthWeeks,
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
           a.CourseTypeFinal,
           a.MOSFinal,
           a.BranchFinal,
           a.GradeFinal,
           a.GradeTypeFinal,
           a.GradeLevelFinal,
           a.PayPlan,
           a.atrrs_tot_students,
           a.NumberOfStudentsAdjusted,
           a.running_adj_students,
           a.Inventory,
           a.InventoryAdjustment,
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
               a.ATRM_CourseLengthWeeks,
               a.ATRM_Activity,
               a.ATRM_CourseTitle,
               a.ATRM_CourseNumber,
               a.ATRM_SchoolCode,
               a.ATRM_VersionId,
               a.ATRM_Key,
               a.ATRRS_Key,
               a.AmcosVersionId,
               a.ATRRS_VersionId,
               a.ATRRS_SchoolCode,
               a.ATRRS_CourseNumber,
               a.ATRRS_Component,
               a.ATRRS_School,
               a.ATRRS_CourseTitle,
               a.ATRRS_GradeLevel,
               a.ATRRS_MOS,
               a.ATRRS_Branch,
               a.ATRRS_CrsType,
               a.ATRRS_NumberOfStudents,
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
               NULL AS CourseTypeFinal,
               NULL AS MOSFinal,
               NULL AS BranchFinal,
               NULL AS GradeFinal,
               NULL AS GradeTypeFinal,
               NULL AS GradeLevelFinal,
               NULL AS PayPlan,
               NULL AS atrrs_tot_students,
               0.0 AS NumberOfStudentsAdjusted,
               0.0 AS running_adj_students,
               NULL AS Inventory,
               0.0 AS InventoryAdjustment,
               0.0 AS total_inv_add,
               0.0 AS final_adj_inv,
               0.0 AS final_adj_students
        FROM crunch_temp.ATRRS_ATRM_Raw AS a
            LEFT JOIN crunch_temp.Training_xwalk_atrrs_crstype_mos AS b
                ON a.ATRRS_CourseNumber = b.ATRRS_CourseNumber
                   AND a.ATRRS_SchoolCode = b.ATRRS_SchoolCode
                   AND a.AmcosVersionId = b.AmcosVersionId
        --we're getting down to business now so get rid of the non-matches to ATRRS and the excludes
        --we assume at this point the analyst will have looked at the previous debug flags and made necessary adjustments
        WHERE a.Exception IS NULL
              AND a.ATRRS_Key IS NOT NULL
    ) AS a;

    --alright, now we use the atrrs assignments to divvy out final assignments
    --make final grade level assignments
    --grade levels come from ATRRS with a few exceptions
    UPDATE crunch_temp.AtrrsAtrmCourseMos
    SET GradeFinal = ATRRS_GradeLevel;

    --cadets become O1s
    UPDATE crunch_temp.AtrrsAtrmCourseMos
    SET GradeFinal = 'O1'
    WHERE ATRRS_GradeLevel = 'CD';

    --warrant candidates become W1s
    UPDATE crunch_temp.AtrrsAtrmCourseMos
    SET GradeFinal = 'W1'
    WHERE ATRRS_CourseTitle LIKE '%warrant officer candidate%'
          OR ATRRS_CourseTitle LIKE '%WOBC%'
          OR ATRRS_CourseTitle LIKE '%wo basic%'
          OR ATRRS_CourseTitle LIKE '%warrant officer basic%';

    --those going to Basic Officer courses need to be converter to an O1 if they are not already
    UPDATE crunch_temp.AtrrsAtrmCourseMos
    SET GradeFinal = 'O1'
    WHERE
        --if the student is already an officer then lets not change their grade level
        LEFT(ATRRS_GradeLevel, 1) <> 'O'
        AND ATRRS_CourseTitle LIKE '%basic officer%'
        AND
        --make sure we aren't including any warrant officer basic type courses
        (
            ATRRS_CourseTitle NOT LIKE '%WOBC%'
            AND ATRRS_CourseTitle NOT LIKE '%Warrant%'
        );

    --O/W & E crs type codes may be different for some courses
    --O/W/E grp/subgrp assignments are also made
    UPDATE crunch_temp.AtrrsAtrmCourseMos
    SET CourseTypeFinal = Crs_Type_O,
        MOSFinal = AOC
    WHERE LEFT(GradeFinal, 1) = 'O';
    UPDATE crunch_temp.AtrrsAtrmCourseMos
    SET CourseTypeFinal = Crs_Type_E,
        MOSFinal = MOS
    WHERE LEFT(GradeFinal, 1) = 'E';
    UPDATE crunch_temp.AtrrsAtrmCourseMos
    SET CourseTypeFinal = Crs_Type_O,
        MOSFinal = WOMOS
    WHERE LEFT(GradeFinal, 1) = 'W';

    --one more final item, if there is a grade level adjustment required by the CrsType_MOS table then we need to make it
    --because each grade type has a floor and ceiling this is going to take a series of update statements

    --to make this easier before we do anything let's populate the final grade and level columns
    UPDATE crunch_temp.AtrrsAtrmCourseMos
    SET GradeTypeFinal = LEFT(GradeFinal, 1),
        GradeLevelFinal = (RIGHT(GradeFinal, 1));

    --now let's make the grade level adjustments
    --officer grade level floor and ceiling
    UPDATE crunch_temp.AtrrsAtrmCourseMos
    SET GradeLevelFinal = O_GradeLevel_Floor
    WHERE GradeTypeFinal = 'O'
          AND O_GradeLevel_Floor > GradeLevelFinal
          AND O_GradeLevel_Floor IS NOT NULL;
    UPDATE crunch_temp.AtrrsAtrmCourseMos
    SET GradeLevelFinal = O_GradeLevel_Ceiling
    WHERE GradeTypeFinal = 'O'
          AND O_GradeLevel_Ceiling < GradeLevelFinal
          AND O_GradeLevel_Ceiling IS NOT NULL;

    --warrant grade level floor and ceiling
    UPDATE crunch_temp.AtrrsAtrmCourseMos
    SET GradeLevelFinal = W_GradeLevel_Floor
    WHERE GradeTypeFinal = 'W'
          AND W_GradeLevel_Floor > GradeLevelFinal
          AND W_GradeLevel_Floor IS NOT NULL;
    UPDATE crunch_temp.AtrrsAtrmCourseMos
    SET GradeLevelFinal = W_GradeLevel_Ceiling
    WHERE GradeTypeFinal = 'W'
          AND W_GradeLevel_Ceiling < GradeLevelFinal
          AND W_GradeLevel_Ceiling IS NOT NULL;

    --enlisted grade level floor and ceiling
    UPDATE crunch_temp.AtrrsAtrmCourseMos
    SET GradeLevelFinal = E_GradeLevel_Floor
    WHERE GradeTypeFinal = 'E'
          AND E_GradeLevel_Floor > GradeLevelFinal
          AND E_GradeLevel_Floor IS NOT NULL;
    UPDATE crunch_temp.AtrrsAtrmCourseMos
    SET GradeLevelFinal = E_GradeLevel_Ceiling
    WHERE GradeTypeFinal = 'E'
          AND E_GradeLevel_Ceiling < GradeLevelFinal
          AND E_GradeLevel_Ceiling IS NOT NULL;

    ----Now copy any changes back into the combined GradeFinal
    UPDATE crunch_temp.AtrrsAtrmCourseMos
    SET GradeFinal = CONCAT(GradeTypeFinal, GradeLevelFinal);
    IF @Debug = 1
    BEGIN
        SELECT 'the following records do not have any course type assignment, this needs to be fixed';
        SELECT *
        FROM crunch_temp.AtrrsAtrmCourseMos
        WHERE CourseTypeFinal IS NULL
        ORDER BY ATRM_SchoolCode,
                 ATRM_CourseNumber;
    END;

    --Now we turn the ATRRS data select values into whoever ATRRS says attended the course
    UPDATE crunch_temp.AtrrsAtrmCourseMos
    SET MOSFinal = CASE
                       WHEN (LEN(ATRRS_MOS) > 3) THEN
                           ISNULL(LEFT(ATRRS_MOS, 3), NULL)
                       ELSE
                           ATRRS_MOS
                   END
    WHERE LEFT(ATRRS_GradeLevel, 1) <> 'W'
          AND MOSFinal = 'ATRRS';
    UPDATE crunch_temp.AtrrsAtrmCourseMos
    SET MOSFinal = ATRRS_MOS
    WHERE LEFT(ATRRS_GradeLevel, 1) = 'W'
          AND MOSFinal = 'ATRRS';

    /* This statement corrects the issue where the course xwalk wants to use ATRRS WOMOS but then we converted some Es to Ws, so we need
	to make those XXXs since we do not know which WOMOS to use they will only be the ones with an existing 3 character MOS, we want to
	exclude any 2 character MOS (CMF level) or 4 character MOS (correct WOMOS) */
    UPDATE crunch_temp.AtrrsAtrmCourseMos
    SET MOSFinal = 'XXX'
    WHERE GradeTypeFinal = 'W'
          --WOMOS is 4 digits so a 3 digit WOMOS is an enlisted that was converted to a warrant through warrant officer basic course
          AND LEN(MOSFinal) = 3;

    --if the course xwalk used an WOMOS in the enlisted column that means we also need to now convert their grade
    UPDATE crunch_temp.AtrrsAtrmCourseMos
    SET GradeTypeFinal = 'W'
    WHERE GradeTypeFinal = 'E'
          --WOMOS is 4 digits so a 3 digit WOMOS in an enlisted grade means we need to convert the grade to W
          AND LEN(MOSFinal) > 3;

    --bring in officer branch data
    --because ATRRS doesn't have officer AOCs we need someway to determine if we are doing officer conversions
    --we use the ATRRS branch field 2 character abbreviation and a lookup table to pull in the branch cmf
    UPDATE crunch_temp.AtrrsAtrmCourseMos
    SET BranchFinal = b.Branch
    FROM crunch_temp.AtrrsAtrmCourseMos AS a
        LEFT JOIN crunch_temp.ATRRSOfficerBranchCodes AS b
            ON LEFT(a.MOSFinal, 2) = b.CMF
               AND b.AmcosVersionId = a.AmcosVersionId --this added 1/2/2020 to deal with AmcosVersionId
    WHERE a.GradeTypeFinal = 'O';

    --populate the payplan field
    UPDATE crunch_temp.AtrrsAtrmCourseMos
    SET PayPlan = ATRRS_Component;
    UPDATE crunch_temp.AtrrsAtrmCourseMos
    SET PayPlan = 'N'
    WHERE PayPlan = 'G';
    UPDATE crunch_temp.AtrrsAtrmCourseMos
    SET PayPlan = CONCAT(PayPlan, GradeTypeFinal);
    UPDATE crunch_temp.AtrrsAtrmCourseMos
    SET PayPlan = CONCAT(PayPlan, 'O')
    WHERE PayPlan LIKE '%W%';

    -- =============================================
    --Make sure that before we bring in inventory we have valid AOCs/MOSes/WOMOSes
    --by converting those we can
    --Conversion information comes from the G1 Personnel Authorization Module (PAM)
    -- =============================================
    --
    UPDATE crunch_temp.AtrrsAtrmCourseMos
    SET MOSFinal = b.NewMOS
    FROM crunch_temp.AtrrsAtrmCourseMos AS a
        INNER JOIN crunch_temp.MilitaryConversions AS b
            ON a.MOSFinal = b.OldMOS
               AND RIGHT(a.ATRRS_GradeLevel, LEN(a.ATRRS_GradeLevel) - 1) = b.GradeLevel
               AND LEFT(a.ATRRS_GradeLevel, 1) = b.Grade
               AND b.NewMOS NOT LIKE '%none%'
               AND b.AmcosVersionId = a.AmcosVersionId;

    IF @Debug = 1
    BEGIN
        SELECT 'status of the crunch_temp.AtrrsAtrmCourseMos table';
        SELECT *
        FROM crunch_temp.AtrrsAtrmCourseMos;
        SELECT 'The following AOC/MOS/WOMOS are not valid, we need to fix this to the extent we can';
        SELECT a.MOSFinal,
               a.GradeTypeFinal,
               a.GradeLevelFinal
        FROM crunch_temp.AtrrsAtrmCourseMos AS a
            LEFT OUTER JOIN
            (
                SELECT MOS,
                       GradeType,
                       GradeLevel
                FROM crunch_temp.MOSAOC_Validation
                GROUP BY MOS,
                         GradeType,
                         GradeLevel
            ) AS b
                ON a.MOSFinal = b.MOS
                   AND a.GradeTypeFinal = b.GradeType
                   AND a.GradeLevelFinal = b.GradeLevel
        WHERE b.MOS IS NULL
              --we're not checking CMFs and it doesn't make sense to check PayPlan wide assignments -> 'XXX'
              AND a.MOSFinal <> 'XXX'
              AND LEN(a.MOSFinal) > 2
        GROUP BY a.MOSFinal,
                 a.GradeTypeFinal,
                 a.GradeLevelFinal;
        SELECT 'the following records do not have any MOS assignment, this needs to be fixed';
        SELECT *
        FROM crunch_temp.AtrrsAtrmCourseMos
        WHERE MOSFinal IS NULL;
    END;

    -- =============================================
    --bring in inventory
    -- =============================================

    --Bring in inventory for the subgroup matches
    --3/11/2021 per the guidance of the COR (Marsha Popp) this was adjusted to include a 3 year moving average for inventory to better stabalize the denominator like we do for the numerator with course costs
    UPDATE crunch_temp.AtrrsAtrmCourseMos
    SET Inventory = b.Inventory
    FROM crunch_temp.AtrrsAtrmCourseMos AS a
        LEFT OUTER JOIN
        (
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   GradeType,
                   GradeLevel,
                   AVG(Inventory) AS Inventory
            FROM
            (
                SELECT PayPlan,
                       CategoryGroupCode,
                       CategorySubgroupCode,
                       GradeType,
                       GradeLevel,
                       SUM(Inventory) AS Inventory,
                       AmcosVersionId
                FROM data.KnownInventory
                WHERE PayPlan IN ( 'AE', 'AO', 'AWO', 'NE', 'NO', 'NWO', 'RE', 'RO', 'RWO' )
                      AND AmcosVersionId
                      BETWEEN @AmcosVersionId - 200 AND @AmcosVersionId
                GROUP BY PayPlan,
                         CategoryGroupCode,
                         CategorySubgroupCode,
                         GradeType,
                         GradeLevel,
                         AmcosVersionId
            ) AS z
            GROUP BY PayPlan,
                     CategoryGroupCode,
                     CategorySubgroupCode,
                     GradeType,
                     GradeLevel
        ) AS b
            ON a.MOSFinal = b.CategorySubgroupCode
               AND a.GradeLevelFinal = b.GradeLevel
               AND a.PayPlan = b.PayPlan;

    /* Bring in inventory for the group matches */
    UPDATE crunch_temp.AtrrsAtrmCourseMos
    SET Inventory = b.Inventory
    FROM crunch_temp.AtrrsAtrmCourseMos AS a
        LEFT OUTER JOIN
        (
            SELECT PayPlan,
                   CategoryGroupCode,
                   GradeType,
                   GradeLevel,
                   AVG(Inventory) AS Inventory
            FROM
            (
                SELECT PayPlan,
                       CategoryGroupCode,
                       GradeType,
                       GradeLevel,
                       SUM(Inventory) AS Inventory,
                       AmcosVersionId
                FROM data.KnownInventory
                WHERE PayPlan IN ( 'AE', 'AO', 'AWO', 'NE', 'NO', 'NWO', 'RE', 'RO', 'RWO' )
                      AND AmcosVersionId
                      BETWEEN @AmcosVersionId - 200 AND @AmcosVersionId
                GROUP BY PayPlan,
                         CategoryGroupCode,
                         GradeType,
                         GradeLevel,
                         AmcosVersionId
            ) AS z
            GROUP BY PayPlan,
                     CategoryGroupCode,
                     GradeType,
                     GradeLevel
        ) AS b
            ON LEFT(a.MOSFinal, 2) = b.CategoryGroupCode
               AND a.GradeLevelFinal = b.GradeLevel
               AND a.PayPlan = b.PayPlan
    WHERE LEN(a.MOSFinal) = 2;

    /* Bring in inventory for the payplan and grade */
    UPDATE crunch_temp.AtrrsAtrmCourseMos
    SET Inventory = b.Inventory
    FROM crunch_temp.AtrrsAtrmCourseMos AS a
        LEFT OUTER JOIN
        (
            SELECT PayPlan,
                   GradeType,
                   GradeLevel,
                   AVG(Inventory) AS Inventory
            FROM
            (
                SELECT PayPlan,
                       GradeType,
                       GradeLevel,
                       SUM(Inventory) AS Inventory,
                       AmcosVersionId
                FROM data.KnownInventory
                WHERE PayPlan IN ( 'AE', 'AO', 'AWO', 'NE', 'NO', 'NWO', 'RE', 'RO', 'RWO' )
                      AND AmcosVersionId
                      BETWEEN @AmcosVersionId - 200 AND @AmcosVersionId
                GROUP BY PayPlan,
                         GradeType,
                         GradeLevel,
                         AmcosVersionId
            ) AS z
            GROUP BY PayPlan,
                     GradeType,
                     GradeLevel
        ) AS b
            ON a.GradeLevelFinal = b.GradeLevel
               AND a.PayPlan = b.PayPlan
    WHERE a.MOSFinal = 'XXX';

    --when there is no inventory the value shows up as null, we want to change those to 0
    UPDATE crunch_temp.AtrrsAtrmCourseMos
    SET Inventory = 0
    WHERE Inventory IS NULL;
    IF @Debug = 1
    BEGIN
        SELECT 'these records do not have any inventory, it could be an invalid assignment by us or just a bad ATRRS record';
        SELECT *
        FROM crunch_temp.AtrrsAtrmCourseMos
        WHERE Inventory = 0
        ORDER BY MOSFinal,
                 GradeFinal,
                 ATRRS_CourseTitle;
    END;

    /*
    make student adjustments
    
    ATRM data shows the number of graduates which can be compared to the number of students in ATRRS
    When ATRRS students exceeds ATRM graduates we can throttle the number of students
    When ATRRS students falls short of ATRM graduates we do nothing
    purpose of this is to throttle costs by taking into account the reported graduates */

    --first we need to calculate the total number of ATRRS students for each course
    UPDATE crunch_temp.AtrrsAtrmCourseMos
    SET atrrs_tot_students = b.ATRRS_NumberOfStudents
    FROM crunch_temp.AtrrsAtrmCourseMos AS a
        LEFT JOIN
        (
            SELECT AmcosVersionId,
                   ATRRS_SchoolCode,
                   ATRRS_CourseNumber,
                   SUM(ISNULL(ATRRS_NumberOfStudents, 0)) AS ATRRS_NumberOfStudents
            FROM crunch_temp.AtrrsAtrmCourseMos
            GROUP BY AmcosVersionId,
                     ATRRS_SchoolCode,
                     ATRRS_CourseNumber
        ) AS b
            ON a.ATRRS_SchoolCode = b.ATRRS_SchoolCode
               AND a.ATRRS_CourseNumber = b.ATRRS_CourseNumber
               AND a.AmcosVersionId = b.AmcosVersionId;

    --next we calculate the adjusted students
    --first we fill in the NumberOfStudentsAdjusted field with the existing atrrs student count
    UPDATE crunch_temp.AtrrsAtrmCourseMos
    SET NumberOfStudentsAdjusted = ATRRS_NumberOfStudents;

    --now we adjust the student count for certain records
    UPDATE crunch_temp.AtrrsAtrmCourseMos
    SET NumberOfStudentsAdjusted = (ATRM_EGRADS / atrrs_tot_students) * ATRRS_NumberOfStudents
    --only reduce the total students, we do not want to inflate them as we trust atrrs except where it
    --exceeds atrm
    WHERE ATRM_EGRADS < atrrs_tot_students;

    --REVERSE THE EFFECTS OF THE ABOVE FOR TESTING PURPOSES
    --UPDATE crunch_temp.AtrrsAtrmCourseMos SET NumberOfStudentsAdjusted=atrrs_NumberOfStudents

    -- =============================================
    --make inventory adjustments
    -- =============================================
    --conversions should be added to inventory in certain cases
    UPDATE crunch_temp.AtrrsAtrmCourseMos
    SET InventoryAdjustment = 0;
    --if we converted positions then we should track those as additions to inventory

    --adjust inventory at the MOS level for warrants
    --their incoming MOS, if filled out, is exactly 4 digits
    UPDATE crunch_temp.AtrrsAtrmCourseMos
    SET InventoryAdjustment = NumberOfStudentsAdjusted
    --when we changed the MOS, but also forget about the officers since they almost always come in without an MOS
    WHERE ATRRS_MOS <> MOSFinal
          AND LEN(MOSFinal) >= 3
          --we don't want to adjust inventory at the payplan level as that would be incorrectly addative
          AND MOSFinal <> 'XXX'
          --we only do this for Warrants since their ATRRS reported MOS doesn't have a digit suffix
          AND GradeTypeFinal = 'W';

    --adjust enlisted  and officers (most officers don't have an ATRRS MOS but some do) 
    --their incoming MOS, if filled out, can be 3 or 4 digits with some having a trailing suffix as the 4th digit which we do not care about
    UPDATE crunch_temp.AtrrsAtrmCourseMos
    SET InventoryAdjustment = NumberOfStudentsAdjusted
    --when we changed the MOS, but also forget about the officers since they almost always come in without an MOS
    WHERE LEFT(ATRRS_MOS, 3) <> MOSFinal
          AND ATRRS_MOS IS NOT NULL
          AND LEN(MOSFinal) >= 3
          --we don't want to adjust inventory at the payplan level as that would be incorrectly addative
          AND MOSFinal <> 'XXX'
          AND GradeTypeFinal <> 'W';

    --adjust officers using branch (most officers don't have an MOS in ATRRS so we use some deduction to figure out if we are making a CMF conversion
    --their incoming MOS, if filled out, can be 3 or 4 digits with some having a trailing suffix as the 4th digit which we do not care about
    UPDATE crunch_temp.AtrrsAtrmCourseMos
    SET InventoryAdjustment = NumberOfStudentsAdjusted
    --when we changed the MOS, but also forget about the officers since they almost always come in without an MOS
    WHERE ATRRS_Branch <> BranchFinal
          AND GradeTypeFinal = 'O'
          AND ATRRS_Branch IS NOT NULL
          --we don't want to adjust inventory at the payplan level as that would be incorrectly addative
          AND MOSFinal <> 'XXX';

    /* Adjust inventory at the CMF level */
    UPDATE crunch_temp.AtrrsAtrmCourseMos
    SET InventoryAdjustment = NumberOfStudentsAdjusted
    --when we changed the CMF, but also forget about the officers since they almost always come in without an MOS
    WHERE LEFT(ATRRS_MOS, 2) <> LEFT(MOSFinal, 2)
          AND GradeTypeFinal <> 'O'
          --final MOS with a length of only 2 are our CMF level costs
          AND LEN(MOSFinal) = 2;

    /* If inventory is 0 then we don't touch that record since no cost elements are shown for records with 0 inventory
    could have added this as a where clause to each of the above 3 statements but easier and more straightforward to just do a quick update here */
    UPDATE crunch_temp.AtrrsAtrmCourseMos
    SET InventoryAdjustment = 0
    WHERE Inventory = 0;

    /* Each ATRRS course can appear multiple times within a given AOC/MOS/WOMOS, PP, and gradelevel in cases where we made a manual conversion
        if we don't account for this then we could average at the row level, but then the sum later on would cause an additive average which
        is not by any means the true average we want.  We could account for this through an interim table with aggregation but we're going for
        one detailed table with all the steps so we have complete accountability of the entire process from start to finish, so because of that
        we add 3 additional columns to assist with this important processing step */

    --first give us a list of the running adjusted student total so we can stop adding costs when students outpace inventory
    WITH myAdjStudCTE
    AS (SELECT *,
               SUM(ISNULL(NumberOfStudentsAdjusted, 0)) OVER (PARTITION BY AmcosVersionId,
                                                                           PayPlan,
                                                                           ATRRS_Key,
                                                                           MOSFinal,
                                                                           GradeLevelFinal
                                                              ORDER BY AmcosVersionId,
                                                                       PayPlan,
                                                                       ATRRS_Key,
                                                                       MOSFinal,
                                                                       GradeLevelFinal
                                                             ) AS SumOfNumberOfStudentsAdjusted
        FROM crunch_temp.AtrrsAtrmCourseMos)
    UPDATE myAdjStudCTE
    SET running_adj_students = SumOfNumberOfStudentsAdjusted;

    --FROM TempAtrrsAtrmCourseMos AS a
    --INNER JOIN my_adj_students AS b ON a.ATRRS_SchoolCode=b.atrrs_SchoolCode AND a.ATRRS_CourseNumber=b.atrrs_CourseNumber and a.PayPlan=b.PayPlan AND a.final_mos=b.final_mos and a.GradeFinal=b.GradeFinal;

    --SELECT * FROM TempAtrrsAtrmCourseMos
    --WHERE atrrs_CourseNumber='5E-F1/234-F41' AND PayPlan='AE' AND GradeFinal='E4'
    ;
    WITH my_adj_inv
    AS (SELECT *,
               SUM(InventoryAdjustment) OVER (PARTITION BY AmcosVersionId,
                                                           ATRRS_Key,
                                                           PayPlan,
                                                           MOSFinal,
                                                           GradeFinal
                                              ORDER BY ATRRS_Key,
                                                       PayPlan,
                                                       MOSFinal,
                                                       GradeFinal
                                             ) AS my_inv_add
        FROM crunch_temp.AtrrsAtrmCourseMos)
    UPDATE my_adj_inv
    SET total_inv_add = my_inv_add;
    --FROM TempAtrrsAtrmCourseMos AS a
    --INNER JOIN my_adj_inv AS b ON a.ATRRS_SchoolCode=b.atrrs_SchoolCode AND a.ATRRS_CourseNumber=b.atrrs_CourseNumber and a.PayPlan=b.PayPlan AND a.final_mos=b.final_mos and a.GradeTypeFinal=b.GradeFinal;

    --the final inventory is the base inventory plus all the inventory conversions we made
    UPDATE crunch_temp.AtrrsAtrmCourseMos
    --inventory add was removed when we went to the CGLA math, away from the show costs where they lay process which Mr Barth did not like
    SET final_adj_inv = Inventory + total_inv_add;
    UPDATE crunch_temp.AtrrsAtrmCourseMos
    SET final_adj_students = 0;

    /* Compute the final adjusted students, there are 3 scenarios
    1) the row's students don't exceed the adj inventory so we compute the cost for the row as an average */
    UPDATE crunch_temp.AtrrsAtrmCourseMos
    SET final_adj_students = NumberOfStudentsAdjusted
    WHERE running_adj_students <= (final_adj_inv);

    /* 2) the row's students exceed the adj inventory
      2a) but the row has some # of students which are under the adjusted inventory cap so we compute an average cost for those */
    UPDATE crunch_temp.AtrrsAtrmCourseMos
    SET final_adj_students = CONVERT(INT, (final_adj_inv - (running_adj_students - NumberOfStudentsAdjusted)))
                             % NULLIF(CONVERT(INT, NumberOfStudentsAdjusted), 0)
    WHERE
        --need to be above adjusted inventory
        running_adj_students > final_adj_inv
        --need to have some headspace left in inventory
        AND final_adj_inv - (running_adj_students - NumberOfStudentsAdjusted) > 0;

    --2b) the # of students already exceeded adjusted inventory in a prior row so we return 0 
    --we do nothing here to default to a zero

    /* Basic training should costs should only appear up to GL4 per email with Marsha on 12/20/2018 therefore we set GL5 and above costs to 0 */
    UPDATE crunch_temp.AtrrsAtrmCourseMos
    SET NumberOfStudentsAdjusted = 0
    WHERE CourseTypeFinal = 'B'
          AND GradeLevelFinal >= 5
          AND GradeTypeFinal = 'E';

    INSERT INTO crunch_temp.TrainingCostsByVersion
    (
        AmcosVersionId,
        ATRM_Key,
        ATRRS_Key,
        ATRM_CourseTitle,
        ATRM_MPA,
        ATRM_OMA,
        ATRM_Other,
        Inventory,
        PayPlan,
        MOSFinal,
        CourseTypeFinal,
        WeaponSystemName,
        GradeTypeFinal,
        GradeLevelFinal,
        NumberOfStudentsAdjusted,
        MPA_Total_Cost,
        OMA_Total_Cost,
        Other_Total_cost
    )
    SELECT AmcosVersionId,
           ATRM_Key,
           ATRRS_Key,
           ATRM_CourseTitle,
           MAX(ISNULL(ATRM_MPA, 0)) AS ATRM_MPA,
           MAX(ISNULL(ATRM_OMA, 0)) AS ATRM_OMA,
           MAX(ISNULL(ATRM_Other, 0)) AS ATRM_Other,
           MAX(Inventory) AS Inventory,
           PayPlan,
           MOSFinal,
           CourseTypeFinal,
           WeaponSystemName,
           GradeTypeFinal,
           GradeLevelFinal,
           SUM(ISNULL(NumberOfStudentsAdjusted, 0)) AS NumberOfStudentsAdjusted,
           0.0 AS MPA_Total_Cost,
           0.0 AS OMA_Total_Cost,
           0.0 AS Other_Total_cost
    FROM crunch_temp.AtrrsAtrmCourseMos
    GROUP BY AmcosVersionId,
             ATRM_Key,
             ATRRS_Key,
             ATRM_CourseTitle,
             PayPlan,
             MOSFinal,
             CourseTypeFinal,
             WeaponSystemName,
             GradeTypeFinal,
             GradeLevelFinal;

    -- =============================================
    --compute costs
    -- =============================================
    --when the students exceed inventory use inventory
    --this prevents a situation where say 25 people attend a class for an E5 when there is only E5 inventory of 1 and no E6 or above exist
    --that would create astronimcal costs which are not reasonable
    --such a scenario is likely possible due both to our converting MOSes/AOCes and the questionable attendee data from ATRRs in some cases
    /* TODO Check for NULL */
    UPDATE crunch_temp.TrainingCostsByVersion
    SET MPA_Total_Cost = CASE
                             WHEN NumberOfStudentsAdjusted > Inventory THEN
                                 Inventory * ATRM_MPA
                             ELSE
                                 NumberOfStudentsAdjusted * ATRM_MPA
                         END,
        OMA_Total_Cost = CASE
                             WHEN NumberOfStudentsAdjusted > Inventory THEN
                                 Inventory * ATRM_OMA
                             ELSE
                                 NumberOfStudentsAdjusted * ATRM_OMA
                         END,
        Other_Total_cost = CASE
                               WHEN NumberOfStudentsAdjusted > Inventory THEN
                                   Inventory * ATRM_Other
                               ELSE
                                   NumberOfStudentsAdjusted * ATRM_Other
                           END;

    -- =============================================
    --generate a average table
    -- =============================================
    --because we are going to use this table a few times its less overhead to generate one summation table than to keep using an aggregation of the TempATRRS_ATRM_CRS_MOS table
    INSERT INTO crunch_temp.TrainingCostsAverage
    (
        WeaponSystemName,
        CourseTypeFinal,
        MOSFinal,
        GradeTypeFinal,
        GradeLevelFinal,
        PayPlan,
        Inventory,
        mpa_total_avg_cost,
        oma_total_avg_cost,
        other_total_avg_cost,
        MPA_adj,
        OMA_adj,
        Other_adj
    )
    SELECT a.WeaponSystemName,
           a.CourseTypeFinal,
           a.MOSFinal,
           a.GradeTypeFinal,
           a.GradeLevelFinal,
           a.PayPlan,
           a.Inventory,
           a.mpa_total_avg_cost,
           a.oma_total_avg_cost,
           a.other_total_avg_cost,
           0.0 AS MPA_adj,
           0.0 AS OMA_adj,
           0.0 AS Other_adj
    FROM
    (
        --average across versions
        SELECT WeaponSystemName,
               CourseTypeFinal,
               MOSFinal,
               GradeTypeFinal,
               GradeLevelFinal,
               PayPlan,
               MAX(Inventory) AS Inventory,
               -- code was changed 2/4/2020 per email with marsha to do a forced 3 year moving average in case any years have a cost of null which would prevent a true 3 yr avg
               --AVG(MPA_Total_Cost) AS mpa_total_avg_cost,
               --AVG(OMA_Total_Cost) AS oma_total_avg_cost,
               --AVG(Other_Total_cost) AS other_total_avg_cost

               --added 2/18/2020 to fix an average of averages issues when it sohuld be a sum, then an average of 3 since we are doing 3 years of costs
               --sum up the courses by removing the course information, if we don't do this then the calculation is a simple average of all courses across all versions which is not what we want
               --we want the total training cost for each version, then we want to average that
               SUM(ISNULL(MPA_Total_Cost, 0)) / 3 AS mpa_total_avg_cost,
               SUM(ISNULL(OMA_Total_Cost, 0)) / 3 AS oma_total_avg_cost,
               SUM(ISNULL(Other_Total_cost, 0)) / 3 AS other_total_avg_cost
        FROM crunch_temp.TrainingCostsByVersion
        --this was long hand to do the above, leaving it in for reference if needed in the future

        --(
        --    SELECT WeaponSystemName,
        --           CourseTypeFinal,
        --           MOSFinal,
        --           GradeTypeFinal,
        --           GradeLevelFinal,
        --           PayPlan,
        --           MAX(Inventory) AS inv,
        --           SUM(MPA_Total_Cost) AS mpa_total,
        --           SUM(OMA_Total_Cost) AS oma_total,
        --           SUM(Other_Total_cost) AS other_total,
        --           AmcosVersionId
        --    FROM crunch_temp.TrainingCostsByVersion
        --    GROUP BY WeaponSystemName,
        --             CourseTypeFinal,
        --             MOSFinal,
        --             GradeTypeFinal,
        --             GradeLevelFinal,
        --             PayPlan,
        --             AmcosVersionId
        --) AS a
        GROUP BY WeaponSystemName,
                 CourseTypeFinal,
                 MOSFinal,
                 GradeTypeFinal,
                 GradeLevelFinal,
                 PayPlan
    ) AS a;

    -- =============================================
    --Adjust the Average table by bringing in Budget data
    -- =============================================
    --Army budget data gives us an idea of how much is budgeted for training types, we can use this to bring the ATRRS and ATRM data back in line with the budget
    --we could have just used the army budget data but then we'd have the same training amount for every soldier and that's too generic for AMCOS


    DECLARE @OSUT_Perc AS NUMERIC(18, 2);


    DECLARE @B_perc AS NUMERIC(18, 2);


    DECLARE @PC_perc AS NUMERIC(18, 2);


    DECLARE @AIT_IET_Perc AS NUMERIC(18, 2);
    DECLARE @Training_Budget_Total AS NUMERIC(18, 2);
    DECLARE @Unallocated_Training_Budget AS NUMERIC(18, 2);
    DECLARE @unallocated_budget_per_soldier AS NUMERIC(18, 2);

    --Before we do any adjustments we need to implement a rule on reporting codes
    --Per discussion with marsha on 11/14/2018, reporting codes will not get MOS level ATRM/ATRRS costs
    --any MOS level ATRM/ATRRS costs they have will be zero-d out, this is to prevent unnatural spikes of costs (e.g. some reporting code person going to an expensive blackhawk course
    UPDATE crunch_temp.TrainingCostsAverage
    SET mpa_total_avg_cost = 0,
        oma_total_avg_cost = 0,
        other_total_avg_cost = 0
    WHERE LEFT(MOSFinal, 1) = '0';

    --compute our ATRM/ATRRS generated course totals
    DECLARE @OSUT_Total AS NUMERIC(18, 2) =
            (
                SELECT SUM(oma_total_avg_cost) + SUM(other_total_avg_cost)
                FROM crunch_temp.TrainingCostsAverage
                WHERE CourseTypeFinal IN ( 'OSUT' )
            );

    DECLARE @B_Total AS NUMERIC(18, 2) =
            (
                SELECT SUM(oma_total_avg_cost) + SUM(other_total_avg_cost)
                FROM crunch_temp.TrainingCostsAverage
                WHERE CourseTypeFinal IN ( 'B' )
            );

    DECLARE @PC_total AS NUMERIC(18, 2) =
            (
                SELECT SUM(oma_total_avg_cost) + SUM(other_total_avg_cost)
                FROM crunch_temp.TrainingCostsAverage
                WHERE CourseTypeFinal IN ( 'P', 'C' )
            );

    DECLARE @AIT_IET_Total AS NUMERIC(18, 2) =
            (
                SELECT SUM(oma_total_avg_cost) + SUM(other_total_avg_cost)
                FROM crunch_temp.TrainingCostsAverage
                WHERE CourseTypeFinal IN ( 'IET', 'AIT' )
            );

    --get the budget amounts
    DECLARE @OSUT_Budget AS NUMERIC(18, 2)
        = crunch.GetArmyBudgetSingleValue('Training-OSUT', 'OMA', 'Avg', @AmcosVersionId);

    DECLARE @B_budget AS NUMERIC(18, 2)
        = crunch.GetArmyBudgetSingleValue('Training-Recruit', 'OMA', 'Avg', @AmcosVersionId);

    DECLARE @PC_budget AS NUMERIC(18, 2)
        = crunch.GetArmyBudgetSingleValue('Training-Professional Development Education', 'OMA', 'Avg', @AmcosVersionId);

    DECLARE @AIT_IET_budget AS NUMERIC(18, 2)
        = crunch.GetArmyBudgetSingleValue('Training-Specialized Skill', 'OMA', 'Avg', @AmcosVersionId);

    DECLARE @BudgetTrainingFlight AS NUMERIC(18, 2)
        = crunch.GetArmyBudgetSingleValue('Training-Flight', 'OMA', 'Avg', @AmcosVersionId);

    DECLARE @BudgetTrainingSupport AS NUMERIC(18, 2)
        = crunch.GetArmyBudgetSingleValue('Training-Support', 'OMA', 'Avg', @AmcosVersionId);

    SET @Training_Budget_Total
        = @OSUT_Budget + @B_budget + @PC_budget + @AIT_IET_budget + @BudgetTrainingSupport + @BudgetTrainingFlight;


    --compute the factors
    SET @OSUT_Perc = @OSUT_Budget / @OSUT_Total;
    SET @B_perc = @B_budget / @B_Total;
    SET @PC_perc = @PC_budget / @PC_total;
    SET @AIT_IET_Perc = @AIT_IET_budget / @AIT_IET_Total;

    --bring the factors into our table
    UPDATE crunch_temp.TrainingCostsAverage
    SET MPA_adj = mpa_total_avg_cost * @OSUT_Perc,
        OMA_adj = oma_total_avg_cost * @OSUT_Perc,
        Other_adj = other_total_avg_cost * @OSUT_Perc
    WHERE CourseTypeFinal IN ( 'OSUT' );
    UPDATE crunch_temp.TrainingCostsAverage
    SET MPA_adj = mpa_total_avg_cost * @B_perc,
        OMA_adj = oma_total_avg_cost * @B_perc,
        Other_adj = other_total_avg_cost * @B_perc
    WHERE CourseTypeFinal IN ( 'B' );
    UPDATE crunch_temp.TrainingCostsAverage
    SET MPA_adj = mpa_total_avg_cost * @PC_perc,
        OMA_adj = oma_total_avg_cost * @PC_perc,
        Other_adj = other_total_avg_cost * @PC_perc
    WHERE CourseTypeFinal IN ( 'P', 'C' );
    UPDATE crunch_temp.TrainingCostsAverage
    SET MPA_adj = mpa_total_avg_cost * @AIT_IET_Perc,
        OMA_adj = oma_total_avg_cost * @AIT_IET_Perc,
        Other_adj = other_total_avg_cost * @AIT_IET_Perc
    WHERE CourseTypeFinal IN ( 'AIT', 'IET' );
    UPDATE crunch_temp.TrainingCostsAverage
    SET MPA_adj = mpa_total_avg_cost,
        OMA_adj = oma_total_avg_cost,
        Other_adj = other_total_avg_cost
    WHERE CourseTypeFinal IN ( 'W', 'F', 'O' );
    SET @Unallocated_Training_Budget = @Training_Budget_Total -
                                       (
                                           SELECT SUM(OMA_adj) + SUM(Other_adj)
                                           FROM crunch_temp.TrainingCostsAverage
                                       );
    SET @unallocated_budget_per_soldier = @Unallocated_Training_Budget /
                                          (
                                              SELECT SUM(Inventory)
                                              FROM data.Inventory
                                              WHERE PayPlan IN ( 'AO', 'AWO', 'AE' )
                                                    AND AmcosVersionId = @AmcosVersionId
                                          );
    IF @Debug = 1
    BEGIN
        SELECT 'total table thus far';
        SELECT CourseTypeFinal,
               SUM(mpa_total_avg_cost) AS mpa_total,
               (SUM(oma_total_avg_cost) + SUM(other_total_avg_cost)) AS OMA,
               SUM(MPA_adj) AS mpa_adj,
               (SUM(OMA_adj) + SUM(Other_adj)) AS oma_adj
        FROM crunch_temp.TrainingCostsAverage
        GROUP BY CourseTypeFinal;

        SET @MessageText = CONCAT('OSUT_Amt ', FORMAT(@OSUT_Total, 'C', 'en-us'));
        RAISERROR(@MessageText, 10, 1) WITH NOWAIT;

        SET @MessageText = CONCAT('OSUT_Budget', FORMAT(@OSUT_Budget, 'C', 'en-us'));
        RAISERROR(@MessageText, 10, 1) WITH NOWAIT;

        SET @MessageText = CONCAT('OSUT Perc ', @OSUT_Perc);
        RAISERROR(@MessageText, 10, 1) WITH NOWAIT;

        SET @MessageText = CONCAT('B_Amt ', FORMAT(@B_Total, 'C', 'en-us'));
        RAISERROR(@MessageText, 10, 1) WITH NOWAIT;

        SET @MessageText = CONCAT('B_Budget', FORMAT(@B_budget, 'C', 'en-us'));
        RAISERROR(@MessageText, 10, 1) WITH NOWAIT;

        SET @MessageText = CONCAT('B Perc ', @B_perc);
        RAISERROR(@MessageText, 10, 1) WITH NOWAIT;

        SET @MessageText = CONCAT('PC_Amt ', FORMAT(@PC_total, 'C', 'en-us'));
        RAISERROR(@MessageText, 10, 1) WITH NOWAIT;

        SET @MessageText = CONCAT('PC_Budget', FORMAT(@PC_budget, 'C', 'en-us'));
        RAISERROR(@MessageText, 10, 1) WITH NOWAIT;

        SET @MessageText = CONCAT('PC Perc ', @PC_perc);
        RAISERROR(@MessageText, 10, 1) WITH NOWAIT;

        SET @MessageText = CONCAT('AIT IET_Amt ', FORMAT(@AIT_IET_Total, 'C', 'en-us'));
        RAISERROR(@MessageText, 10, 1) WITH NOWAIT;

        SET @MessageText = CONCAT('AIT IET_Budget', FORMAT(@AIT_IET_budget, 'C', 'en-us'));
        RAISERROR(@MessageText, 10, 1) WITH NOWAIT;

        SET @MessageText = CONCAT('AIT IET Perc ', @AIT_IET_Perc);
        RAISERROR(@MessageText, 10, 1) WITH NOWAIT;

        SET @MessageText = CONCAT('Training Budget', FORMAT(@Training_Budget_Total, 'C', 'en-us'));
        RAISERROR(@MessageText, 10, 1) WITH NOWAIT;

        SET @MessageText = CONCAT('Unallocated Training Budget', FORMAT(@Unallocated_Training_Budget, 'C', 'en-us'));
        RAISERROR(@MessageText, 10, 1) WITH NOWAIT;

        SET @MessageText
            = CONCAT('Unallocated Training Budget per soldier', FORMAT(@unallocated_budget_per_soldier, 'C', 'en-us'));
        RAISERROR(@MessageText, 10, 1) WITH NOWAIT;

    END;

    -- =============================================
    --generate final costs
    -- =============================================

    /* We have to start with the inventory table, this is because we may have an MOS with no MOS specific costs
    but it still should get CMF or PayPlan total costs.  If we started with the ATRM/ATRRS table we might miss those
    Then we left join with the summation table, this makes sure multiple entries for Crs Type W (Weapon system) are
    also included in case there are costs at the CMF or Pay Plan level */
    IF @Debug = 1
    BEGIN
        SET @MessageText = CONCAT(N'Starting to insert into TempTrainingCosts ', CAST(SYSDATETIME() AS NVARCHAR(30)));
        RAISERROR(@MessageText, 10, 1) WITH NOWAIT;
    END;

    INSERT INTO crunch_temp.TrainingCosts
    (
        PayPlan,
        CategoryGroupCode,
        CategorySubgroupCode,
        GradeType,
        GradeLevel,
        WeaponSystemName,
        CourseType,
        Inventory,
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
           a.CategorySubgroupCode,
           a.GradeType,
           a.GradeLevel,
           a.WeaponSystemName,
           a.CourseType,
           a.Inventory,
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
           NULL AS WeaponSystemId
    FROM
    (
        SELECT a.*,
               b.CourseType,
               b.WeaponSystemName
        FROM
        (
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   GradeType,
                   GradeLevel,
                   SUM(Inventory) AS Inventory
            FROM data.KnownInventory
            WHERE PayPlan IN ( 'AE', 'AO', 'AWO', 'NE', 'NO', 'NWO', 'RE', 'RO', 'RWO' )
                  AND AmcosVersionId = @AmcosVersionId
            GROUP BY PayPlan,
                     CategoryGroupCode,
                     CategorySubgroupCode,
                     GradeType,
                     GradeLevel
        ) AS a
            FULL OUTER JOIN
            (
                --use our average cost table as the source for all possible course type and wpn combinations
                SELECT PayPlan,
                       CourseTypeFinal AS CourseType,
                       WeaponSystemName
                FROM crunch_temp.TrainingCostsAverage
                WHERE CourseTypeFinal IS NOT NULL
                GROUP BY PayPlan,
                         CourseTypeFinal,
                         WeaponSystemName
                UNION
                --the following gives us a course type for general training costs from the budget
                SELECT 'AO' AS PayPlan,
                       'G' AS CourseTypeFinal,
                       'Not Applicable' AS WeaponSystemName
                UNION
                SELECT 'AE' AS PayPlan,
                       'G' AS CourseTypeFinal,
                       'Not Applicable' AS WeaponSystemName
                UNION
                SELECT 'AWO' AS PayPlan,
                       'G' AS CourseTypeFinal,
                       'Not Applicable' AS WeaponSystemName
                UNION
                SELECT 'RO' AS PayPlan,
                       'G' AS CourseTypeFinal,
                       'Not Applicable' AS WeaponSystemName
                UNION
                SELECT 'RE' AS PayPlan,
                       'G' AS CourseTypeFinal,
                       'Not Applicable' AS WeaponSystemName
                UNION
                SELECT 'RWO' AS PayPlan,
                       'G' AS CourseTypeFinal,
                       'Not Applicable' AS WeaponSystemName
                UNION
                SELECT 'NO' AS PayPlan,
                       'G' AS CourseTypeFinal,
                       'Not Applicable' AS WeaponSystemName
                UNION
                SELECT 'NE' AS PayPlan,
                       'G' AS CourseTypeFinal,
                       'Not Applicable' AS WeaponSystemName
                UNION
                SELECT 'NWO' AS PayPlan,
                       'G' AS CourseTypeFinal,
                       'Not Applicable' AS WeaponSystemName
                --our business rules indicate that for the active IET is only for officer/warrants
                --but the JBooks have IET costs for the NG/R enlisted so we need to have a way to capture those
                UNION
                SELECT 'RE' AS PayPlan,
                       'IET' AS CourseTypeFinal,
                       'Not Applicable' AS WeaponSystemName
                UNION
                SELECT 'NE' AS PayPlan,
                       'IET' AS CourseTypeFinal,
                       'Not Applicable' AS WeaponSystemName
            ) AS b
                ON a.PayPlan = b.PayPlan
    ) AS a;

    /* Generate CGLA inventory at the category subgroup level
    compute my CGLA inventory
    cgla is the cummulative inventory at or above any one payplan and subgroup combination
    it is later used to compute CGLA */
    IF @Debug = 1
    BEGIN
        SET @MessageText
            = CONCAT(
                        N'Starting to compute CGLA inventory at the category subgroup level ',
                        CAST(SYSDATETIME() AS NVARCHAR(30))
                    );
        RAISERROR(@MessageText, 10, 1) WITH NOWAIT;
    END;

    UPDATE crunch_temp.TrainingCosts
    SET CGLA_MOS_inv = B.inv_cumulative
    FROM crunch_temp.TrainingCosts AS a
        INNER JOIN
        (
            --compute the reverse sum which will later be used to do Cross Grade Level Allocation (CGLA)
            SELECT PayPlan,
                   CategorySubgroupCode,
                   GradeType,
                   GradeLevel,
                   Inventory,
                   SUM(Inventory) OVER (PARTITION BY PayPlan,
                                                     CategorySubgroupCode
                                        ORDER BY PayPlan,
                                                 CategorySubgroupCode,
                                                 GradeLevel DESC
                                       ) + crunch.GetParentInventory(PayPlan, CategorySubgroupCode, @AmcosVersionId) AS inv_cumulative
            FROM
            (
                SELECT PayPlan,
                       CategorySubgroupCode,
                       GradeType,
                       GradeLevel,
                       SUM(Inventory) AS Inventory
                FROM data.KnownInventory
                WHERE AmcosVersionId = @AmcosVersionId
                      AND PayPlan IN ( 'AE', 'AO', 'AWO', 'NE', 'NO', 'NWO', 'RE', 'RO', 'RWO' )
                GROUP BY PayPlan,
                         CategorySubgroupCode,
                         GradeType,
                         GradeLevel
            ) AS A
            GROUP BY PayPlan,
                     CategorySubgroupCode,
                     GradeType,
                     GradeLevel,
                     Inventory
        ) AS B
            ON a.PayPlan = B.PayPlan
               AND a.CategorySubgroupCode = B.CategorySubgroupCode
               AND a.GradeLevel = B.GradeLevel;

    /* Generate CGLA inventory at the category group level
    --compute my CGLA inventory
    --cgla is the cummulative inventory at or above any one payplan & subgroup combination
    --it is later used to compute CGLA */
    IF @Debug = 1
    BEGIN
        SET @MessageText
            = CONCAT(
                        N'Starting to compute CGLA inventory at the category group level ',
                        CAST(SYSDATETIME() AS NVARCHAR(30))
                    );
        RAISERROR(@MessageText, 10, 1) WITH NOWAIT;
    END;

    UPDATE crunch_temp.TrainingCosts
    SET CGLA_CMF_Inv = B.inv_cumulative
    FROM crunch_temp.TrainingCosts AS A
        INNER JOIN
        (
            --compute the reverse sum which wil later be used to do Cross Grade Level Allocation (CGLA)
            SELECT PayPlan,
                   CategoryGroupCode,
                   GradeType,
                   GradeLevel,
                   Inventory,
                   SUM(Inventory) OVER (PARTITION BY PayPlan,
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
                       SUM(Inventory) AS Inventory
                FROM data.KnownInventory
                WHERE AmcosVersionId = @AmcosVersionId
                      AND PayPlan IN ( 'AE', 'AO', 'AWO', 'NE', 'NO', 'NWO', 'RE', 'RO', 'RWO' )
                GROUP BY PayPlan,
                         CategoryGroupCode,
                         GradeType,
                         GradeLevel
            ) AS A
            GROUP BY PayPlan,
                     CategoryGroupCode,
                     GradeType,
                     GradeLevel,
                     Inventory
        ) AS B
            --no change is needed to this where because only final_mos with a length of 2 (CMF level) will catch on this 'on' clause
            ON A.PayPlan = B.PayPlan
               AND A.CategoryGroupCode = B.CategoryGroupCode
               AND A.GradeLevel = B.GradeLevel;


    /* Generate CGLA inventory at the pay plan level
    compute my CGLA inventory
    cgla is the cummulative inventory at or above any one payplan & subgroup combination
    it is later used to compute CGLA */
    IF @Debug = 1
    BEGIN
        SET @MessageText
            = CONCAT(N'Starting to compute CGLA inventory at the pay plan level ', CAST(SYSDATETIME() AS NVARCHAR(30)));
        RAISERROR(@MessageText, 10, 1) WITH NOWAIT;
    END;

    UPDATE crunch_temp.TrainingCosts
    SET CGLA_PP_inv = B.inv_cumulative
    FROM crunch_temp.TrainingCosts AS A
        INNER JOIN
        (
            --compute the reverse sum which wil later be used to do Cross Grade Level Allocation (CGLA)
            SELECT PayPlan,
                   GradeType,
                   GradeLevel,
                   Inventory,
                   SUM(Inventory) OVER (PARTITION BY PayPlan ORDER BY PayPlan, GradeLevel DESC) AS inv_cumulative
            FROM
            (
                SELECT PayPlan,
                       GradeType,
                       GradeLevel,
                       SUM(Inventory) AS Inventory
                FROM data.KnownInventory
                WHERE AmcosVersionId = @AmcosVersionId
                      AND PayPlan IN ( 'AE', 'AO', 'AWO', 'NE', 'NO', 'NWO', 'RE', 'RO', 'RWO' )
                GROUP BY PayPlan,
                         GradeType,
                         GradeLevel
            ) AS A
            GROUP BY PayPlan,
                     GradeType,
                     GradeLevel,
                     Inventory
        ) AS B
            ON A.PayPlan = B.PayPlan
               AND A.GradeLevel = B.GradeLevel;

    IF @Debug = 1
    BEGIN
        SELECT 'crunch_temp.TrainingCostsAverage';
        SELECT *
        FROM crunch_temp.TrainingCostsAverage
        WHERE GradeLevelFinal = 1
              AND MOSFinal = '15A'
              AND PayPlan = 'RO';
    END;
    IF @Debug = 1
    BEGIN
        SELECT 'Raw data';
        SELECT *
        FROM crunch_temp.AtrrsAtrmCourseMos
        WHERE GradeLevelFinal = 1
              AND MOSFinal = '15A'
              AND PayPlan = 'RO';
    END;

    --bring in the average total costs from crunch_temp.TrainingCostsAverage for MOS FOR WEAPON SYSTEM only
    UPDATE crunch_temp.TrainingCosts
    SET MPA_MOS = ISNULL(B.MPA_adj, 0),
        OMA_MOS = ISNULL(B.oma_total_avg_cost, 0),
        Other_MOS = ISNULL(B.other_total_avg_cost, 0)
    FROM crunch_temp.TrainingCosts AS A
        INNER JOIN crunch_temp.TrainingCostsAverage AS B
            ON A.PayPlan = B.PayPlan
               AND A.CategorySubgroupCode = B.MOSFinal
               AND A.GradeLevel = B.GradeLevelFinal
               AND A.CourseType = B.CourseTypeFinal
               AND A.WeaponSystemName = B.WeaponSystemName
    WHERE A.CourseType = 'W';
    IF @Debug = 1
    BEGIN
        SELECT 'Before';
        SELECT *
        FROM crunch_temp.TrainingCosts
        WHERE PayPlan = 'RO'
              AND CategorySubgroupCode = '15A'
              AND GradeLevel = 1;
    END;

    --bring in the average total costs from crunch_temp.TrainingCostsAverage for MOS for non-weapon system
    UPDATE crunch_temp.TrainingCosts
    SET MPA_MOS = ISNULL(B.MPA_adj, 0),
        OMA_MOS = ISNULL(B.OMA_adj, 0),
        Other_MOS = ISNULL(B.Other_adj, 0)
    FROM crunch_temp.TrainingCosts AS A
        INNER JOIN crunch_temp.TrainingCostsAverage AS B
            ON A.PayPlan = B.PayPlan
               AND A.CategorySubgroupCode = B.MOSFinal
               AND A.GradeLevel = B.GradeLevelFinal
               AND A.CourseType = B.CourseTypeFinal
    WHERE A.CourseType <> 'W';
    IF @Debug = 1
    BEGIN
        SELECT 'After';
        SELECT *
        FROM crunch_temp.TrainingCosts
        WHERE PayPlan = 'RO'
              AND CategorySubgroupCode = '15A'
              AND GradeLevel = 1;
    END;

    --bring in the average total costs from crunch_temp.TrainingCostsAverage for CMF for weapon system only
    UPDATE crunch_temp.TrainingCosts
    SET MPA_CMF = ISNULL(B.MPA_adj, 0),
        OMA_CMF = ISNULL(B.OMA_adj, 0),
        Other_CMF = ISNULL(B.Other_adj, 0)
    FROM crunch_temp.TrainingCosts AS A
        INNER JOIN crunch_temp.TrainingCostsAverage AS B
            ON A.PayPlan = B.PayPlan
               AND A.CategoryGroupCode = B.MOSFinal
               AND A.GradeLevel = B.GradeLevelFinal
               AND A.CourseType = B.CourseTypeFinal
               AND A.WeaponSystemName = B.WeaponSystemName
    WHERE A.CourseType = 'W';

    --bring in the average total costs from crunch_temp.TrainingCostsAverage for CMF for non-weapon system
    UPDATE crunch_temp.TrainingCosts
    SET MPA_CMF = ISNULL(B.MPA_adj, 0),
        OMA_CMF = ISNULL(B.OMA_adj, 0),
        Other_CMF = ISNULL(B.Other_adj, 0)
    FROM crunch_temp.TrainingCosts AS A
        INNER JOIN crunch_temp.TrainingCostsAverage AS B
            ON A.PayPlan = B.PayPlan
               AND A.CategoryGroupCode = B.MOSFinal
               AND A.GradeLevel = B.GradeLevelFinal
               AND A.CourseType = B.CourseTypeFinal
    WHERE A.CourseType <> 'W';

    --bring in the average total costs from crunch_temp.TrainingCostsAverage for PP for weapon system only
    UPDATE crunch_temp.TrainingCosts
    SET MPA_PP = ISNULL(B.MPA_adj, 0),
        OMA_PP = ISNULL(B.OMA_adj, 0),
        other_PP = ISNULL(B.Other_adj, 0)
    FROM crunch_temp.TrainingCosts AS A
        INNER JOIN crunch_temp.TrainingCostsAverage AS B
            ON A.PayPlan = B.PayPlan
               AND A.GradeLevel = B.GradeLevelFinal
               AND A.CourseType = B.CourseTypeFinal
               AND A.WeaponSystemName = B.WeaponSystemName
    WHERE B.MOSFinal = 'XXX'
          AND A.CourseType = 'W';

    --bring in the average total costs from crunch_temp.TrainingCostsAverage for PP for non-weapon system only
    UPDATE crunch_temp.TrainingCosts
    SET MPA_PP = ISNULL(B.MPA_adj, 0),
        OMA_PP = ISNULL(B.OMA_adj, 0),
        other_PP = ISNULL(B.Other_adj, 0)
    FROM crunch_temp.TrainingCosts AS A
        INNER JOIN crunch_temp.TrainingCostsAverage AS B
            ON A.PayPlan = B.PayPlan
               AND A.GradeLevel = B.GradeLevelFinal
               AND A.CourseType = B.CourseTypeFinal
    WHERE B.MOSFinal = 'XXX'
          AND A.CourseType <> 'W';

    --bring in the weapon system IDs
    UPDATE crunch_temp.TrainingCosts
    SET WeaponSystemId = WeaponSystem.WeaponSystemId
    FROM crunch_temp.TrainingCosts AS A
        INNER JOIN lookup.WeaponSystem AS WeaponSystem
            ON A.WeaponSystemName = WeaponSystem.WeaponSystemName
    WHERE A.CourseType = 'W'
          AND (@AmcosVersionId
          BETWEEN WeaponSystem.AmcosVersionIdStart AND WeaponSystem.AmcosVersionIdEnd
              );

    --execute the CGLA math to spread a costs at the category subgroup level with weapon system
    UPDATE crunch_temp.TrainingCosts
    SET CGLA_MPA = A.CGLA_MPA + ISNULL(B.mpa, 0),
        CGLA_OMA = A.CGLA_OMA + ISNULL(B.oma, 0),
        CGLA_Other = A.CGLA_Other + ISNULL(B.other, 0)
    FROM crunch_temp.TrainingCosts AS A
        INNER JOIN
        (
            SELECT *,
                   SUM(MPA_MOS / NULLIF(CGLA_MOS_inv, 0)) OVER (PARTITION BY PayPlan,
                                                                             CategorySubgroupCode,
                                                                             CourseType,
                                                                             WeaponSystemName
                                                                ORDER BY PayPlan,
                                                                         CategorySubgroupCode,
                                                                         CourseType,
                                                                         WeaponSystemName,
                                                                         GradeLevel ASC
                                                               --) AS mpa,
                                                               )
                   + crunch.GetChildTrainingWeaponsRecursive(
                                                                PayPlan,
                                                                CategorySubgroupCode,
                                                                GradeType,
                                                                CourseType,
                                                                WeaponSystemName,
                                                                GradeLevel,
                                                                'TrainingMPA',
                                                                @AmcosVersionId
                                                            ) AS mpa,
                   SUM(OMA_MOS / NULLIF(CGLA_MOS_inv, 0)) OVER (PARTITION BY PayPlan,
                                                                             CategorySubgroupCode,
                                                                             CourseType,
                                                                             WeaponSystemName
                                                                ORDER BY PayPlan,
                                                                         CategorySubgroupCode,
                                                                         CourseType,
                                                                         WeaponSystemName,
                                                                         GradeLevel ASC
                                                               --) AS oma,
                                                               )
                   + crunch.GetChildTrainingWeaponsRecursive(
                                                                PayPlan,
                                                                CategorySubgroupCode,
                                                                GradeType,
                                                                CourseType,
                                                                WeaponSystemName,
                                                                GradeLevel,
                                                                'TrainingOMA',
                                                                @AmcosVersionId
                                                            ) AS oma,
                   SUM(Other_MOS / NULLIF(CGLA_MOS_inv, 0)) OVER (PARTITION BY PayPlan,
                                                                               CategorySubgroupCode,
                                                                               CourseType,
                                                                               WeaponSystemName
                                                                  ORDER BY PayPlan,
                                                                           CategorySubgroupCode,
                                                                           CourseType,
                                                                           WeaponSystemName,
                                                                           GradeLevel ASC
                                                                 --) AS other
                                                                 )
                   + crunch.GetChildTrainingWeaponsRecursive(
                                                                PayPlan,
                                                                CategorySubgroupCode,
                                                                GradeType,
                                                                CourseType,
                                                                WeaponSystemName,
                                                                GradeLevel,
                                                                'TrainingOther',
                                                                @AmcosVersionId
                                                            ) AS other
            FROM crunch_temp.TrainingCosts
            WHERE CourseType = 'W'
        ) AS B
            ON A.PayPlan = B.PayPlan
               AND A.CategorySubgroupCode = B.CategorySubgroupCode
               AND A.GradeLevel = B.GradeLevel
               AND A.WeaponSystemName = B.WeaponSystemName
               AND A.CourseType = B.CourseType;

    --execute the CGLA math to spread a costs at the category subgroup level without weapon system
    UPDATE crunch_temp.TrainingCosts
    SET CGLA_MPA = A.CGLA_MPA + ISNULL(B.mpa, 0),
        CGLA_OMA = A.CGLA_OMA + ISNULL(B.oma, 0),
        CGLA_Other = A.CGLA_Other + ISNULL(B.other, 0)
    FROM crunch_temp.TrainingCosts AS A
        INNER JOIN
        (
            SELECT *,
                   SUM(MPA_MOS / NULLIF(CGLA_MOS_inv, 0)) OVER (PARTITION BY PayPlan,
                                                                             CategorySubgroupCode,
                                                                             CourseType
                                                                ORDER BY PayPlan,
                                                                         CategorySubgroupCode,
                                                                         CourseType,
                                                                         GradeLevel ASC
                                                               --) AS mpa,
                                                               )
                   + crunch.GetChildTrainingRecursive(
                                                         PayPlan,
                                                         CategorySubgroupCode,
                                                         GradeType,
                                                         CourseType,
                                                         GradeLevel,
                                                         'TrainingMPA',
                                                         @AmcosVersionId
                                                     ) AS mpa,
                   SUM(OMA_MOS / NULLIF(CGLA_MOS_inv, 0)) OVER (PARTITION BY PayPlan,
                                                                             CategorySubgroupCode,
                                                                             CourseType
                                                                ORDER BY PayPlan,
                                                                         CategorySubgroupCode,
                                                                         CourseType,
                                                                         GradeLevel ASC
                                                               --) AS oma,
                                                               )
                   + crunch.GetChildTrainingRecursive(
                                                         PayPlan,
                                                         CategorySubgroupCode,
                                                         GradeType,
                                                         CourseType,
                                                         GradeLevel,
                                                         'TrainingOMA',
                                                         @AmcosVersionId
                                                     ) AS oma,
                   SUM(Other_MOS / NULLIF(CGLA_MOS_inv, 0)) OVER (PARTITION BY PayPlan,
                                                                               CategorySubgroupCode,
                                                                               CourseType
                                                                  ORDER BY PayPlan,
                                                                           CategorySubgroupCode,
                                                                           CourseType,
                                                                           GradeLevel ASC
                                                                 --) AS other
                                                                 )
                   + crunch.GetChildTrainingRecursive(
                                                         PayPlan,
                                                         CategorySubgroupCode,
                                                         GradeType,
                                                         CourseType,
                                                         GradeLevel,
                                                         'TrainingOther',
                                                         @AmcosVersionId
                                                     ) AS other
            FROM crunch_temp.TrainingCosts
            WHERE CourseType <> 'W'
        ) AS B
            ON A.PayPlan = B.PayPlan
               AND A.CategorySubgroupCode = B.CategorySubgroupCode
               AND A.GradeLevel = B.GradeLevel
               AND A.CourseType = B.CourseType;

    --execute the CGLA math to spread a costs at the category group level with weapon system
    UPDATE crunch_temp.TrainingCosts
    SET CGLA_MPA = A.CGLA_MPA + ISNULL(B.mpa, 0),
        CGLA_OMA = A.CGLA_OMA + ISNULL(B.oma, 0),
        CGLA_Other = A.CGLA_Other + ISNULL(B.other, 0)
    FROM crunch_temp.TrainingCosts AS A
        INNER JOIN
        (
            SELECT *,
                   SUM(MPA_CMF / NULLIF(CGLA_CMF_Inv, 0)) OVER (PARTITION BY PayPlan,
                                                                             CategorySubgroupCode,
                                                                             CourseType,
                                                                             WeaponSystemName
                                                                ORDER BY PayPlan,
                                                                         CategorySubgroupCode,
                                                                         CourseType,
                                                                         WeaponSystemName,
                                                                         GradeLevel ASC
                                                               ) AS mpa,
                   SUM(OMA_CMF / NULLIF(CGLA_CMF_Inv, 0)) OVER (PARTITION BY PayPlan,
                                                                             CategorySubgroupCode,
                                                                             CourseType,
                                                                             WeaponSystemName
                                                                ORDER BY PayPlan,
                                                                         CategorySubgroupCode,
                                                                         CourseType,
                                                                         WeaponSystemName,
                                                                         GradeLevel ASC
                                                               ) AS oma,
                   SUM(Other_CMF / NULLIF(CGLA_CMF_Inv, 0)) OVER (PARTITION BY PayPlan,
                                                                               CategorySubgroupCode,
                                                                               CourseType,
                                                                               WeaponSystemName
                                                                  ORDER BY PayPlan,
                                                                           CategorySubgroupCode,
                                                                           CourseType,
                                                                           WeaponSystemName,
                                                                           GradeLevel ASC
                                                                 ) AS other
            FROM crunch_temp.TrainingCosts
            WHERE CourseType = 'W'
        ) AS B
            ON A.PayPlan = B.PayPlan
               AND A.CategorySubgroupCode = B.CategorySubgroupCode
               AND A.GradeLevel = B.GradeLevel
               AND A.WeaponSystemName = B.WeaponSystemName
               AND A.CourseType = B.CourseType;

    --execute the CGLA math to spread a costs at the category group level without weapon system
    UPDATE crunch_temp.TrainingCosts
    SET CGLA_MPA = A.CGLA_MPA + ISNULL(B.mpa, 0),
        CGLA_OMA = A.CGLA_OMA + ISNULL(B.oma, 0),
        CGLA_Other = A.CGLA_Other + ISNULL(B.other, 0)
    FROM crunch_temp.TrainingCosts AS A
        INNER JOIN
        (
            SELECT *,
                   SUM(MPA_CMF / NULLIF(CGLA_CMF_Inv, 0)) OVER (PARTITION BY PayPlan,
                                                                             CategorySubgroupCode,
                                                                             CourseType
                                                                ORDER BY PayPlan,
                                                                         CategorySubgroupCode,
                                                                         CourseType,
                                                                         GradeLevel ASC
                                                               ) AS mpa,
                   SUM(OMA_CMF / NULLIF(CGLA_CMF_Inv, 0)) OVER (PARTITION BY PayPlan,
                                                                             CategorySubgroupCode,
                                                                             CourseType
                                                                ORDER BY PayPlan,
                                                                         CategorySubgroupCode,
                                                                         CourseType,
                                                                         GradeLevel ASC
                                                               ) AS oma,
                   SUM(Other_CMF / NULLIF(CGLA_CMF_Inv, 0)) OVER (PARTITION BY PayPlan,
                                                                               CategorySubgroupCode,
                                                                               CourseType
                                                                  ORDER BY PayPlan,
                                                                           CategorySubgroupCode,
                                                                           CourseType,
                                                                           GradeLevel ASC
                                                                 ) AS other
            FROM crunch_temp.TrainingCosts
            WHERE CourseType <> 'W'
        ) AS B
            ON A.PayPlan = B.PayPlan
               AND A.CategorySubgroupCode = B.CategorySubgroupCode
               AND A.GradeLevel = B.GradeLevel
               AND A.CourseType = B.CourseType;

    --execute the CGLA math to spread a costs at the PayPlan level with weapon system
    UPDATE crunch_temp.TrainingCosts
    SET CGLA_MPA = A.CGLA_MPA + ISNULL(B.mpa, 0),
        CGLA_OMA = A.CGLA_OMA + ISNULL(B.oma, 0),
        CGLA_Other = A.CGLA_Other + ISNULL(B.other, 0)
    FROM crunch_temp.TrainingCosts AS A
        INNER JOIN
        (
            SELECT *,
                   SUM(MPA_PP / NULLIF(CGLA_PP_inv, 0)) OVER (PARTITION BY PayPlan,
                                                                           CategorySubgroupCode,
                                                                           CourseType,
                                                                           WeaponSystemName
                                                              ORDER BY PayPlan,
                                                                       CategorySubgroupCode,
                                                                       CourseType,
                                                                       WeaponSystemName,
                                                                       GradeLevel ASC
                                                             ) AS mpa,
                   SUM(OMA_PP / NULLIF(CGLA_PP_inv, 0)) OVER (PARTITION BY PayPlan,
                                                                           CategorySubgroupCode,
                                                                           CourseType,
                                                                           WeaponSystemName
                                                              ORDER BY PayPlan,
                                                                       CategorySubgroupCode,
                                                                       CourseType,
                                                                       WeaponSystemName,
                                                                       GradeLevel ASC
                                                             ) AS oma,
                   SUM(other_PP / NULLIF(CGLA_PP_inv, 0)) OVER (PARTITION BY PayPlan,
                                                                             CategorySubgroupCode,
                                                                             CourseType,
                                                                             WeaponSystemName
                                                                ORDER BY PayPlan,
                                                                         CategorySubgroupCode,
                                                                         CourseType,
                                                                         WeaponSystemName,
                                                                         GradeLevel ASC
                                                               ) AS other
            FROM crunch_temp.TrainingCosts
            WHERE CourseType = 'W'
        ) AS B
            ON A.PayPlan = B.PayPlan
               AND A.CategorySubgroupCode = B.CategorySubgroupCode
               AND A.GradeLevel = B.GradeLevel
               AND A.WeaponSystemName = B.WeaponSystemName
               AND A.CourseType = B.CourseType;

    /* Execute the CGLA math to spread a costs at the PayPlan level without weapon system */
    UPDATE crunch_temp.TrainingCosts
    SET CGLA_MPA = A.CGLA_MPA + ISNULL(B.mpa, 0),
        CGLA_OMA = A.CGLA_OMA + ISNULL(B.oma, 0),
        CGLA_Other = A.CGLA_Other + ISNULL(B.other, 0)
    FROM crunch_temp.TrainingCosts AS A
        INNER JOIN
        (
            SELECT *,
                   SUM(MPA_PP / NULLIF(CGLA_PP_inv, 0)) OVER (PARTITION BY PayPlan,
                                                                           CategorySubgroupCode,
                                                                           CourseType
                                                              ORDER BY PayPlan,
                                                                       CategorySubgroupCode,
                                                                       CourseType,
                                                                       GradeLevel ASC
                                                             ) AS mpa,
                   SUM(OMA_PP / NULLIF(CGLA_PP_inv, 0)) OVER (PARTITION BY PayPlan,
                                                                           CategorySubgroupCode,
                                                                           CourseType
                                                              ORDER BY PayPlan,
                                                                       CategorySubgroupCode,
                                                                       CourseType,
                                                                       GradeLevel ASC
                                                             ) AS oma,
                   SUM(other_PP / NULLIF(CGLA_PP_inv, 0)) OVER (PARTITION BY PayPlan,
                                                                             CategorySubgroupCode,
                                                                             CourseType
                                                                ORDER BY PayPlan,
                                                                         CategorySubgroupCode,
                                                                         CourseType,
                                                                         GradeLevel ASC
                                                               ) AS other
            FROM crunch_temp.TrainingCosts
            WHERE CourseType <> 'W'
        ) AS B
            ON A.PayPlan = B.PayPlan
               AND A.CategorySubgroupCode = B.CategorySubgroupCode
               AND A.GradeLevel = B.GradeLevel
               AND A.CourseType = B.CourseType;

    /* Assign the unallocated training costs to the G CourseType in a Payplan Average (PPA)
	way but only to the active component, the reserves have their own budget process for G costs */
    UPDATE crunch_temp.TrainingCosts
    SET CGLA_OMA = CGLA_OMA + @unallocated_budget_per_soldier
    WHERE CourseType = 'G'
          AND PayPlan IN ( 'AO', 'AE', 'AWO' );

    -- =============================================
    --Bring in Army Reserve and National Guard Specific costs
    -- =============================================
    DECLARE @AR_All AS NUMERIC(18, 2);
    DECLARE @NG_All AS NUMERIC(18, 2);
    DECLARE @AR_E AS NUMERIC(18, 2);
    DECLARE @NG_E AS NUMERIC(18, 2);
    SET @AR_All =
    (
        SELECT SUM(Inventory)
        FROM data.KnownInventory
        WHERE PayPlan IN ( 'RO', 'RWO', 'RE' )
    );
    SET @NG_All =
    (
        SELECT SUM(Inventory)
        FROM data.KnownInventory
        WHERE PayPlan IN ( 'NO', 'NWO', 'NE' )
    );
    SET @AR_E =
    (
        SELECT SUM(Inventory)FROM data.KnownInventory WHERE PayPlan IN ( 'RE' )
    );
    SET @NG_E =
    (
        SELECT SUM(Inventory)FROM data.KnownInventory WHERE PayPlan IN ( 'NE' )
    );
    DECLARE @IET_RPA AS NUMERIC(18, 2),
            @IET_NGPA AS NUMERIC(18, 2),
            @IET_OMAR AS NUMERIC(18, 2),
            @IET_OMNG AS NUMERIC(18, 2),
            @IET_RPA_soldier AS NUMERIC(18, 2),
            @IET_NGPA_soldier AS NUMERIC(18, 2),
            @IET_OMAR_soldier AS NUMERIC(18, 2),
            @IET_OMNG_soldier AS NUMERIC(18, 2),
            @AIT_RPA AS NUMERIC(18, 2),
            @AIT_NGPA AS NUMERIC(18, 2),
            @AIT_OMAR AS NUMERIC(18, 2),
            @AIT_OMNG AS NUMERIC(18, 2),
            @AIT_RPA_soldier AS NUMERIC(18, 2),
            @AIT_NGPA_soldier AS NUMERIC(18, 2),
            @AIT_OMAR_soldier AS NUMERIC(18, 2),
            @AIT_OMNG_soldier AS NUMERIC(18, 2),
            @MOS_Qual_RPA AS NUMERIC(18, 2),
            @MOS_Qual_NGPA AS NUMERIC(18, 2),
            @MOS_Qual_OMAR AS NUMERIC(18, 2),
            @MOS_Qual_OMNG AS NUMERIC(18, 2),
            @MOS_Qual_RPA_soldier AS NUMERIC(18, 2),
            @MOS_Qual_NGPA_soldier AS NUMERIC(18, 2),
            @MOS_Qual_OMAR_soldier AS NUMERIC(18, 2),
            @MOS_Qual_OMNG_soldier AS NUMERIC(18, 2),
            @G_RPA AS NUMERIC(18, 2),
            @G_NGPA AS NUMERIC(18, 2),
            @G_OMAR AS NUMERIC(18, 2),
            @G_OMNG AS NUMERIC(18, 2),
            @G_RPA_soldier AS NUMERIC(18, 2),
            @G_NGPA_soldier AS NUMERIC(18, 2),
            @G_OMAR_soldier AS NUMERIC(18, 2),
            @G_OMNG_soldier AS NUMERIC(18, 2),
            @P_RPA AS NUMERIC(18, 2),
            @P_NGPA AS NUMERIC(18, 2),
            @P_OMAR AS NUMERIC(18, 2),
            @P_OMNG AS NUMERIC(18, 2),
            @P_RPA_soldier AS NUMERIC(18, 2),
            @P_NGPA_soldier AS NUMERIC(18, 2),
            @P_OMAR_soldier AS NUMERIC(18, 2),
            @P_OMNG_soldier AS NUMERIC(18, 2);

    --beginning in 2023 the army got rid of specific training costs in the budget for NG/R so this code only is rellevant for certain FYs
    IF (@AmcosVersionId BETWEEN 202001 AND 202201)
    BEGIN

        --According to the 2018 NGPA book IET is for " non-prior service enlisted Soldiers attending IET"
        SET @IET_RPA = crunch.GetArmyBudgetSingleValue('Training-IET', 'RPA', 'Avg', @AmcosVersionId);

        SET @IET_OMAR = crunch.GetArmyBudgetSingleValue('Training-IET', 'OMAR', 'Avg', @AmcosVersionId);

        SET @IET_NGPA = crunch.GetArmyBudgetSingleValue('Training-IET', 'NGPA', 'Avg', @AmcosVersionId);

        SET @IET_OMNG = crunch.GetArmyBudgetSingleValue('Training-IET', 'OMNG', 'Avg', @AmcosVersionId);

        SET @IET_RPA_soldier = @IET_RPA / @AR_E;
        SET @IET_OMAR_soldier = @IET_OMAR / @AR_E;
        SET @IET_NGPA_soldier = @IET_NGPA / @NG_E;
        SET @IET_OMNG_soldier = @IET_OMNG / @AR_E;

        UPDATE crunch_temp.TrainingCosts
        SET RPA_NGPA = @IET_RPA_soldier,
            OMAR_OMNG = @IET_OMAR_soldier
        WHERE CourseType = 'IET'
              AND PayPlan IN ( 'RE' );

        UPDATE crunch_temp.TrainingCosts
        SET RPA_NGPA = @IET_NGPA_soldier,
            OMAR_OMNG = @IET_OMNG_soldier
        WHERE CourseType = 'IET'
              AND PayPlan IN ( 'NE' );

        IF @Debug = 1
        BEGIN
            SET @MessageText = CONCAT('IET RPA Budget ', FORMAT(@IET_RPA, 'C', 'en-us'));
            RAISERROR(@MessageText, 10, 1) WITH NOWAIT;

            SET @MessageText = CONCAT('IET RPA per soldier', FORMAT(@IET_RPA_soldier, 'C', 'en-us'));
            RAISERROR(@MessageText, 10, 1) WITH NOWAIT;

            SET @MessageText = CONCAT('IET OMAR Budget', FORMAT(@IET_OMAR, 'C', 'en-us'));
            RAISERROR(@MessageText, 10, 1) WITH NOWAIT;

            SET @MessageText = CONCAT('IET OMAR per soldier', FORMAT(@IET_OMAR_soldier, 'C', 'en-us'));
            RAISERROR(@MessageText, 10, 1) WITH NOWAIT;

            SET @MessageText = CONCAT('IET NGPA Budget', FORMAT(@IET_NGPA, 'C', 'en-us'));
            RAISERROR(@MessageText, 10, 1) WITH NOWAIT;

            SET @MessageText = CONCAT('IET NGPA per soldier', FORMAT(@IET_NGPA_soldier, 'C', 'en-us'));
            RAISERROR(@MessageText, 10, 1) WITH NOWAIT;

            SET @MessageText = CONCAT('IET OMNG Budget', FORMAT(@IET_OMNG, 'C', 'en-us'));
            RAISERROR(@MessageText, 10, 1) WITH NOWAIT;

            SET @MessageText = CONCAT('IET OMNG per soldier', FORMAT(@IET_OMNG_soldier, 'C', 'en-us'));
            RAISERROR(@MessageText, 10, 1) WITH NOWAIT;
        END;

        --According to the 2018 NGPA book initial skills is for all soldiers, however we reclassify O/WO costs as IET since IET is for officers
        SET @AIT_RPA = crunch.GetArmyBudgetSingleValue('Training-Initial SKills', 'RPA', 'Avg', @AmcosVersionId);

        SET @AIT_OMAR = crunch.GetArmyBudgetSingleValue('Training-Initial SKills', 'OMAR', 'Avg', @AmcosVersionId);

        SET @AIT_NGPA = crunch.GetArmyBudgetSingleValue('Training-Initial SKills', 'NGPA', 'Avg', @AmcosVersionId);

        SET @AIT_OMNG = crunch.GetArmyBudgetSingleValue('Training-Initial SKills', 'OMNG', 'Avg', @AmcosVersionId);

        SET @AIT_RPA_soldier = @AIT_RPA / @AR_All;
        SET @AIT_OMAR_soldier = @AIT_OMAR / @AR_All;
        SET @AIT_NGPA_soldier = @AIT_NGPA / @NG_All;
        SET @AIT_OMNG_soldier = @AIT_OMNG / @AR_All;
        UPDATE crunch_temp.TrainingCosts
        SET RPA_NGPA = @AIT_RPA_soldier,
            OMAR_OMNG = @AIT_OMAR_soldier
        WHERE CourseType = 'AIT'
              AND PayPlan IN ( 'RE' );
        UPDATE crunch_temp.TrainingCosts
        SET RPA_NGPA = @AIT_NGPA_soldier,
            OMAR_OMNG = @AIT_OMNG_soldier
        WHERE CourseType = 'AIT'
              AND PayPlan IN ( 'NE' );
        --reclass O/W costs to IET
        UPDATE crunch_temp.TrainingCosts
        SET RPA_NGPA = RPA_NGPA + @AIT_RPA_soldier,
            OMAR_OMNG = OMAR_OMNG + @AIT_OMAR_soldier
        WHERE CourseType = 'IET'
              AND PayPlan IN ( 'RO', 'RWO' );
        UPDATE crunch_temp.TrainingCosts
        SET RPA_NGPA = RPA_NGPA + @AIT_NGPA_soldier,
            OMAR_OMNG = OMAR_OMNG + @AIT_OMNG_soldier
        WHERE CourseType = 'IET'
              AND PayPlan IN ( 'NO', 'NWO' );
        IF @Debug = 1
        BEGIN
            SET @MessageText = CONCAT('AIT/IET RPA Budget ', FORMAT(@AIT_RPA, 'C', 'en-us'));
            RAISERROR(@MessageText, 10, 1) WITH NOWAIT;

            SET @MessageText = CONCAT('AIT/IET RPA per soldier', FORMAT(@AIT_RPA_soldier, 'C', 'en-us'));
            RAISERROR(@MessageText, 10, 1) WITH NOWAIT;

            SET @MessageText = CONCAT('AIT/IET OMAR Budget', FORMAT(@AIT_OMAR, 'C', 'en-us'));
            RAISERROR(@MessageText, 10, 1) WITH NOWAIT;

            SET @MessageText = CONCAT('AIT/IET OMAR per soldier', FORMAT(@AIT_OMAR_soldier, 'C', 'en-us'));
            RAISERROR(@MessageText, 10, 1) WITH NOWAIT;

            SET @MessageText = CONCAT('AIT/IET NGPA Budget', FORMAT(@AIT_NGPA, 'C', 'en-us'));
            RAISERROR(@MessageText, 10, 1) WITH NOWAIT;

            SET @MessageText = CONCAT('AIT/IET NGPA per soldier', FORMAT(@AIT_NGPA_soldier, 'C', 'en-us'));
            RAISERROR(@MessageText, 10, 1) WITH NOWAIT;

            SET @MessageText = CONCAT('AIT/IET OMNG Budget', FORMAT(@AIT_OMNG, 'C', 'en-us'));
            RAISERROR(@MessageText, 10, 1) WITH NOWAIT;

            SET @MessageText = CONCAT('AIT/IET OMNG per soldier', FORMAT(@AIT_OMNG_soldier, 'C', 'en-us'));
            RAISERROR(@MessageText, 10, 1) WITH NOWAIT;
        END;

        --MOS qual course is AIT for enlisted only
        SET @MOS_Qual_RPA
            = crunch.GetArmyBudgetSingleValue('Training-MOS Qualification', 'RPA', 'Avg', @AmcosVersionId);

        SET @MOS_Qual_OMAR
            = crunch.GetArmyBudgetSingleValue('Training-MOS Qualification', 'OMAR', 'Avg', @AmcosVersionId);

        SET @MOS_Qual_NGPA
            = crunch.GetArmyBudgetSingleValue('Training-MOS Qualification', 'NGPA', 'Avg', @AmcosVersionId);

        SET @MOS_Qual_OMNG
            = crunch.GetArmyBudgetSingleValue('Training-MOS Qualification', 'OMNG', 'Avg', @AmcosVersionId);

        SET @MOS_Qual_RPA_soldier = @MOS_Qual_RPA / @AR_E;
        SET @MOS_Qual_OMAR_soldier = @MOS_Qual_OMAR / @AR_E;
        SET @MOS_Qual_NGPA_soldier = @MOS_Qual_NGPA / @NG_E;
        SET @MOS_Qual_OMNG_soldier = @MOS_Qual_OMNG / @AR_E;
        UPDATE crunch_temp.TrainingCosts
        SET RPA_NGPA = RPA_NGPA + @MOS_Qual_RPA_soldier,
            OMAR_OMNG = OMAR_OMNG + @MOS_Qual_OMAR_soldier
        WHERE CourseType = 'AIT'
              AND PayPlan IN ( 'RE' );
        UPDATE crunch_temp.TrainingCosts
        SET RPA_NGPA = RPA_NGPA + @MOS_Qual_NGPA_soldier,
            OMAR_OMNG = OMAR_OMNG + @MOS_Qual_OMNG_soldier
        WHERE CourseType = 'AIT'
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
        SET @P_RPA = crunch.GetArmyBudgetSingleValue('Training-Professional', 'RPA', 'Avg', @AmcosVersionId);

        SET @P_OMAR = crunch.GetArmyBudgetSingleValue('Training-Professional', 'OMAR', 'Avg', @AmcosVersionId);

        SET @P_NGPA = crunch.GetArmyBudgetSingleValue('Training-Professional', 'NGPA', 'Avg', @AmcosVersionId);

        SET @P_OMNG = crunch.GetArmyBudgetSingleValue('Training-Professional', 'OMNG', 'Avg', @AmcosVersionId);

        SET @P_RPA_soldier = @P_RPA / @AR_All;
        SET @P_OMAR_soldier = @P_OMAR / @AR_All;
        SET @P_NGPA_soldier = @P_NGPA / @NG_All;
        SET @P_OMNG_soldier = @P_OMNG / @AR_All;
        UPDATE crunch_temp.TrainingCosts
        SET RPA_NGPA = @P_RPA_soldier,
            OMAR_OMNG = @P_OMAR_soldier
        WHERE CourseType = 'P'
              AND PayPlan IN ( 'RE', 'RO', 'RWO' );
        UPDATE crunch_temp.TrainingCosts
        SET RPA_NGPA = @P_NGPA_soldier,
            OMAR_OMNG = @P_OMNG_soldier
        WHERE CourseType = 'P'
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

        --the balance is going to go into a General training bucket
        SET @G_RPA
            = crunch.GetArmyBudgetSingleValue('Training-Support', 'RPA', 'Avg', @AmcosVersionId)
              + crunch.GetArmyBudgetSingleValue('Training-Special Skills Training', 'RPA', 'Avg', @AmcosVersionId);

        SET @G_OMAR
            = crunch.GetArmyBudgetSingleValue('Training-Support', 'OMAR', 'Avg', @AmcosVersionId)
              + crunch.GetArmyBudgetSingleValue('Training-Special Skills Training', 'OMAR', 'Avg', @AmcosVersionId);

        SET @G_NGPA
            = crunch.GetArmyBudgetSingleValue('Training-Support', 'NGPA', 'Avg', @AmcosVersionId)
              + crunch.GetArmyBudgetSingleValue('Training-Special Skills Training', 'NGPA', 'Avg', @AmcosVersionId);

        SET @G_OMNG
            = crunch.GetArmyBudgetSingleValue('Training-Support', 'OMNG', 'Avg', @AmcosVersionId)
              + crunch.GetArmyBudgetSingleValue('Training-Special Skills Training', 'OMNG', 'Avg', @AmcosVersionId);

        SET @G_RPA_soldier = @G_RPA / @AR_All;
        SET @G_OMAR_soldier = @G_OMAR / @AR_All;
        SET @G_NGPA_soldier = @G_NGPA / @NG_All;
        SET @G_OMNG_soldier = @G_OMNG / @AR_All;
        UPDATE crunch_temp.TrainingCosts
        SET RPA_NGPA = @G_RPA_soldier,
            OMAR_OMNG = @G_OMAR_soldier
        WHERE CourseType = 'G'
              AND PayPlan IN ( 'RE', 'RO', 'RWO' );
        UPDATE crunch_temp.TrainingCosts
        SET RPA_NGPA = @G_NGPA_soldier,
            OMAR_OMNG = @G_OMNG_soldier
        WHERE CourseType = 'G'
              AND PayPlan IN ( 'NE', 'NO', 'NWO' );
    END;
    IF (@AmcosVersionId >= 202301)
    BEGIN

        --in 2023 the more specific training elements in the pres bud were removed in favor or a more general approach
        --the COR (Marsha Popp) approved the new general cost element for training which are calculated below
        UPDATE crunch_temp.TrainingCosts
        SET RPA_NGPA = crunch.GetArmyBudgetSingleValue('General Training', 'RPA', 'Avg', @AmcosVersionId) / @AR_All,
            OMAR_OMNG = crunch.GetArmyBudgetSingleValue('General Training', 'OMAR', 'Avg', @AmcosVersionId) / @AR_All
        WHERE CourseType = 'G'
              AND PayPlan IN ( 'RE', 'RO', 'RWO' );
        UPDATE crunch_temp.TrainingCosts
        SET RPA_NGPA = crunch.GetArmyBudgetSingleValue('General Training', 'NGPA', 'Avg', @AmcosVersionId) / @NG_All,
            OMAR_OMNG = crunch.GetArmyBudgetSingleValue('General Training', 'OMNG', 'Avg', @AmcosVersionId) / @NG_All
        WHERE CourseType = 'G'
              AND PayPlan IN ( 'NE', 'NO', 'NWO' );
    END;

    --3/15/2021 We started to see too much cost swing between the 3 apache WOMOS codes so we added this 
    --snippet of code to take all the subgroup computed costs for weapon specific costs, weighted average 
    --them, and then re-assign that average back to those three subgroups but for only NG/R due to their
    --small inventory numbers and sporadic training attendance
    UPDATE crunch_temp.TrainingCosts
    SET MPA_MOS = B.mpa_mos,
        OMA_MOS = B.oma_mos,
        Other_MOS = B.other_mos,
        CGLA_MPA = B.cgla_mpa,
        CGLA_OMA = B.cgla_oma,
        CGLA_Other = B.cgla_other
    FROM crunch_temp.TrainingCosts AS A
        INNER JOIN
        (
            SELECT PayPlan,
                   GradeLevel,
                   WeaponSystemId,
                   SUM(MPA_MOS * Inventory) / SUM(Inventory) AS mpa_mos,
                   SUM(OMA_MOS * Inventory) / SUM(Inventory) AS oma_mos,
                   SUM(Other_MOS * Inventory) / SUM(Inventory) AS other_mos,
                   SUM(CGLA_MPA * Inventory) / SUM(Inventory) AS cgla_mpa,
                   SUM(CGLA_OMA * Inventory) / SUM(Inventory) AS cgla_oma,
                   SUM(CGLA_Other * Inventory) / SUM(Inventory) AS cgla_other
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan IN ( 'RWO', 'NWO' )
                  AND CategorySubgroupCode IN ( '152E', '152F', '152H' )
                  AND WeaponSystemId IS NOT NULL
            GROUP BY PayPlan,
                     GradeLevel,
                     WeaponSystemId
        ) AS B
            ON B.GradeLevel = A.GradeLevel
               AND B.PayPlan = A.PayPlan
               AND B.WeaponSystemId = A.WeaponSystemId
    WHERE A.PayPlan IN ( 'RWO', 'NWO' )
          AND A.CategorySubgroupCode IN ( '152E', '152F', '152H' )
          AND A.WeaponSystemId IS NOT NULL;
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
    DELETE FROM crunch_temp.TrainingCosts
    WHERE CGLA_MPA = 0
          AND CGLA_OMA = 0
          AND CGLA_Other = 0
          AND RPA_NGPA = 0
          AND OMAR_OMNG = 0;
    IF @Debug = 1
    BEGIN
        SELECT 'the final table before we bring in inventory';
        SELECT *
        FROM crunch_temp.AtrrsAtrmCourseMos
        --WHERE MOSFinal=@MOS AND PayPlan=@PayPlan
        ORDER BY MOSFinal,
                 GradeFinal,
                 ATRRS_CourseTitle;
        SELECT 'crunch_temp.AtrrsAtrmCourseMos now with inventory and costs';
        SELECT *
        FROM crunch_temp.AtrrsAtrmCourseMos
        --WHERE PayPlan=@PayPlan --AND MOSFinal=@MOS
        ORDER BY MOSFinal,
                 GradeFinal,
                 ATRRS_CourseTitle,
                 AmcosVersionId;
        SELECT 'crunch_temp.TrainingCosts table';
        SELECT *
        FROM crunch_temp.TrainingCosts;
        --wHERE PayPlan=@PayPlan AND CategorySubgroupCode=@MOS
        SELECT 'TempTraining_Costs_sum table';
        SELECT *
        FROM crunch_temp.TrainingCostsByVersion;
        --WHERE  PayPlan=@PayPlan AND MOSFinal=@MOS 
        SELECT 'crunch_temp.TrainingCostsAverage table';
        SELECT *
        FROM crunch_temp.TrainingCostsAverage
        --WHERE  PayPlan=@PayPlan AND MOSFinal=@MOS 
        ORDER BY MOSFinal,
                 GradeLevelFinal,
                 PayPlan;
        SELECT 'the final crunch_temp.TrainingCosts now with all training costs by amount';
        SELECT *
        FROM crunch_temp.TrainingCosts
        --WHERE
        -- ISNULL((CGLA_MPA+CGLA_oma+CGLA_other),0)>0 
        --and
        -- PayPlan=@PayPlan AND CategorySubgroupCode=@MOS 
        ORDER BY (CGLA_MPA + CGLA_OMA + CGLA_Other) DESC;
        SELECT 'the final crunch_temp.TrainingCosts now with all training costs by order';
        SELECT *
        FROM crunch_temp.TrainingCosts
        --WHERE 
        --ISNULL((CGLA_MPA+CGLA_oma+CGLA_other),0)>0 
        --AND 
        --PayPlan=@PayPlan AND  CategorySubgroupCode=@MOS
        ORDER BY CategorySubgroupCode,
                 GradeLevel,
                 CourseType;
        SELECT 'Check the following table for minimum costs by course type that make sense and are comparable across payplans';
        SELECT PayPlan,
               CourseType,
               MIN(NULLIF(CGLA_MPA, 0)) AS mpa,
               (MIN(NULLIF(CGLA_OMA, 0)) + MIN(NULLIF(CGLA_Other, 0))) AS OMA_Other,
               MIN(NULLIF(RPA_NGPA, 0)) AS RPA_NGPA,
               MIN(NULLIF(OMAR_OMNG, 0)) AS omar_omng
        FROM crunch_temp.TrainingCosts
        GROUP BY PayPlan,
                 CourseType;
        SELECT 'Check the following table for minimum costs by payplan that make sense and are comparable across payplans';
        SELECT PayPlan,
               SUM(mpa) AS mpa,
               (SUM(cgla_oma) + SUM(cgla_other)) AS OMA_Other,
               SUM(RPA_NGPA) AS RPA_NGPA,
               SUM(omar_omng) AS omar_omng
        FROM
        (
            SELECT PayPlan,
                   CourseType,
                   MIN(NULLIF(CGLA_MPA, 0)) AS mpa,
                   MIN(NULLIF(CGLA_OMA, 0)) AS cgla_oma,
                   MIN(NULLIF(CGLA_Other, 0)) AS cgla_other,
                   MIN(NULLIF(RPA_NGPA, 0)) AS RPA_NGPA,
                   MIN(NULLIF(OMAR_OMNG, 0)) AS omar_omng
            FROM crunch_temp.TrainingCosts
            GROUP BY PayPlan,
                     CourseType
        ) AS A
        GROUP BY PayPlan;
    END;
    SELECT *
    FROM lookup.CostElement
    WHERE PayPlan = 'NWO'
          AND APPN LIKE '%Federal%';
    IF @Debug = 0
    BEGIN
        -- clear out the existing cost table for all the CE IDs we are about to insert values for
        --AE/AO/AWO: MPA, OMA, OMA_1 for actual and avg costs
        DELETE FROM crunch.Costs_AE
        WHERE CostElementId IN ( 56, 58, 60, 62, 65, 91, 93, 95, 97, 100, 110, 112, 114, 116, 119, 3379, 3381, 3383,
                                 3385, 3387, 3389, 3957, 3958, 3959, 3960, 3961, 3962, 3983, 4022, 4041, 4044, 4059,
                                 4068, 4085, 4086, 4109, 4112, 4127, 4136, 4202, 4203
                               )
              AND AmcosVersionId = @AmcosVersionId;
        DELETE FROM crunch.Costs_AO
        WHERE CostElementId IN ( 163, 165, 167, 184, 186, 188, 194, 196, 198, 649, 650, 651, 670, 671, 672, 3391, 3393,
                                 3395, 3397, 3399, 3401, 3969, 3977, 3986, 3994, 4006, 4008, 4016, 4021, 4045, 4053,
                                 4062, 4071, 4083, 4087, 4113, 4121, 4130, 4139, 4151, 4153
                               )
              AND AmcosVersionId = @AmcosVersionId;
        DELETE FROM crunch.Costs_AWO
        WHERE CostElementId IN ( 237, 239, 241, 252, 254, 256, 265, 267, 269, 686, 687, 688, 692, 693, 694, 3403, 3405,
                                 3407, 3409, 3411, 3413, 3970, 3978, 3987, 3995, 4007, 4009, 4017, 4023, 4046, 4054,
                                 4063, 4072, 4084, 4088, 4114, 4122, 4131, 4140, 4152, 4154
                               )
              AND AmcosVersionId = @AmcosVersionId;
        --NG/R: Have additional APPNsMPA, OMA, OMA_1 for actual and avg costs
        DELETE FROM crunch.Costs_NE
        WHERE CostElementId IN ( 309, 313, 318, 322, 347, 352, 3415, 3417, 3419, 3421, 3423, 3425, 3967, 3971, 3984,
                                 3993, 4004, 4010, 4019, 4028, 4033, 4034, 4037, 4039, 4042, 4047, 4060, 4070, 4081,
                                 4092, 4095, 4097, 4098, 4100, 4103, 4105, 4108, 4110, 4115, 4128, 4138, 4149, 4158,
                                 4162, 4168, 4173, 4176, 4177, 4183
                               )
              AND AmcosVersionId = @AmcosVersionId;
        DELETE FROM crunch.Costs_NO
        WHERE CostElementId IN ( 369, 371, 373, 378, 380, 382, 400, 404, 406, 3029, 3031, 3033, 3035, 3037, 3039, 3427,
                                 3429, 3431, 3433, 3471, 3472, 3972, 3979, 3990, 3996, 4000, 4011, 4018, 4027, 4048,
                                 4057, 4066, 4075, 4077, 4093, 4116, 4125, 4134, 4143, 4145, 4159, 4161, 4167, 4178,
                                 4184, 4208, 4210
                               )
              AND AmcosVersionId = @AmcosVersionId;
        DELETE FROM crunch.Costs_NWO
        WHERE CostElementId IN ( 420, 422, 424, 429, 431, 433, 440, 444, 446, 3041, 3043, 3045, 3047, 3049, 3051, 3435,
                                 3437, 3439, 3441, 3475, 3476, 3973, 3980, 3991, 3997, 4001, 4012, 4020, 4029, 4049,
                                 4058, 4067, 4076, 4078, 4094, 4117, 4126, 4135, 4144, 4146, 4160, 4163, 4169, 4179,
                                 4185, 4209, 4211
                               )
              AND AmcosVersionId = @AmcosVersionId;
        DELETE FROM crunch.Costs_RE
        WHERE CostElementId IN ( 473, 477, 482, 486, 511, 516, 3443, 3445, 3447, 3449, 3451, 3453, 3968, 3974, 3985,
                                 3992, 4005, 4013, 4025, 4031, 4035, 4036, 4038, 4040, 4043, 4050, 4061, 4069, 4082,
                                 4089, 4096, 4099, 4101, 4102, 4104, 4106, 4107, 4111, 4118, 4129, 4137, 4150, 4155,
                                 4165, 4171, 4174, 4175, 4180, 4186
                               )
              AND AmcosVersionId = @AmcosVersionId;
        DELETE FROM crunch.Costs_RO
        WHERE CostElementId IN ( 533, 535, 537, 542, 544, 546, 564, 568, 570, 655, 656, 657, 673, 674, 675, 3455, 3457,
                                 3459, 3461, 3479, 3480, 3975, 3981, 3988, 3998, 4002, 4014, 4024, 4030, 4051, 4055,
                                 4064, 4073, 4079, 4090, 4119, 4123, 4132, 4141, 4147, 4156, 4164, 4170, 4181, 4187,
                                 4204, 4206
                               )
              AND AmcosVersionId = @AmcosVersionId;
        DELETE FROM crunch.Costs_RWO
        WHERE CostElementId IN ( 584, 586, 588, 593, 595, 597, 604, 608, 610, 3017, 3019, 3021, 3023, 3025, 3027, 3463,
                                 3465, 3467, 3469, 3483, 3484, 3976, 3982, 3989, 3999, 4003, 4015, 4026, 4032, 4052,
                                 4056, 4065, 4074, 4080, 4091, 4120, 4124, 4133, 4142, 4148, 4157, 4166, 4172, 4182,
                                 4188, 4205, 4207
                               )
              AND AmcosVersionId = @AmcosVersionId;
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
                CrunchTime,
                AmcosVersionId,
                LocationId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   3957,
                   GradeType,
                   GradeLevel,
                   -1,
                   MPA_PP + MPA_CMF + MPA_MOS,
                   @CrunchTime,
                   @AmcosVersionId,
                   -1
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'AE'
                  AND CourseType = 'B';
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
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   3967,
                   GradeType,
                   GradeLevel,
                   -1,
                   MPA_PP + MPA_CMF + MPA_MOS,
                   @CrunchTime,
                   @AmcosVersionId
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'NE'
                  AND CourseType = 'B';
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
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   3968,
                   GradeType,
                   GradeLevel,
                   -1,
                   MPA_PP + MPA_CMF + MPA_MOS,
                   @CrunchTime,
                   @AmcosVersionId
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'RE'
                  AND CourseType = 'B';
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
                CrunchTime,
                AmcosVersionId,
                LocationId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4041,
                   GradeType,
                   GradeLevel,
                   -1,
                   OMA_PP + OMA_CMF + OMA_MOS,
                   @CrunchTime,
                   @AmcosVersionId,
                   -1
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'AE'
                  AND CourseType = 'B';
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
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4042,
                   GradeType,
                   GradeLevel,
                   -1,
                   OMA_PP + OMA_CMF + OMA_MOS,
                   @CrunchTime,
                   @AmcosVersionId
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'NE'
                  AND CourseType = 'B';
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
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4043,
                   GradeType,
                   GradeLevel,
                   -1,
                   OMA_PP + OMA_CMF + OMA_MOS,
                   @CrunchTime,
                   @AmcosVersionId
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'RE'
                  AND CourseType = 'B';
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
                CrunchTime,
                AmcosVersionId,
                LocationId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4109,
                   GradeType,
                   GradeLevel,
                   -1,
                   other_PP + Other_CMF + Other_MOS,
                   @CrunchTime,
                   @AmcosVersionId,
                   -1
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'AE'
                  AND CourseType = 'B';
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
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4110,
                   GradeType,
                   GradeLevel,
                   -1,
                   other_PP + Other_CMF + Other_MOS,
                   @CrunchTime,
                   @AmcosVersionId
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'NE'
                  AND CourseType = 'B';
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
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4111,
                   GradeType,
                   GradeLevel,
                   -1,
                   other_PP + Other_CMF + Other_MOS,
                   @CrunchTime,
                   @AmcosVersionId
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'RE'
                  AND CourseType = 'B';

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
                CrunchTime,
                AmcosVersionId,
                LocationId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   3958,
                   GradeType,
                   GradeLevel,
                   -1,
                   MPA_PP + MPA_CMF + MPA_MOS,
                   @CrunchTime,
                   @AmcosVersionId,
                   -1
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'AE'
                  AND CourseType = 'C';
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
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   3971,
                   GradeType,
                   GradeLevel,
                   -1,
                   MPA_PP + MPA_CMF + MPA_MOS,
                   @CrunchTime,
                   @AmcosVersionId
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'NE'
                  AND CourseType = 'C';
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
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   3974,
                   GradeType,
                   GradeLevel,
                   -1,
                   MPA_PP + MPA_CMF + MPA_MOS,
                   @CrunchTime,
                   @AmcosVersionId
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'RE'
                  AND CourseType = 'C';
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
                CrunchTime,
                AmcosVersionId,
                LocationId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4044,
                   GradeType,
                   GradeLevel,
                   -1,
                   OMA_PP + OMA_CMF + OMA_MOS,
                   @CrunchTime,
                   @AmcosVersionId,
                   -1
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'AE'
                  AND CourseType = 'C';
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
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4047,
                   GradeType,
                   GradeLevel,
                   -1,
                   OMA_PP + OMA_CMF + OMA_MOS,
                   @CrunchTime,
                   @AmcosVersionId
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'NE'
                  AND CourseType = 'C';
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
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4050,
                   GradeType,
                   GradeLevel,
                   -1,
                   OMA_PP + OMA_CMF + OMA_MOS,
                   @CrunchTime,
                   @AmcosVersionId
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'RE'
                  AND CourseType = 'C';
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
                CrunchTime,
                AmcosVersionId,
                LocationId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4112,
                   GradeType,
                   GradeLevel,
                   -1,
                   other_PP + Other_CMF + Other_MOS,
                   @CrunchTime,
                   @AmcosVersionId,
                   -1
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'AE'
                  AND CourseType = 'C';
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
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4115,
                   GradeType,
                   GradeLevel,
                   -1,
                   other_PP + Other_CMF + Other_MOS,
                   @CrunchTime,
                   @AmcosVersionId
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'NE'
                  AND CourseType = 'C';
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
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4118,
                   GradeType,
                   GradeLevel,
                   -1,
                   other_PP + Other_CMF + Other_MOS,
                   @CrunchTime,
                   @AmcosVersionId
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'RE'
                  AND CourseType = 'C';

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
                CrunchTime,
                AmcosVersionId,
                LocationId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   3969,
                   GradeType,
                   GradeLevel,
                   -1,
                   MPA_PP + MPA_CMF + MPA_MOS,
                   @CrunchTime,
                   @AmcosVersionId,
                   -1
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'AO'
                  AND CourseType = 'C';
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
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   3972,
                   GradeType,
                   GradeLevel,
                   -1,
                   MPA_PP + MPA_CMF + MPA_MOS,
                   @CrunchTime,
                   @AmcosVersionId
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'NO'
                  AND CourseType = 'C';
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
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   3975,
                   GradeType,
                   GradeLevel,
                   -1,
                   MPA_PP + MPA_CMF + MPA_MOS,
                   @CrunchTime,
                   @AmcosVersionId
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'RO'
                  AND CourseType = 'C';
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
                CrunchTime,
                AmcosVersionId,
                LocationId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4045,
                   GradeType,
                   GradeLevel,
                   -1,
                   OMA_PP + OMA_CMF + OMA_MOS,
                   @CrunchTime,
                   @AmcosVersionId,
                   -1
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'AO'
                  AND CourseType = 'C';
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
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4048,
                   GradeType,
                   GradeLevel,
                   -1,
                   OMA_PP + OMA_CMF + OMA_MOS,
                   @CrunchTime,
                   @AmcosVersionId
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'NO'
                  AND CourseType = 'C';
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
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4051,
                   GradeType,
                   GradeLevel,
                   -1,
                   OMA_PP + OMA_CMF + OMA_MOS,
                   @CrunchTime,
                   @AmcosVersionId
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'RO'
                  AND CourseType = 'C';
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
                CrunchTime,
                AmcosVersionId,
                LocationId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4113,
                   GradeType,
                   GradeLevel,
                   -1,
                   other_PP + Other_CMF + Other_MOS,
                   @CrunchTime,
                   @AmcosVersionId,
                   -1
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'AO'
                  AND CourseType = 'C';
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
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4116,
                   GradeType,
                   GradeLevel,
                   -1,
                   other_PP + Other_CMF + Other_MOS,
                   @CrunchTime,
                   @AmcosVersionId
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'NO'
                  AND CourseType = 'C';
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
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4119,
                   GradeType,
                   GradeLevel,
                   -1,
                   other_PP + Other_CMF + Other_MOS,
                   @CrunchTime,
                   @AmcosVersionId
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'RO'
                  AND CourseType = 'C';

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
                CrunchTime,
                AmcosVersionId,
                LocationId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   3970,
                   GradeType,
                   GradeLevel,
                   -1,
                   MPA_PP + MPA_CMF + MPA_MOS,
                   @CrunchTime,
                   @AmcosVersionId,
                   -1
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'AWO'
                  AND CourseType = 'C';
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
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   3973,
                   GradeType,
                   GradeLevel,
                   -1,
                   MPA_PP + MPA_CMF + MPA_MOS,
                   @CrunchTime,
                   @AmcosVersionId
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'NWO'
                  AND CourseType = 'C';
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
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   3976,
                   GradeType,
                   GradeLevel,
                   -1,
                   MPA_PP + MPA_CMF + MPA_MOS,
                   @CrunchTime,
                   @AmcosVersionId
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'RWO'
                  AND CourseType = 'C';
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
                CrunchTime,
                AmcosVersionId,
                LocationId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4046,
                   GradeType,
                   GradeLevel,
                   -1,
                   OMA_PP + OMA_CMF + OMA_MOS,
                   @CrunchTime,
                   @AmcosVersionId,
                   -1
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'AWO'
                  AND CourseType = 'C';
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
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4049,
                   GradeType,
                   GradeLevel,
                   -1,
                   OMA_PP + OMA_CMF + OMA_MOS,
                   @CrunchTime,
                   @AmcosVersionId
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'NWO'
                  AND CourseType = 'C';
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
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4052,
                   GradeType,
                   GradeLevel,
                   -1,
                   OMA_PP + OMA_CMF + OMA_MOS,
                   @CrunchTime,
                   @AmcosVersionId
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'RWO'
                  AND CourseType = 'C';
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
                CrunchTime,
                AmcosVersionId,
                LocationId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4114,
                   GradeType,
                   GradeLevel,
                   -1,
                   other_PP + Other_CMF + Other_MOS,
                   @CrunchTime,
                   @AmcosVersionId,
                   -1
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'AWO'
                  AND CourseType = 'C';
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
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4117,
                   GradeType,
                   GradeLevel,
                   -1,
                   other_PP + Other_CMF + Other_MOS,
                   @CrunchTime,
                   @AmcosVersionId
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'NWO'
                  AND CourseType = 'C';
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
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4120,
                   GradeType,
                   GradeLevel,
                   -1,
                   other_PP + Other_CMF + Other_MOS,
                   @CrunchTime,
                   @AmcosVersionId
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'RWO'
                  AND CourseType = 'C';

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
                CrunchTime,
                AmcosVersionId,
                LocationId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   3977,
                   GradeType,
                   GradeLevel,
                   -1,
                   MPA_PP + MPA_CMF + MPA_MOS,
                   @CrunchTime,
                   @AmcosVersionId,
                   -1
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'AO'
                  AND CourseType = 'IET';
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
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   3979,
                   GradeType,
                   GradeLevel,
                   -1,
                   MPA_PP + MPA_CMF + MPA_MOS,
                   @CrunchTime,
                   @AmcosVersionId
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'NO'
                  AND CourseType = 'IET';
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
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   3981,
                   GradeType,
                   GradeLevel,
                   -1,
                   MPA_PP + MPA_CMF + MPA_MOS,
                   @CrunchTime,
                   @AmcosVersionId
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'RO'
                  AND CourseType = 'IET';
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
                CrunchTime,
                AmcosVersionId,
                LocationId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4053,
                   GradeType,
                   GradeLevel,
                   -1,
                   OMA_PP + OMA_CMF + OMA_MOS,
                   @CrunchTime,
                   @AmcosVersionId,
                   -1
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'AO'
                  AND CourseType = 'IET';
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
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4057,
                   GradeType,
                   GradeLevel,
                   -1,
                   OMA_PP + OMA_CMF + OMA_MOS,
                   @CrunchTime,
                   @AmcosVersionId
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'NO'
                  AND CourseType = 'IET';
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
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4055,
                   GradeType,
                   GradeLevel,
                   -1,
                   OMA_PP + OMA_CMF + OMA_MOS,
                   @CrunchTime,
                   @AmcosVersionId
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'RO'
                  AND CourseType = 'IET';
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
                CrunchTime,
                AmcosVersionId,
                LocationId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4121,
                   GradeType,
                   GradeLevel,
                   -1,
                   other_PP + Other_CMF + Other_MOS,
                   @CrunchTime,
                   @AmcosVersionId,
                   -1
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'AO'
                  AND CourseType = 'IET';
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
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4125,
                   GradeType,
                   GradeLevel,
                   -1,
                   other_PP + Other_CMF + Other_MOS,
                   @CrunchTime,
                   @AmcosVersionId
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'NO'
                  AND CourseType = 'IET';
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
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4123,
                   GradeType,
                   GradeLevel,
                   -1,
                   other_PP + Other_CMF + Other_MOS,
                   @CrunchTime,
                   @AmcosVersionId
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'RO'
                  AND CourseType = 'IET';

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
                CrunchTime,
                AmcosVersionId,
                LocationId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   3978,
                   GradeType,
                   GradeLevel,
                   -1,
                   MPA_PP + MPA_CMF + MPA_MOS,
                   @CrunchTime,
                   @AmcosVersionId,
                   -1
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'AWO'
                  AND CourseType = 'IET';
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
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   3980,
                   GradeType,
                   GradeLevel,
                   -1,
                   MPA_PP + MPA_CMF + MPA_MOS,
                   @CrunchTime,
                   @AmcosVersionId
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'NWO'
                  AND CourseType = 'IET';
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
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   3982,
                   GradeType,
                   GradeLevel,
                   -1,
                   MPA_PP + MPA_CMF + MPA_MOS,
                   @CrunchTime,
                   @AmcosVersionId
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'RWO'
                  AND CourseType = 'IET';
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
                CrunchTime,
                AmcosVersionId,
                LocationId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4054,
                   GradeType,
                   GradeLevel,
                   -1,
                   OMA_PP + OMA_CMF + OMA_MOS,
                   @CrunchTime,
                   @AmcosVersionId,
                   -1
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'AWO'
                  AND CourseType = 'IET';
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
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4058,
                   GradeType,
                   GradeLevel,
                   -1,
                   OMA_PP + OMA_CMF + OMA_MOS,
                   @CrunchTime,
                   @AmcosVersionId
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'NWO'
                  AND CourseType = 'IET';
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
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4056,
                   GradeType,
                   GradeLevel,
                   -1,
                   OMA_PP + OMA_CMF + OMA_MOS,
                   @CrunchTime,
                   @AmcosVersionId
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'RWO'
                  AND CourseType = 'IET';
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
                CrunchTime,
                AmcosVersionId,
                LocationId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4122,
                   GradeType,
                   GradeLevel,
                   -1,
                   other_PP + Other_CMF + Other_MOS,
                   @CrunchTime,
                   @AmcosVersionId,
                   -1
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'AWO'
                  AND CourseType = 'IET';
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
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4126,
                   GradeType,
                   GradeLevel,
                   -1,
                   other_PP + Other_CMF + Other_MOS,
                   @CrunchTime,
                   @AmcosVersionId
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'NWO'
                  AND CourseType = 'IET';
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
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4124,
                   GradeType,
                   GradeLevel,
                   -1,
                   other_PP + Other_CMF + Other_MOS,
                   @CrunchTime,
                   @AmcosVersionId
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'RWO'
                  AND CourseType = 'IET';

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
                CrunchTime,
                AmcosVersionId,
                LocationId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   3959,
                   GradeType,
                   GradeLevel,
                   -1,
                   MPA_PP + MPA_CMF + MPA_MOS,
                   @CrunchTime,
                   @AmcosVersionId,
                   -1
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'AE'
                  AND CourseType = 'AIT';
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
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   3984,
                   GradeType,
                   GradeLevel,
                   -1,
                   MPA_PP + MPA_CMF + MPA_MOS,
                   @CrunchTime,
                   @AmcosVersionId
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'NE'
                  AND CourseType = 'AIT';
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
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   3985,
                   GradeType,
                   GradeLevel,
                   -1,
                   MPA_PP + MPA_CMF + MPA_MOS,
                   @CrunchTime,
                   @AmcosVersionId
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'RE'
                  AND CourseType = 'AIT';
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
                CrunchTime,
                AmcosVersionId,
                LocationId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4059,
                   GradeType,
                   GradeLevel,
                   -1,
                   OMA_PP + OMA_CMF + OMA_MOS,
                   @CrunchTime,
                   @AmcosVersionId,
                   -1
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'AE'
                  AND CourseType = 'AIT';
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
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4060,
                   GradeType,
                   GradeLevel,
                   -1,
                   OMA_PP + OMA_CMF + OMA_MOS,
                   @CrunchTime,
                   @AmcosVersionId
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'NE'
                  AND CourseType = 'AIT';
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
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4061,
                   GradeType,
                   GradeLevel,
                   -1,
                   OMA_PP + OMA_CMF + OMA_MOS,
                   @CrunchTime,
                   @AmcosVersionId
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'RE'
                  AND CourseType = 'AIT';
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
                CrunchTime,
                AmcosVersionId,
                LocationId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4127,
                   GradeType,
                   GradeLevel,
                   -1,
                   other_PP + Other_CMF + Other_MOS,
                   @CrunchTime,
                   @AmcosVersionId,
                   -1
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'AE'
                  AND CourseType = 'AIT';
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
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4128,
                   GradeType,
                   GradeLevel,
                   -1,
                   other_PP + Other_CMF + Other_MOS,
                   @CrunchTime,
                   @AmcosVersionId
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'NE'
                  AND CourseType = 'AIT';
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
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4129,
                   GradeType,
                   GradeLevel,
                   -1,
                   other_PP + Other_CMF + Other_MOS,
                   @CrunchTime,
                   @AmcosVersionId
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'RE'
                  AND CourseType = 'AIT';

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
                CrunchTime,
                AmcosVersionId,
                LocationId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   3986,
                   GradeType,
                   GradeLevel,
                   -1,
                   MPA_PP + MPA_CMF + MPA_MOS,
                   @CrunchTime,
                   @AmcosVersionId,
                   -1
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'AO'
                  AND CourseType = 'F';
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
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   3990,
                   GradeType,
                   GradeLevel,
                   -1,
                   MPA_PP + MPA_CMF + MPA_MOS,
                   @CrunchTime,
                   @AmcosVersionId
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'NO'
                  AND CourseType = 'F';
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
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   3988,
                   GradeType,
                   GradeLevel,
                   -1,
                   MPA_PP + MPA_CMF + MPA_MOS,
                   @CrunchTime,
                   @AmcosVersionId
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'RO'
                  AND CourseType = 'F';
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
                CrunchTime,
                AmcosVersionId,
                LocationId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4062,
                   GradeType,
                   GradeLevel,
                   -1,
                   OMA_PP + OMA_CMF + OMA_MOS,
                   @CrunchTime,
                   @AmcosVersionId,
                   -1
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'AO'
                  AND CourseType = 'F';
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
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4066,
                   GradeType,
                   GradeLevel,
                   -1,
                   OMA_PP + OMA_CMF + OMA_MOS,
                   @CrunchTime,
                   @AmcosVersionId
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'NO'
                  AND CourseType = 'F';
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
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4064,
                   GradeType,
                   GradeLevel,
                   -1,
                   OMA_PP + OMA_CMF + OMA_MOS,
                   @CrunchTime,
                   @AmcosVersionId
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'RO'
                  AND CourseType = 'F';
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
                CrunchTime,
                AmcosVersionId,
                LocationId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4130,
                   GradeType,
                   GradeLevel,
                   -1,
                   other_PP + Other_CMF + Other_MOS,
                   @CrunchTime,
                   @AmcosVersionId,
                   -1
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'AO'
                  AND CourseType = 'F';
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
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4134,
                   GradeType,
                   GradeLevel,
                   -1,
                   other_PP + Other_CMF + Other_MOS,
                   @CrunchTime,
                   @AmcosVersionId
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'NO'
                  AND CourseType = 'F';
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
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4132,
                   GradeType,
                   GradeLevel,
                   -1,
                   other_PP + Other_CMF + Other_MOS,
                   @CrunchTime,
                   @AmcosVersionId
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'RO'
                  AND CourseType = 'F';

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
                CrunchTime,
                AmcosVersionId,
                LocationId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   3987,
                   GradeType,
                   GradeLevel,
                   -1,
                   MPA_PP + MPA_CMF + MPA_MOS,
                   @CrunchTime,
                   @AmcosVersionId,
                   -1
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'AWO'
                  AND CourseType = 'F';
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
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   3991,
                   GradeType,
                   GradeLevel,
                   -1,
                   MPA_PP + MPA_CMF + MPA_MOS,
                   @CrunchTime,
                   @AmcosVersionId
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'NWO'
                  AND CourseType = 'F';
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
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   3989,
                   GradeType,
                   GradeLevel,
                   -1,
                   MPA_PP + MPA_CMF + MPA_MOS,
                   @CrunchTime,
                   @AmcosVersionId
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'RWO'
                  AND CourseType = 'F';
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
                CrunchTime,
                AmcosVersionId,
                LocationId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4063,
                   GradeType,
                   GradeLevel,
                   -1,
                   OMA_PP + OMA_CMF + OMA_MOS,
                   @CrunchTime,
                   @AmcosVersionId,
                   -1
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'AWO'
                  AND CourseType = 'F';
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
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4067,
                   GradeType,
                   GradeLevel,
                   -1,
                   OMA_PP + OMA_CMF + OMA_MOS,
                   @CrunchTime,
                   @AmcosVersionId
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'NWO'
                  AND CourseType = 'F';
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
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4065,
                   GradeType,
                   GradeLevel,
                   -1,
                   OMA_PP + OMA_CMF + OMA_MOS,
                   @CrunchTime,
                   @AmcosVersionId
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'RWO'
                  AND CourseType = 'F';
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
                CrunchTime,
                AmcosVersionId,
                LocationId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4131,
                   GradeType,
                   GradeLevel,
                   -1,
                   other_PP + Other_CMF + Other_MOS,
                   @CrunchTime,
                   @AmcosVersionId,
                   -1
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'AWO'
                  AND CourseType = 'F';
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
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4135,
                   GradeType,
                   GradeLevel,
                   -1,
                   other_PP + Other_CMF + Other_MOS,
                   @CrunchTime,
                   @AmcosVersionId
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'NWO'
                  AND CourseType = 'F';
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
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4133,
                   GradeType,
                   GradeLevel,
                   -1,
                   other_PP + Other_CMF + Other_MOS,
                   @CrunchTime,
                   @AmcosVersionId
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'RWO'
                  AND CourseType = 'F';

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
                CrunchTime,
                AmcosVersionId,
                LocationId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   3960,
                   GradeType,
                   GradeLevel,
                   -1,
                   MPA_PP + MPA_CMF + MPA_MOS,
                   @CrunchTime,
                   @AmcosVersionId,
                   -1
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'AE'
                  AND CourseType = 'OSUT';
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
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   3993,
                   GradeType,
                   GradeLevel,
                   -1,
                   MPA_PP + MPA_CMF + MPA_MOS,
                   @CrunchTime,
                   @AmcosVersionId
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'NE'
                  AND CourseType = 'OSUT';
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
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   3992,
                   GradeType,
                   GradeLevel,
                   -1,
                   MPA_PP + MPA_CMF + MPA_MOS,
                   @CrunchTime,
                   @AmcosVersionId
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'RE'
                  AND CourseType = 'OSUT';
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
                CrunchTime,
                AmcosVersionId,
                LocationId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4068,
                   GradeType,
                   GradeLevel,
                   -1,
                   OMA_PP + OMA_CMF + OMA_MOS,
                   @CrunchTime,
                   @AmcosVersionId,
                   -1
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'AE'
                  AND CourseType = 'OSUT';
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
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4070,
                   GradeType,
                   GradeLevel,
                   -1,
                   OMA_PP + OMA_CMF + OMA_MOS,
                   @CrunchTime,
                   @AmcosVersionId
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'NE'
                  AND CourseType = 'OSUT';
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
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4069,
                   GradeType,
                   GradeLevel,
                   -1,
                   OMA_PP + OMA_CMF + OMA_MOS,
                   @CrunchTime,
                   @AmcosVersionId
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'RE'
                  AND CourseType = 'OSUT';
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
                CrunchTime,
                AmcosVersionId,
                LocationId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4136,
                   GradeType,
                   GradeLevel,
                   -1,
                   other_PP + Other_CMF + Other_MOS,
                   @CrunchTime,
                   @AmcosVersionId,
                   -1
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'AE'
                  AND CourseType = 'OSUT';
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
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4138,
                   GradeType,
                   GradeLevel,
                   -1,
                   other_PP + Other_CMF + Other_MOS,
                   @CrunchTime,
                   @AmcosVersionId
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'NE'
                  AND CourseType = 'OSUT';
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
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4137,
                   GradeType,
                   GradeLevel,
                   -1,
                   other_PP + Other_CMF + Other_MOS,
                   @CrunchTime,
                   @AmcosVersionId
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'RE'
                  AND CourseType = 'OSUT';

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
                CrunchTime,
                AmcosVersionId,
                LocationId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   3994,
                   GradeType,
                   GradeLevel,
                   -1,
                   MPA_PP + MPA_CMF + MPA_MOS,
                   @CrunchTime,
                   @AmcosVersionId,
                   -1
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'AO'
                  AND CourseType = 'O';
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
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   3996,
                   GradeType,
                   GradeLevel,
                   -1,
                   MPA_PP + MPA_CMF + MPA_MOS,
                   @CrunchTime,
                   @AmcosVersionId
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'NO'
                  AND CourseType = 'O';
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
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   3998,
                   GradeType,
                   GradeLevel,
                   -1,
                   MPA_PP + MPA_CMF + MPA_MOS,
                   @CrunchTime,
                   @AmcosVersionId
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'RO'
                  AND CourseType = 'O';
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
                CrunchTime,
                AmcosVersionId,
                LocationId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4071,
                   GradeType,
                   GradeLevel,
                   -1,
                   OMA_PP + OMA_CMF + OMA_MOS,
                   @CrunchTime,
                   @AmcosVersionId,
                   -1
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'AO'
                  AND CourseType = 'O';
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
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4075,
                   GradeType,
                   GradeLevel,
                   -1,
                   OMA_PP + OMA_CMF + OMA_MOS,
                   @CrunchTime,
                   @AmcosVersionId
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'NO'
                  AND CourseType = 'O';
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
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4073,
                   GradeType,
                   GradeLevel,
                   -1,
                   OMA_PP + OMA_CMF + OMA_MOS,
                   @CrunchTime,
                   @AmcosVersionId
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'RO'
                  AND CourseType = 'O';
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
                CrunchTime,
                AmcosVersionId,
                LocationId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4139,
                   GradeType,
                   GradeLevel,
                   -1,
                   other_PP + Other_CMF + Other_MOS,
                   @CrunchTime,
                   @AmcosVersionId,
                   -1
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'AO'
                  AND CourseType = 'O';
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
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4143,
                   GradeType,
                   GradeLevel,
                   -1,
                   other_PP + Other_CMF + Other_MOS,
                   @CrunchTime,
                   @AmcosVersionId
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'NO'
                  AND CourseType = 'O';
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
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4141,
                   GradeType,
                   GradeLevel,
                   -1,
                   other_PP + Other_CMF + Other_MOS,
                   @CrunchTime,
                   @AmcosVersionId
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'RO'
                  AND CourseType = 'O';

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
                CrunchTime,
                AmcosVersionId,
                LocationId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   3995,
                   GradeType,
                   GradeLevel,
                   -1,
                   MPA_PP + MPA_CMF + MPA_MOS,
                   @CrunchTime,
                   @AmcosVersionId,
                   -1
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'AWO'
                  AND CourseType = 'O';
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
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   3997,
                   GradeType,
                   GradeLevel,
                   -1,
                   MPA_PP + MPA_CMF + MPA_MOS,
                   @CrunchTime,
                   @AmcosVersionId
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'NWO'
                  AND CourseType = 'O';
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
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   3999,
                   GradeType,
                   GradeLevel,
                   -1,
                   MPA_PP + MPA_CMF + MPA_MOS,
                   @CrunchTime,
                   @AmcosVersionId
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'RWO'
                  AND CourseType = 'O';
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
                CrunchTime,
                AmcosVersionId,
                LocationId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4072,
                   GradeType,
                   GradeLevel,
                   -1,
                   OMA_PP + OMA_CMF + OMA_MOS,
                   @CrunchTime,
                   @AmcosVersionId,
                   -1
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'AWO'
                  AND CourseType = 'O';
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
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4076,
                   GradeType,
                   GradeLevel,
                   -1,
                   OMA_PP + OMA_CMF + OMA_MOS,
                   @CrunchTime,
                   @AmcosVersionId
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'NWO'
                  AND CourseType = 'O';
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
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4074,
                   GradeType,
                   GradeLevel,
                   -1,
                   OMA_PP + OMA_CMF + OMA_MOS,
                   @CrunchTime,
                   @AmcosVersionId
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'RWO'
                  AND CourseType = 'O';
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
                CrunchTime,
                AmcosVersionId,
                LocationId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4140,
                   GradeType,
                   GradeLevel,
                   -1,
                   other_PP + Other_CMF + Other_MOS,
                   @CrunchTime,
                   @AmcosVersionId,
                   -1
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'AWO'
                  AND CourseType = 'O';
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
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4144,
                   GradeType,
                   GradeLevel,
                   -1,
                   other_PP + Other_CMF + Other_MOS,
                   @CrunchTime,
                   @AmcosVersionId
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'NWO'
                  AND CourseType = 'O';
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
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4142,
                   GradeType,
                   GradeLevel,
                   -1,
                   other_PP + Other_CMF + Other_MOS,
                   @CrunchTime,
                   @AmcosVersionId
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'RWO'
                  AND CourseType = 'O';

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
                CrunchTime,
                AmcosVersionId,
                LocationId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   3961,
                   GradeType,
                   GradeLevel,
                   -1,
                   MPA_PP + MPA_CMF + MPA_MOS,
                   @CrunchTime,
                   @AmcosVersionId,
                   -1
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'AE'
                  AND CourseType = 'P';
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
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4004,
                   GradeType,
                   GradeLevel,
                   -1,
                   MPA_PP + MPA_CMF + MPA_MOS,
                   @CrunchTime,
                   @AmcosVersionId
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'NE'
                  AND CourseType = 'P';
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
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4005,
                   GradeType,
                   GradeLevel,
                   -1,
                   MPA_PP + MPA_CMF + MPA_MOS,
                   @CrunchTime,
                   @AmcosVersionId
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'RE'
                  AND CourseType = 'P';
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
                CrunchTime,
                AmcosVersionId,
                LocationId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4085,
                   GradeType,
                   GradeLevel,
                   -1,
                   OMA_PP + OMA_CMF + OMA_MOS,
                   @CrunchTime,
                   @AmcosVersionId,
                   -1
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'AE'
                  AND CourseType = 'P';
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
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4081,
                   GradeType,
                   GradeLevel,
                   -1,
                   OMA_PP + OMA_CMF + OMA_MOS,
                   @CrunchTime,
                   @AmcosVersionId
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'NE'
                  AND CourseType = 'P';
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
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4082,
                   GradeType,
                   GradeLevel,
                   -1,
                   OMA_PP + OMA_CMF + OMA_MOS,
                   @CrunchTime,
                   @AmcosVersionId
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'RE'
                  AND CourseType = 'P';
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
                CrunchTime,
                AmcosVersionId,
                LocationId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4202,
                   GradeType,
                   GradeLevel,
                   -1,
                   other_PP + Other_CMF + Other_MOS,
                   @CrunchTime,
                   @AmcosVersionId,
                   -1
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'AE'
                  AND CourseType = 'P';
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
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4149,
                   GradeType,
                   GradeLevel,
                   -1,
                   other_PP + Other_CMF + Other_MOS,
                   @CrunchTime,
                   @AmcosVersionId
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'NE'
                  AND CourseType = 'P';
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
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4150,
                   GradeType,
                   GradeLevel,
                   -1,
                   other_PP + Other_CMF + Other_MOS,
                   @CrunchTime,
                   @AmcosVersionId
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'RE'
                  AND CourseType = 'P';

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
                CrunchTime,
                AmcosVersionId,
                LocationId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4006,
                   GradeType,
                   GradeLevel,
                   -1,
                   MPA_PP + MPA_CMF + MPA_MOS,
                   @CrunchTime,
                   @AmcosVersionId,
                   -1
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'AO'
                  AND CourseType = 'P';
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
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4000,
                   GradeType,
                   GradeLevel,
                   -1,
                   MPA_PP + MPA_CMF + MPA_MOS,
                   @CrunchTime,
                   @AmcosVersionId
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'NO'
                  AND CourseType = 'P';
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
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4002,
                   GradeType,
                   GradeLevel,
                   -1,
                   MPA_PP + MPA_CMF + MPA_MOS,
                   @CrunchTime,
                   @AmcosVersionId
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'RO'
                  AND CourseType = 'P';
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
                CrunchTime,
                AmcosVersionId,
                LocationId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4083,
                   GradeType,
                   GradeLevel,
                   -1,
                   OMA_PP + OMA_CMF + OMA_MOS,
                   @CrunchTime,
                   @AmcosVersionId,
                   -1
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'AO'
                  AND CourseType = 'P';
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
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4077,
                   GradeType,
                   GradeLevel,
                   -1,
                   OMA_PP + OMA_CMF + OMA_MOS,
                   @CrunchTime,
                   @AmcosVersionId
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'NO'
                  AND CourseType = 'P';
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
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4079,
                   GradeType,
                   GradeLevel,
                   -1,
                   OMA_PP + OMA_CMF + OMA_MOS,
                   @CrunchTime,
                   @AmcosVersionId
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'RO'
                  AND CourseType = 'P';
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
                CrunchTime,
                AmcosVersionId,
                LocationId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4151,
                   GradeType,
                   GradeLevel,
                   -1,
                   other_PP + Other_CMF + Other_MOS,
                   @CrunchTime,
                   @AmcosVersionId,
                   -1
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'AO'
                  AND CourseType = 'P';
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
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4145,
                   GradeType,
                   GradeLevel,
                   -1,
                   other_PP + Other_CMF + Other_MOS,
                   @CrunchTime,
                   @AmcosVersionId
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'NO'
                  AND CourseType = 'P';
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
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4147,
                   GradeType,
                   GradeLevel,
                   -1,
                   other_PP + Other_CMF + Other_MOS,
                   @CrunchTime,
                   @AmcosVersionId
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'RO'
                  AND CourseType = 'P';

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
                CrunchTime,
                AmcosVersionId,
                LocationId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4007,
                   GradeType,
                   GradeLevel,
                   -1,
                   MPA_PP + MPA_CMF + MPA_MOS,
                   @CrunchTime,
                   @AmcosVersionId,
                   -1
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'AWO'
                  AND CourseType = 'P';
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
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4001,
                   GradeType,
                   GradeLevel,
                   -1,
                   MPA_PP + MPA_CMF + MPA_MOS,
                   @CrunchTime,
                   @AmcosVersionId
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'NWO'
                  AND CourseType = 'P';
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
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4003,
                   GradeType,
                   GradeLevel,
                   -1,
                   MPA_PP + MPA_CMF + MPA_MOS,
                   @CrunchTime,
                   @AmcosVersionId
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'RWO'
                  AND CourseType = 'P';
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
                CrunchTime,
                AmcosVersionId,
                LocationId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4084,
                   GradeType,
                   GradeLevel,
                   -1,
                   OMA_PP + OMA_CMF + OMA_MOS,
                   @CrunchTime,
                   @AmcosVersionId,
                   -1
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'AWO'
                  AND CourseType = 'P';
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
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4078,
                   GradeType,
                   GradeLevel,
                   -1,
                   OMA_PP + OMA_CMF + OMA_MOS,
                   @CrunchTime,
                   @AmcosVersionId
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'NWO'
                  AND CourseType = 'P';
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
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4080,
                   GradeType,
                   GradeLevel,
                   -1,
                   OMA_PP + OMA_CMF + OMA_MOS,
                   @CrunchTime,
                   @AmcosVersionId
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'RWO'
                  AND CourseType = 'P';
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
                CrunchTime,
                AmcosVersionId,
                LocationId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4152,
                   GradeType,
                   GradeLevel,
                   -1,
                   other_PP + Other_CMF + Other_MOS,
                   @CrunchTime,
                   @AmcosVersionId,
                   -1
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'AWO'
                  AND CourseType = 'P';
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
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4146,
                   GradeType,
                   GradeLevel,
                   -1,
                   other_PP + Other_CMF + Other_MOS,
                   @CrunchTime,
                   @AmcosVersionId
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'NWO'
                  AND CourseType = 'P';
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
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4148,
                   GradeType,
                   GradeLevel,
                   -1,
                   other_PP + Other_CMF + Other_MOS,
                   @CrunchTime,
                   @AmcosVersionId
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'RWO'
                  AND CourseType = 'P';

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
                CrunchTime,
                AmcosVersionId,
                LocationId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   3962,
                   GradeType,
                   GradeLevel,
                   WeaponSystemId,
                   MPA_PP + MPA_CMF + MPA_MOS,
                   @CrunchTime,
                   @AmcosVersionId,
                   -1
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'AE'
                  AND CourseType = 'W';
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
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4010,
                   GradeType,
                   GradeLevel,
                   WeaponSystemId,
                   MPA_PP + MPA_CMF + MPA_MOS,
                   @CrunchTime,
                   @AmcosVersionId
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'NE'
                  AND CourseType = 'W';
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
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4013,
                   GradeType,
                   GradeLevel,
                   WeaponSystemId,
                   MPA_PP + MPA_CMF + MPA_MOS,
                   @CrunchTime,
                   @AmcosVersionId
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'RE'
                  AND CourseType = 'W';

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
                CrunchTime,
                AmcosVersionId,
                LocationId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4086,
                   GradeType,
                   GradeLevel,
                   WeaponSystemId,
                   OMA_PP + OMA_CMF + OMA_MOS,
                   @CrunchTime,
                   @AmcosVersionId,
                   -1
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'AE'
                  AND CourseType = 'W';
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
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4092,
                   GradeType,
                   GradeLevel,
                   WeaponSystemId,
                   OMA_PP + OMA_CMF + OMA_MOS,
                   @CrunchTime,
                   @AmcosVersionId
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'NE'
                  AND CourseType = 'W';
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
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4089,
                   GradeType,
                   GradeLevel,
                   WeaponSystemId,
                   OMA_PP + OMA_CMF + OMA_MOS,
                   @CrunchTime,
                   @AmcosVersionId
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'RE'
                  AND CourseType = 'W';
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
                CrunchTime,
                AmcosVersionId,
                LocationId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4203,
                   GradeType,
                   GradeLevel,
                   WeaponSystemId,
                   other_PP + Other_CMF + Other_MOS,
                   @CrunchTime,
                   @AmcosVersionId,
                   -1
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'AE'
                  AND CourseType = 'W';
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
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4158,
                   GradeType,
                   GradeLevel,
                   WeaponSystemId,
                   other_PP + Other_CMF + Other_MOS,
                   @CrunchTime,
                   @AmcosVersionId
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'NE'
                  AND CourseType = 'W';
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
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4155,
                   GradeType,
                   GradeLevel,
                   WeaponSystemId,
                   other_PP + Other_CMF + Other_MOS,
                   @CrunchTime,
                   @AmcosVersionId
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'RE'
                  AND CourseType = 'W';

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
                CrunchTime,
                AmcosVersionId,
                LocationId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4008,
                   GradeType,
                   GradeLevel,
                   WeaponSystemId,
                   MPA_PP + MPA_CMF + MPA_MOS,
                   @CrunchTime,
                   @AmcosVersionId,
                   -1
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'AO'
                  AND CourseType = 'W';
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
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4011,
                   GradeType,
                   GradeLevel,
                   WeaponSystemId,
                   MPA_PP + MPA_CMF + MPA_MOS,
                   @CrunchTime,
                   @AmcosVersionId
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'NO'
                  AND CourseType = 'W';
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
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4014,
                   GradeType,
                   GradeLevel,
                   WeaponSystemId,
                   MPA_PP + MPA_CMF + MPA_MOS,
                   @CrunchTime,
                   @AmcosVersionId
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'RO'
                  AND CourseType = 'W';
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
                CrunchTime,
                AmcosVersionId,
                LocationId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4087,
                   GradeType,
                   GradeLevel,
                   WeaponSystemId,
                   OMA_PP + OMA_CMF + OMA_MOS,
                   @CrunchTime,
                   @AmcosVersionId,
                   -1
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'AO'
                  AND CourseType = 'W';
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
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4093,
                   GradeType,
                   GradeLevel,
                   WeaponSystemId,
                   OMA_PP + OMA_CMF + OMA_MOS,
                   @CrunchTime,
                   @AmcosVersionId
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'NO'
                  AND CourseType = 'W';
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
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4090,
                   GradeType,
                   GradeLevel,
                   WeaponSystemId,
                   OMA_PP + OMA_CMF + OMA_MOS,
                   @CrunchTime,
                   @AmcosVersionId
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'RO'
                  AND CourseType = 'W';
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
                CrunchTime,
                AmcosVersionId,
                LocationId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4153,
                   GradeType,
                   GradeLevel,
                   WeaponSystemId,
                   other_PP + Other_CMF + Other_MOS,
                   @CrunchTime,
                   @AmcosVersionId,
                   -1
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'AO'
                  AND CourseType = 'W';
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
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4159,
                   GradeType,
                   GradeLevel,
                   WeaponSystemId,
                   other_PP + Other_CMF + Other_MOS,
                   @CrunchTime,
                   @AmcosVersionId
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'NO'
                  AND CourseType = 'W';
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
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4156,
                   GradeType,
                   GradeLevel,
                   WeaponSystemId,
                   other_PP + Other_CMF + Other_MOS,
                   @CrunchTime,
                   @AmcosVersionId
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'RO'
                  AND CourseType = 'W';

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
                CrunchTime,
                AmcosVersionId,
                LocationId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4009,
                   GradeType,
                   GradeLevel,
                   WeaponSystemId,
                   MPA_PP + MPA_CMF + MPA_MOS,
                   @CrunchTime,
                   @AmcosVersionId,
                   -1
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'AWO'
                  AND CourseType = 'W';
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
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4012,
                   GradeType,
                   GradeLevel,
                   WeaponSystemId,
                   MPA_PP + MPA_CMF + MPA_MOS,
                   @CrunchTime,
                   @AmcosVersionId
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'NWO'
                  AND CourseType = 'W';
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
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4015,
                   GradeType,
                   GradeLevel,
                   WeaponSystemId,
                   MPA_PP + MPA_CMF + MPA_MOS,
                   @CrunchTime,
                   @AmcosVersionId
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'RWO'
                  AND CourseType = 'W';
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
                CrunchTime,
                AmcosVersionId,
                LocationId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4088,
                   GradeType,
                   GradeLevel,
                   WeaponSystemId,
                   OMA_PP + OMA_CMF + OMA_MOS,
                   @CrunchTime,
                   @AmcosVersionId,
                   -1
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'AWO'
                  AND CourseType = 'W';
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
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4094,
                   GradeType,
                   GradeLevel,
                   WeaponSystemId,
                   OMA_PP + OMA_CMF + OMA_MOS,
                   @CrunchTime,
                   @AmcosVersionId
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'NWO'
                  AND CourseType = 'W';
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
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4091,
                   GradeType,
                   GradeLevel,
                   WeaponSystemId,
                   OMA_PP + OMA_CMF + OMA_MOS,
                   @CrunchTime,
                   @AmcosVersionId
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'RWO'
                  AND CourseType = 'W';
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
                CrunchTime,
                AmcosVersionId,
                LocationId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4154,
                   GradeType,
                   GradeLevel,
                   WeaponSystemId,
                   other_PP + Other_CMF + Other_MOS,
                   @CrunchTime,
                   @AmcosVersionId,
                   -1
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'AWO'
                  AND CourseType = 'W';
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
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4160,
                   GradeType,
                   GradeLevel,
                   WeaponSystemId,
                   other_PP + Other_CMF + Other_MOS,
                   @CrunchTime,
                   @AmcosVersionId
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'NWO'
                  AND CourseType = 'W';
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
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4157,
                   GradeType,
                   GradeLevel,
                   WeaponSystemId,
                   other_PP + Other_CMF + Other_MOS,
                   @CrunchTime,
                   @AmcosVersionId
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'RWO'
                  AND CourseType = 'W';

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
                CrunchTime,
                AmcosVersionId,
                LocationId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   56,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_MPA,
                   @CrunchTime,
                   @AmcosVersionId,
                   -1
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'AE'
                  AND CourseType = 'B';
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
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4034,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_MPA,
                   @CrunchTime,
                   @AmcosVersionId
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'NE'
                  AND CourseType = 'B';
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
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4035,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_MPA,
                   @CrunchTime,
                   @AmcosVersionId
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'RE'
                  AND CourseType = 'B';
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
                CrunchTime,
                AmcosVersionId,
                LocationId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   91,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_OMA,
                   @CrunchTime,
                   @AmcosVersionId,
                   -1
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'AE'
                  AND CourseType = 'B';
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
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4105,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_OMA,
                   @CrunchTime,
                   @AmcosVersionId
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'NE'
                  AND CourseType = 'B';
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
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4106,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_OMA,
                   @CrunchTime,
                   @AmcosVersionId
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'RE'
                  AND CourseType = 'B';
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
                CrunchTime,
                AmcosVersionId,
                LocationId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   110,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_Other,
                   @CrunchTime,
                   @AmcosVersionId,
                   -1
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'AE'
                  AND CourseType = 'B';
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
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4173,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_Other,
                   @CrunchTime,
                   @AmcosVersionId
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'NE'
                  AND CourseType = 'B';
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
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4174,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_Other,
                   @CrunchTime,
                   @AmcosVersionId
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'RE'
                  AND CourseType = 'B';

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
                CrunchTime,
                AmcosVersionId,
                LocationId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   58,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_MPA,
                   @CrunchTime,
                   @AmcosVersionId,
                   -1
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'AE'
                  AND CourseType = 'C';
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
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   347,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_MPA,
                   @CrunchTime,
                   @AmcosVersionId
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'NE'
                  AND CourseType = 'C';
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
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   511,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_MPA,
                   @CrunchTime,
                   @AmcosVersionId
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'RE'
                  AND CourseType = 'C';
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
                CrunchTime,
                AmcosVersionId,
                LocationId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   93,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_OMA,
                   @CrunchTime,
                   @AmcosVersionId,
                   -1
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'AE'
                  AND CourseType = 'C';
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
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   309,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_OMA,
                   @CrunchTime,
                   @AmcosVersionId
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'NE'
                  AND CourseType = 'C';
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
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   473,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_OMA,
                   @CrunchTime,
                   @AmcosVersionId
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'RE'
                  AND CourseType = 'C';
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
                CrunchTime,
                AmcosVersionId,
                LocationId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   112,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_Other,
                   @CrunchTime,
                   @AmcosVersionId,
                   -1
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'AE'
                  AND CourseType = 'C';
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
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   318,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_Other,
                   @CrunchTime,
                   @AmcosVersionId
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'NE'
                  AND CourseType = 'C';
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
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   482,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_Other,
                   @CrunchTime,
                   @AmcosVersionId
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'RE'
                  AND CourseType = 'C';

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
                CrunchTime,
                AmcosVersionId,
                LocationId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   163,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_MPA,
                   @CrunchTime,
                   @AmcosVersionId,
                   -1
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'AO'
                  AND CourseType = 'C';
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
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   400,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_MPA,
                   @CrunchTime,
                   @AmcosVersionId
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'NO'
                  AND CourseType = 'C';
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
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   564,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_MPA,
                   @CrunchTime,
                   @AmcosVersionId
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'RO'
                  AND CourseType = 'C';
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
                CrunchTime,
                AmcosVersionId,
                LocationId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   184,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_OMA,
                   @CrunchTime,
                   @AmcosVersionId,
                   -1
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'AO'
                  AND CourseType = 'C';
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
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   369,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_OMA,
                   @CrunchTime,
                   @AmcosVersionId
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'NO'
                  AND CourseType = 'C';
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
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   533,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_OMA,
                   @CrunchTime,
                   @AmcosVersionId
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'RO'
                  AND CourseType = 'C';
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
                CrunchTime,
                AmcosVersionId,
                LocationId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   194,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_Other,
                   @CrunchTime,
                   @AmcosVersionId,
                   -1
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'AO'
                  AND CourseType = 'C';
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
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   378,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_Other,
                   @CrunchTime,
                   @AmcosVersionId
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'NO'
                  AND CourseType = 'C';
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
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   542,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_Other,
                   @CrunchTime,
                   @AmcosVersionId
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'RO'
                  AND CourseType = 'C';

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
                CrunchTime,
                AmcosVersionId,
                LocationId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   237,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_MPA,
                   @CrunchTime,
                   @AmcosVersionId,
                   -1
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'AWO'
                  AND CourseType = 'C';
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
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   440,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_MPA,
                   @CrunchTime,
                   @AmcosVersionId
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'NWO'
                  AND CourseType = 'C';
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
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   604,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_MPA,
                   @CrunchTime,
                   @AmcosVersionId
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'RWO'
                  AND CourseType = 'C';
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
                CrunchTime,
                AmcosVersionId,
                LocationId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   252,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_OMA,
                   @CrunchTime,
                   @AmcosVersionId,
                   -1
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'AWO'
                  AND CourseType = 'C';
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
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   420,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_OMA,
                   @CrunchTime,
                   @AmcosVersionId
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'NWO'
                  AND CourseType = 'C';
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
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   584,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_OMA,
                   @CrunchTime,
                   @AmcosVersionId
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'RWO'
                  AND CourseType = 'C';
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
                CrunchTime,
                AmcosVersionId,
                LocationId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   265,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_Other,
                   @CrunchTime,
                   @AmcosVersionId,
                   -1
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'AWO'
                  AND CourseType = 'C';
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
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   429,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_Other,
                   @CrunchTime,
                   @AmcosVersionId
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'NWO'
                  AND CourseType = 'C';
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
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   593,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_Other,
                   @CrunchTime,
                   @AmcosVersionId
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'RWO'
                  AND CourseType = 'C';

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
                CrunchTime,
                AmcosVersionId,
                LocationId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   3983,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_MPA,
                   @CrunchTime,
                   @AmcosVersionId,
                   -1
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'AE'
                  AND CourseType = 'G';
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
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4019,
                   GradeType,
                   GradeLevel,
                   -1,
                   RPA_NGPA,
                   @CrunchTime,
                   @AmcosVersionId
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'NE'
                  AND CourseType = 'G';
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
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4031,
                   GradeType,
                   GradeLevel,
                   -1,
                   RPA_NGPA,
                   @CrunchTime,
                   @AmcosVersionId
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'RE'
                  AND CourseType = 'G';
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
                CrunchTime,
                AmcosVersionId,
                LocationId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4022,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_OMA,
                   @CrunchTime,
                   @AmcosVersionId,
                   -1
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'AE'
                  AND CourseType = 'G';
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
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4028,
                   GradeType,
                   GradeLevel,
                   -1,
                   OMAR_OMNG,
                   @CrunchTime,
                   @AmcosVersionId
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'NE'
                  AND CourseType = 'G';
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
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4025,
                   GradeType,
                   GradeLevel,
                   -1,
                   OMAR_OMNG,
                   @CrunchTime,
                   @AmcosVersionId
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'RE'
                  AND CourseType = 'G';

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
                CrunchTime,
                AmcosVersionId,
                LocationId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4016,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_MPA,
                   @CrunchTime,
                   @AmcosVersionId,
                   -1
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'AO'
                  AND CourseType = 'G';
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
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4018,
                   GradeType,
                   GradeLevel,
                   -1,
                   RPA_NGPA,
                   @CrunchTime,
                   @AmcosVersionId
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'NO'
                  AND CourseType = 'G';
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
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4030,
                   GradeType,
                   GradeLevel,
                   -1,
                   RPA_NGPA,
                   @CrunchTime,
                   @AmcosVersionId
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'RO'
                  AND CourseType = 'G';
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
                CrunchTime,
                AmcosVersionId,
                LocationId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4021,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_OMA,
                   @CrunchTime,
                   @AmcosVersionId,
                   -1
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'AO'
                  AND CourseType = 'G';
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
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4027,
                   GradeType,
                   GradeLevel,
                   -1,
                   OMAR_OMNG,
                   @CrunchTime,
                   @AmcosVersionId
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'NO'
                  AND CourseType = 'G';
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
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4024,
                   GradeType,
                   GradeLevel,
                   -1,
                   OMAR_OMNG,
                   @CrunchTime,
                   @AmcosVersionId
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'RO'
                  AND CourseType = 'G';

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
                CrunchTime,
                AmcosVersionId,
                LocationId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4017,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_MPA,
                   @CrunchTime,
                   @AmcosVersionId,
                   -1
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'AWO'
                  AND CourseType = 'G';
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
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4020,
                   GradeType,
                   GradeLevel,
                   -1,
                   RPA_NGPA,
                   @CrunchTime,
                   @AmcosVersionId
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'NWO'
                  AND CourseType = 'G';
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
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4032,
                   GradeType,
                   GradeLevel,
                   -1,
                   RPA_NGPA,
                   @CrunchTime,
                   @AmcosVersionId
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'RWO'
                  AND CourseType = 'G';
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
                CrunchTime,
                AmcosVersionId,
                LocationId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4023,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_OMA,
                   @CrunchTime,
                   @AmcosVersionId,
                   -1
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'AWO'
                  AND CourseType = 'G';
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
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4029,
                   GradeType,
                   GradeLevel,
                   -1,
                   OMAR_OMNG,
                   @CrunchTime,
                   @AmcosVersionId
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'NWO'
                  AND CourseType = 'G';
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
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4026,
                   GradeType,
                   GradeLevel,
                   -1,
                   OMAR_OMNG,
                   @CrunchTime,
                   @AmcosVersionId
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'RWO'
                  AND CourseType = 'G';

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
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4033,
                   GradeType,
                   GradeLevel,
                   -1,
                   RPA_NGPA,
                   @CrunchTime,
                   @AmcosVersionId
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'NE'
                  AND CourseType = 'IET';
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
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4040,
                   GradeType,
                   GradeLevel,
                   -1,
                   RPA_NGPA,
                   @CrunchTime,
                   @AmcosVersionId
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'RE'
                  AND CourseType = 'IET';
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
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4039,
                   GradeType,
                   GradeLevel,
                   -1,
                   OMAR_OMNG,
                   @CrunchTime,
                   @AmcosVersionId
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'NE'
                  AND CourseType = 'IET';
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
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4038,
                   GradeType,
                   GradeLevel,
                   -1,
                   OMAR_OMNG,
                   @CrunchTime,
                   @AmcosVersionId
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'RE'
                  AND CourseType = 'IET';

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
                CrunchTime,
                AmcosVersionId,
                LocationId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   3391,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_MPA,
                   @CrunchTime,
                   @AmcosVersionId,
                   -1
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'AO'
                  AND CourseType = 'IET';
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
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   3427,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_MPA,
                   @CrunchTime,
                   @AmcosVersionId
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'NO'
                  AND CourseType = 'IET';
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
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   3461,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_MPA,
                   @CrunchTime,
                   @AmcosVersionId
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'RO'
                  AND CourseType = 'IET';
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
                CrunchTime,
                AmcosVersionId,
                LocationId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   3395,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_OMA,
                   @CrunchTime,
                   @AmcosVersionId,
                   -1
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'AO'
                  AND CourseType = 'IET';
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
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   3429,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_OMA,
                   @CrunchTime,
                   @AmcosVersionId
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'NO'
                  AND CourseType = 'IET';
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
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   3455,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_OMA,
                   @CrunchTime,
                   @AmcosVersionId
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'RO'
                  AND CourseType = 'IET';
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
                CrunchTime,
                AmcosVersionId,
                LocationId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   3399,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_Other,
                   @CrunchTime,
                   @AmcosVersionId,
                   -1
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'AO'
                  AND CourseType = 'IET';
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
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   3431,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_Other,
                   @CrunchTime,
                   @AmcosVersionId
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'NO'
                  AND CourseType = 'IET';
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
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   3457,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_Other,
                   @CrunchTime,
                   @AmcosVersionId
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'RO'
                  AND CourseType = 'IET';

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
                CrunchTime,
                AmcosVersionId,
                LocationId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   3403,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_MPA,
                   @CrunchTime,
                   @AmcosVersionId,
                   -1
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'AWO'
                  AND CourseType = 'IET';
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
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   3435,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_MPA,
                   @CrunchTime,
                   @AmcosVersionId
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'NWO'
                  AND CourseType = 'IET';
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
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   3469,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_MPA,
                   @CrunchTime,
                   @AmcosVersionId
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'RWO'
                  AND CourseType = 'IET';
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
                CrunchTime,
                AmcosVersionId,
                LocationId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   3407,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_OMA,
                   @CrunchTime,
                   @AmcosVersionId,
                   -1
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'AWO'
                  AND CourseType = 'IET';
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
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   3437,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_OMA,
                   @CrunchTime,
                   @AmcosVersionId
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'NWO'
                  AND CourseType = 'IET';
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
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   3463,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_OMA,
                   @CrunchTime,
                   @AmcosVersionId
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'RWO'
                  AND CourseType = 'IET';
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
                CrunchTime,
                AmcosVersionId,
                LocationId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   3411,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_Other,
                   @CrunchTime,
                   @AmcosVersionId,
                   -1
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'AWO'
                  AND CourseType = 'IET';
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
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   3439,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_Other,
                   @CrunchTime,
                   @AmcosVersionId
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'NWO'
                  AND CourseType = 'IET';
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
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   3465,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_Other,
                   @CrunchTime,
                   @AmcosVersionId
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'RWO'
                  AND CourseType = 'IET';

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
                CrunchTime,
                AmcosVersionId,
                LocationId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   60,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_MPA,
                   @CrunchTime,
                   @AmcosVersionId,
                   -1
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'AE'
                  AND CourseType = 'AIT';
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
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4095,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_MPA,
                   @CrunchTime,
                   @AmcosVersionId
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'NE'
                  AND CourseType = 'AIT';
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
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4096,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_MPA,
                   @CrunchTime,
                   @AmcosVersionId
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'RE'
                  AND CourseType = 'AIT';
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
                CrunchTime,
                AmcosVersionId,
                LocationId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   95,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_OMA,
                   @CrunchTime,
                   @AmcosVersionId,
                   -1
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'AE'
                  AND CourseType = 'AIT';
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
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4098,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_OMA,
                   @CrunchTime,
                   @AmcosVersionId
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'NE'
                  AND CourseType = 'AIT';
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
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4099,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_OMA,
                   @CrunchTime,
                   @AmcosVersionId
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'RE'
                  AND CourseType = 'AIT';
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
                CrunchTime,
                AmcosVersionId,
                LocationId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   114,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_Other,
                   @CrunchTime,
                   @AmcosVersionId,
                   -1
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'AE'
                  AND CourseType = 'AIT';
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
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4100,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_Other,
                   @CrunchTime,
                   @AmcosVersionId
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'NE'
                  AND CourseType = 'AIT';
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
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4101,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_Other,
                   @CrunchTime,
                   @AmcosVersionId
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'RE'
                  AND CourseType = 'AIT';

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
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4097,
                   GradeType,
                   GradeLevel,
                   -1,
                   RPA_NGPA,
                   @CrunchTime,
                   @AmcosVersionId
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'NE'
                  AND CourseType = 'AIT';
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
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4104,
                   GradeType,
                   GradeLevel,
                   -1,
                   RPA_NGPA,
                   @CrunchTime,
                   @AmcosVersionId
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'RE'
                  AND CourseType = 'AIT';
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
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4103,
                   GradeType,
                   GradeLevel,
                   -1,
                   OMAR_OMNG,
                   @CrunchTime,
                   @AmcosVersionId
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'NE'
                  AND CourseType = 'AIT';
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
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4102,
                   GradeType,
                   GradeLevel,
                   -1,
                   OMAR_OMNG,
                   @CrunchTime,
                   @AmcosVersionId
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'RE'
                  AND CourseType = 'AIT';

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
                CrunchTime,
                AmcosVersionId,
                LocationId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   670,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_MPA,
                   @CrunchTime,
                   @AmcosVersionId,
                   -1
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'AO'
                  AND CourseType = 'F';
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
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   3029,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_MPA,
                   @CrunchTime,
                   @AmcosVersionId
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'NO'
                  AND CourseType = 'F';
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
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   673,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_MPA,
                   @CrunchTime,
                   @AmcosVersionId
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'RO'
                  AND CourseType = 'F';
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
                CrunchTime,
                AmcosVersionId,
                LocationId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   671,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_OMA,
                   @CrunchTime,
                   @AmcosVersionId,
                   -1
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'AO'
                  AND CourseType = 'F';
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
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   3031,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_OMA,
                   @CrunchTime,
                   @AmcosVersionId
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'NO'
                  AND CourseType = 'F';
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
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   674,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_OMA,
                   @CrunchTime,
                   @AmcosVersionId
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'RO'
                  AND CourseType = 'F';
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
                CrunchTime,
                AmcosVersionId,
                LocationId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   672,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_Other,
                   @CrunchTime,
                   @AmcosVersionId,
                   -1
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'AO'
                  AND CourseType = 'F';
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
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   3033,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_Other,
                   @CrunchTime,
                   @AmcosVersionId
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'NO'
                  AND CourseType = 'F';
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
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   675,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_Other,
                   @CrunchTime,
                   @AmcosVersionId
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'RO'
                  AND CourseType = 'F';

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
                CrunchTime,
                AmcosVersionId,
                LocationId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   692,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_MPA,
                   @CrunchTime,
                   @AmcosVersionId,
                   -1
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'AWO'
                  AND CourseType = 'F';
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
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   3041,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_MPA,
                   @CrunchTime,
                   @AmcosVersionId
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'NWO'
                  AND CourseType = 'F';
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
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   3017,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_MPA,
                   @CrunchTime,
                   @AmcosVersionId
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'RWO'
                  AND CourseType = 'F';
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
                CrunchTime,
                AmcosVersionId,
                LocationId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   693,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_OMA,
                   @CrunchTime,
                   @AmcosVersionId,
                   -1
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'AWO'
                  AND CourseType = 'F';
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
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   3043,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_OMA,
                   @CrunchTime,
                   @AmcosVersionId
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'NWO'
                  AND CourseType = 'F';
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
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   3019,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_OMA,
                   @CrunchTime,
                   @AmcosVersionId
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'RWO'
                  AND CourseType = 'F';
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
                CrunchTime,
                AmcosVersionId,
                LocationId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   694,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_Other,
                   @CrunchTime,
                   @AmcosVersionId,
                   -1
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'AWO'
                  AND CourseType = 'F';
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
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   3045,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_Other,
                   @CrunchTime,
                   @AmcosVersionId
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'NWO'
                  AND CourseType = 'F';
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
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   3021,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_Other,
                   @CrunchTime,
                   @AmcosVersionId
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'RWO'
                  AND CourseType = 'F';

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
                CrunchTime,
                AmcosVersionId,
                LocationId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   62,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_MPA,
                   @CrunchTime,
                   @AmcosVersionId,
                   -1
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'AE'
                  AND CourseType = 'OSUT';
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
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4037,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_MPA,
                   @CrunchTime,
                   @AmcosVersionId
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'NE'
                  AND CourseType = 'OSUT';
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
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4036,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_MPA,
                   @CrunchTime,
                   @AmcosVersionId
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'RE'
                  AND CourseType = 'OSUT';
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
                CrunchTime,
                AmcosVersionId,
                LocationId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   97,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_OMA,
                   @CrunchTime,
                   @AmcosVersionId,
                   -1
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'AE'
                  AND CourseType = 'OSUT';
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
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4108,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_OMA,
                   @CrunchTime,
                   @AmcosVersionId
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'NE'
                  AND CourseType = 'OSUT';
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
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4107,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_OMA,
                   @CrunchTime,
                   @AmcosVersionId
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'RE'
                  AND CourseType = 'OSUT';
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
                CrunchTime,
                AmcosVersionId,
                LocationId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   116,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_Other,
                   @CrunchTime,
                   @AmcosVersionId,
                   -1
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'AE'
                  AND CourseType = 'OSUT';
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
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4176,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_Other,
                   @CrunchTime,
                   @AmcosVersionId
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'NE'
                  AND CourseType = 'OSUT';
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
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4175,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_Other,
                   @CrunchTime,
                   @AmcosVersionId
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'RE'
                  AND CourseType = 'OSUT';

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
                CrunchTime,
                AmcosVersionId,
                LocationId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   649,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_MPA,
                   @CrunchTime,
                   @AmcosVersionId,
                   -1
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'AO'
                  AND CourseType = 'O';
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
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   3035,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_MPA,
                   @CrunchTime,
                   @AmcosVersionId
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'NO'
                  AND CourseType = 'O';
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
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   655,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_MPA,
                   @CrunchTime,
                   @AmcosVersionId
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'RO'
                  AND CourseType = 'O';
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
                CrunchTime,
                AmcosVersionId,
                LocationId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   650,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_OMA,
                   @CrunchTime,
                   @AmcosVersionId,
                   -1
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'AO'
                  AND CourseType = 'O';
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
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   3037,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_OMA,
                   @CrunchTime,
                   @AmcosVersionId
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'NO'
                  AND CourseType = 'O';
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
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   656,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_OMA,
                   @CrunchTime,
                   @AmcosVersionId
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'RO'
                  AND CourseType = 'O';
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
                CrunchTime,
                AmcosVersionId,
                LocationId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   651,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_Other,
                   @CrunchTime,
                   @AmcosVersionId,
                   -1
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'AO'
                  AND CourseType = 'O';
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
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   3039,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_Other,
                   @CrunchTime,
                   @AmcosVersionId
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'NO'
                  AND CourseType = 'O';
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
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   657,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_Other,
                   @CrunchTime,
                   @AmcosVersionId
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'RO'
                  AND CourseType = 'O';

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
                CrunchTime,
                AmcosVersionId,
                LocationId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   686,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_MPA,
                   @CrunchTime,
                   @AmcosVersionId,
                   -1
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'AWO'
                  AND CourseType = 'O';
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
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   3047,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_MPA,
                   @CrunchTime,
                   @AmcosVersionId
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'NWO'
                  AND CourseType = 'O';
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
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   3023,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_MPA,
                   @CrunchTime,
                   @AmcosVersionId
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'RWO'
                  AND CourseType = 'O';
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
                CrunchTime,
                AmcosVersionId,
                LocationId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   687,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_OMA,
                   @CrunchTime,
                   @AmcosVersionId,
                   -1
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'AWO'
                  AND CourseType = 'O';
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
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   3049,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_OMA,
                   @CrunchTime,
                   @AmcosVersionId
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'NWO'
                  AND CourseType = 'O';
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
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   3025,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_OMA,
                   @CrunchTime,
                   @AmcosVersionId
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'RWO'
                  AND CourseType = 'O';
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
                CrunchTime,
                AmcosVersionId,
                LocationId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   688,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_Other,
                   @CrunchTime,
                   @AmcosVersionId,
                   -1
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'AWO'
                  AND CourseType = 'O';
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
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   3051,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_Other,
                   @CrunchTime,
                   @AmcosVersionId
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'NWO'
                  AND CourseType = 'O';
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
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   3027,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_Other,
                   @CrunchTime,
                   @AmcosVersionId
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'RWO'
                  AND CourseType = 'O';

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
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4162,
                   GradeType,
                   GradeLevel,
                   -1,
                   RPA_NGPA,
                   @CrunchTime,
                   @AmcosVersionId
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'NE'
                  AND CourseType = 'P';
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
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4171,
                   GradeType,
                   GradeLevel,
                   -1,
                   RPA_NGPA,
                   @CrunchTime,
                   @AmcosVersionId
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'RE'
                  AND CourseType = 'P';
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
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4168,
                   GradeType,
                   GradeLevel,
                   -1,
                   OMAR_OMNG,
                   @CrunchTime,
                   @AmcosVersionId
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'NE'
                  AND CourseType = 'P';
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
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4165,
                   GradeType,
                   GradeLevel,
                   -1,
                   OMAR_OMNG,
                   @CrunchTime,
                   @AmcosVersionId
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'RE'
                  AND CourseType = 'P';

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
                CrunchTime,
                AmcosVersionId,
                LocationId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   3379,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_MPA,
                   @CrunchTime,
                   @AmcosVersionId,
                   -1
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'AE'
                  AND CourseType = 'P';
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
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   3423,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_MPA,
                   @CrunchTime,
                   @AmcosVersionId
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'NE'
                  AND CourseType = 'P';
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
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   3451,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_MPA,
                   @CrunchTime,
                   @AmcosVersionId
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'RE'
                  AND CourseType = 'P';
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
                CrunchTime,
                AmcosVersionId,
                LocationId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   3383,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_OMA,
                   @CrunchTime,
                   @AmcosVersionId,
                   -1
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'AE'
                  AND CourseType = 'P';
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
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   3415,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_OMA,
                   @CrunchTime,
                   @AmcosVersionId
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'NE'
                  AND CourseType = 'P';
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
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   3443,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_OMA,
                   @CrunchTime,
                   @AmcosVersionId
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'RE'
                  AND CourseType = 'P';
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
                CrunchTime,
                AmcosVersionId,
                LocationId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   3387,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_Other,
                   @CrunchTime,
                   @AmcosVersionId,
                   -1
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'AE'
                  AND CourseType = 'P';
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
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   3419,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_Other,
                   @CrunchTime,
                   @AmcosVersionId
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'NE'
                  AND CourseType = 'P';
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
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   3447,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_Other,
                   @CrunchTime,
                   @AmcosVersionId
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'RE'
                  AND CourseType = 'P';

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
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4161,
                   GradeType,
                   GradeLevel,
                   -1,
                   RPA_NGPA,
                   @CrunchTime,
                   @AmcosVersionId
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'NO'
                  AND CourseType = 'P';
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
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4170,
                   GradeType,
                   GradeLevel,
                   -1,
                   RPA_NGPA,
                   @CrunchTime,
                   @AmcosVersionId
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'RO'
                  AND CourseType = 'P';
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
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4167,
                   GradeType,
                   GradeLevel,
                   -1,
                   OMAR_OMNG,
                   @CrunchTime,
                   @AmcosVersionId
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'NO'
                  AND CourseType = 'P';
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
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4164,
                   GradeType,
                   GradeLevel,
                   -1,
                   OMAR_OMNG,
                   @CrunchTime,
                   @AmcosVersionId
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'RO'
                  AND CourseType = 'P';

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
                CrunchTime,
                AmcosVersionId,
                LocationId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   165,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_MPA,
                   @CrunchTime,
                   @AmcosVersionId,
                   -1
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'AO'
                  AND CourseType = 'P';
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
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   404,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_MPA,
                   @CrunchTime,
                   @AmcosVersionId
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'NO'
                  AND CourseType = 'P';
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
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   568,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_MPA,
                   @CrunchTime,
                   @AmcosVersionId
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'RO'
                  AND CourseType = 'P';
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
                CrunchTime,
                AmcosVersionId,
                LocationId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   186,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_OMA,
                   @CrunchTime,
                   @AmcosVersionId,
                   -1
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'AO'
                  AND CourseType = 'P';
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
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   371,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_OMA,
                   @CrunchTime,
                   @AmcosVersionId
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'NO'
                  AND CourseType = 'P';
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
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   535,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_OMA,
                   @CrunchTime,
                   @AmcosVersionId
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'RO'
                  AND CourseType = 'P';
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
                CrunchTime,
                AmcosVersionId,
                LocationId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   196,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_Other,
                   @CrunchTime,
                   @AmcosVersionId,
                   -1
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'AO'
                  AND CourseType = 'P';
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
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   380,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_Other,
                   @CrunchTime,
                   @AmcosVersionId
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'NO'
                  AND CourseType = 'P';
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
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   544,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_Other,
                   @CrunchTime,
                   @AmcosVersionId
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'RO'
                  AND CourseType = 'P';

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
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4163,
                   GradeType,
                   GradeLevel,
                   -1,
                   RPA_NGPA,
                   @CrunchTime,
                   @AmcosVersionId
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'NWO'
                  AND CourseType = 'P';
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
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4172,
                   GradeType,
                   GradeLevel,
                   -1,
                   RPA_NGPA,
                   @CrunchTime,
                   @AmcosVersionId
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'RWO'
                  AND CourseType = 'P';
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
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4169,
                   GradeType,
                   GradeLevel,
                   -1,
                   OMAR_OMNG,
                   @CrunchTime,
                   @AmcosVersionId
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'NWO'
                  AND CourseType = 'P';
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
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4166,
                   GradeType,
                   GradeLevel,
                   -1,
                   OMAR_OMNG,
                   @CrunchTime,
                   @AmcosVersionId
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'RWO'
                  AND CourseType = 'P';

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
                CrunchTime,
                AmcosVersionId,
                LocationId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   239,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_MPA,
                   @CrunchTime,
                   @AmcosVersionId,
                   -1
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'AWO'
                  AND CourseType = 'P';
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
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   444,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_MPA,
                   @CrunchTime,
                   @AmcosVersionId
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'NWO'
                  AND CourseType = 'P';
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
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   608,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_MPA,
                   @CrunchTime,
                   @AmcosVersionId
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'RWO'
                  AND CourseType = 'P';
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
                CrunchTime,
                AmcosVersionId,
                LocationId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   254,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_OMA,
                   @CrunchTime,
                   @AmcosVersionId,
                   -1
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'AWO'
                  AND CourseType = 'P';
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
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   422,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_OMA,
                   @CrunchTime,
                   @AmcosVersionId
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'NWO'
                  AND CourseType = 'P';
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
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   586,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_OMA,
                   @CrunchTime,
                   @AmcosVersionId
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'RWO'
                  AND CourseType = 'P';
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
                CrunchTime,
                AmcosVersionId,
                LocationId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   267,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_Other,
                   @CrunchTime,
                   @AmcosVersionId,
                   -1
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'AWO'
                  AND CourseType = 'P';
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
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   431,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_Other,
                   @CrunchTime,
                   @AmcosVersionId
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'NWO'
                  AND CourseType = 'P';
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
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   595,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_Other,
                   @CrunchTime,
                   @AmcosVersionId
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'RWO'
                  AND CourseType = 'P';

            --##########################  Average cost of Weapon System Training #################################
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
                CrunchTime,
                AmcosVersionId,
                LocationId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   3381,
                   GradeType,
                   GradeLevel,
                   WeaponSystemId,
                   CGLA_MPA,
                   @CrunchTime,
                   @AmcosVersionId,
                   -1
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'AE'
                  AND CourseType = 'W';
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
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   3417,
                   GradeType,
                   GradeLevel,
                   WeaponSystemId,
                   CGLA_MPA,
                   @CrunchTime,
                   @AmcosVersionId
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'NE'
                  AND CourseType = 'W';
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
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   3453,
                   GradeType,
                   GradeLevel,
                   WeaponSystemId,
                   CGLA_MPA,
                   @CrunchTime,
                   @AmcosVersionId
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'RE'
                  AND CourseType = 'W';
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
                CrunchTime,
                AmcosVersionId,
                LocationId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   3385,
                   GradeType,
                   GradeLevel,
                   WeaponSystemId,
                   CGLA_OMA,
                   @CrunchTime,
                   @AmcosVersionId,
                   -1
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'AE'
                  AND CourseType = 'W';
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
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   3421,
                   GradeType,
                   GradeLevel,
                   WeaponSystemId,
                   CGLA_OMA,
                   @CrunchTime,
                   @AmcosVersionId
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'NE'
                  AND CourseType = 'W';
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
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   3445,
                   GradeType,
                   GradeLevel,
                   WeaponSystemId,
                   CGLA_OMA,
                   @CrunchTime,
                   @AmcosVersionId
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'RE'
                  AND CourseType = 'W';
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
                CrunchTime,
                AmcosVersionId,
                LocationId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   3389,
                   GradeType,
                   GradeLevel,
                   WeaponSystemId,
                   CGLA_Other,
                   @CrunchTime,
                   @AmcosVersionId,
                   -1
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'AE'
                  AND CourseType = 'W';
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
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   3425,
                   GradeType,
                   GradeLevel,
                   WeaponSystemId,
                   CGLA_Other,
                   @CrunchTime,
                   @AmcosVersionId
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'NE'
                  AND CourseType = 'W';
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
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   3449,
                   GradeType,
                   GradeLevel,
                   WeaponSystemId,
                   CGLA_Other,
                   @CrunchTime,
                   @AmcosVersionId
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'RE'
                  AND CourseType = 'W';

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
                CrunchTime,
                AmcosVersionId,
                LocationId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   3393,
                   GradeType,
                   GradeLevel,
                   WeaponSystemId,
                   CGLA_MPA,
                   @CrunchTime,
                   @AmcosVersionId,
                   -1
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'AO'
                  AND CourseType = 'W';
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
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   3471,
                   GradeType,
                   GradeLevel,
                   WeaponSystemId,
                   CGLA_MPA,
                   @CrunchTime,
                   @AmcosVersionId
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'NO'
                  AND CourseType = 'W';
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
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   3479,
                   GradeType,
                   GradeLevel,
                   WeaponSystemId,
                   CGLA_MPA,
                   @CrunchTime,
                   @AmcosVersionId
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'RO'
                  AND CourseType = 'W';
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
                CrunchTime,
                AmcosVersionId,
                LocationId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   3397,
                   GradeType,
                   GradeLevel,
                   WeaponSystemId,
                   CGLA_OMA,
                   @CrunchTime,
                   @AmcosVersionId,
                   -1
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'AO'
                  AND CourseType = 'W';
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
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   3472,
                   GradeType,
                   GradeLevel,
                   WeaponSystemId,
                   CGLA_OMA,
                   @CrunchTime,
                   @AmcosVersionId
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'NO'
                  AND CourseType = 'W';
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
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   3480,
                   GradeType,
                   GradeLevel,
                   WeaponSystemId,
                   CGLA_OMA,
                   @CrunchTime,
                   @AmcosVersionId
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'RO'
                  AND CourseType = 'W';
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
                CrunchTime,
                AmcosVersionId,
                LocationId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   3401,
                   GradeType,
                   GradeLevel,
                   WeaponSystemId,
                   CGLA_Other,
                   @CrunchTime,
                   @AmcosVersionId,
                   -1
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'AO'
                  AND CourseType = 'W';
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
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   3433,
                   GradeType,
                   GradeLevel,
                   WeaponSystemId,
                   CGLA_Other,
                   @CrunchTime,
                   @AmcosVersionId
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'NO'
                  AND CourseType = 'W';
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
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   3459,
                   GradeType,
                   GradeLevel,
                   WeaponSystemId,
                   CGLA_Other,
                   @CrunchTime,
                   @AmcosVersionId
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'RO'
                  AND CourseType = 'W';

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
                CrunchTime,
                AmcosVersionId,
                LocationId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   3405,
                   GradeType,
                   GradeLevel,
                   WeaponSystemId,
                   CGLA_MPA,
                   @CrunchTime,
                   @AmcosVersionId,
                   -1
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'AWO'
                  AND CourseType = 'W';
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
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   3475,
                   GradeType,
                   GradeLevel,
                   WeaponSystemId,
                   CGLA_MPA,
                   @CrunchTime,
                   @AmcosVersionId
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'NWO'
                  AND CourseType = 'W';
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
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   3483,
                   GradeType,
                   GradeLevel,
                   WeaponSystemId,
                   CGLA_MPA,
                   @CrunchTime,
                   @AmcosVersionId
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'RWO'
                  AND CourseType = 'W';
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
                CrunchTime,
                AmcosVersionId,
                LocationId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   3409,
                   GradeType,
                   GradeLevel,
                   WeaponSystemId,
                   CGLA_OMA,
                   @CrunchTime,
                   @AmcosVersionId,
                   -1
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'AWO'
                  AND CourseType = 'W';
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
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   3476,
                   GradeType,
                   GradeLevel,
                   WeaponSystemId,
                   CGLA_OMA,
                   @CrunchTime,
                   @AmcosVersionId
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'NWO'
                  AND CourseType = 'W';
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
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   3484,
                   GradeType,
                   GradeLevel,
                   WeaponSystemId,
                   CGLA_OMA,
                   @CrunchTime,
                   @AmcosVersionId
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'RWO'
                  AND CourseType = 'W';
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
                CrunchTime,
                AmcosVersionId,
                LocationId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   3413,
                   GradeType,
                   GradeLevel,
                   WeaponSystemId,
                   CGLA_Other,
                   @CrunchTime,
                   @AmcosVersionId,
                   -1
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'AWO'
                  AND CourseType = 'W';
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
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   3441,
                   GradeType,
                   GradeLevel,
                   WeaponSystemId,
                   CGLA_Other,
                   @CrunchTime,
                   @AmcosVersionId
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'NWO'
                  AND CourseType = 'W';
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
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   3467,
                   GradeType,
                   GradeLevel,
                   WeaponSystemId,
                   CGLA_Other,
                   @CrunchTime,
                   @AmcosVersionId
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'RWO'
                  AND CourseType = 'W';

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
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4177,
                   GradeType,
                   GradeLevel,
                   -1,
                   SUM(RPA_NGPA),
                   @CrunchTime,
                   @AmcosVersionId
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'NE'
            GROUP BY PayPlan,
                     CategoryGroupCode,
                     CategorySubgroupCode,
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
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4186,
                   GradeType,
                   GradeLevel,
                   -1,
                   SUM(RPA_NGPA),
                   @CrunchTime,
                   @AmcosVersionId
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'RE'
            GROUP BY PayPlan,
                     CategoryGroupCode,
                     CategorySubgroupCode,
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
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4183,
                   GradeType,
                   GradeLevel,
                   -1,
                   SUM(OMAR_OMNG),
                   @CrunchTime,
                   @AmcosVersionId
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'NE'
            GROUP BY PayPlan,
                     CategoryGroupCode,
                     CategorySubgroupCode,
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
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4180,
                   GradeType,
                   GradeLevel,
                   -1,
                   SUM(OMAR_OMNG),
                   @CrunchTime,
                   @AmcosVersionId
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'RE'
            GROUP BY PayPlan,
                     CategoryGroupCode,
                     CategorySubgroupCode,
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
                CrunchTime,
                AmcosVersionId,
                LocationId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   65,
                   GradeType,
                   GradeLevel,
                   -1,
                   SUM(CGLA_MPA),
                   @CrunchTime,
                   @AmcosVersionId,
                   -1
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'AE'
            GROUP BY PayPlan,
                     CategoryGroupCode,
                     CategorySubgroupCode,
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
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   352,
                   GradeType,
                   GradeLevel,
                   -1,
                   SUM(CGLA_MPA),
                   @CrunchTime,
                   @AmcosVersionId
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'NE'
            GROUP BY PayPlan,
                     CategoryGroupCode,
                     CategorySubgroupCode,
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
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   516,
                   GradeType,
                   GradeLevel,
                   -1,
                   SUM(CGLA_MPA),
                   @CrunchTime,
                   @AmcosVersionId
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'RE'
            GROUP BY PayPlan,
                     CategoryGroupCode,
                     CategorySubgroupCode,
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
                CrunchTime,
                AmcosVersionId,
                LocationId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   100,
                   GradeType,
                   GradeLevel,
                   -1,
                   SUM(CGLA_OMA),
                   @CrunchTime,
                   @AmcosVersionId,
                   -1
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'AE'
            GROUP BY PayPlan,
                     CategoryGroupCode,
                     CategorySubgroupCode,
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
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   313,
                   GradeType,
                   GradeLevel,
                   -1,
                   SUM(CGLA_OMA),
                   @CrunchTime,
                   @AmcosVersionId
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'NE'
            GROUP BY PayPlan,
                     CategoryGroupCode,
                     CategorySubgroupCode,
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
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   477,
                   GradeType,
                   GradeLevel,
                   -1,
                   SUM(CGLA_OMA),
                   @CrunchTime,
                   @AmcosVersionId
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'RE'
            GROUP BY PayPlan,
                     CategoryGroupCode,
                     CategorySubgroupCode,
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
                CrunchTime,
                AmcosVersionId,
                LocationId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   119,
                   GradeType,
                   GradeLevel,
                   -1,
                   SUM(CGLA_Other),
                   @CrunchTime,
                   @AmcosVersionId,
                   -1
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'AE'
            GROUP BY PayPlan,
                     CategoryGroupCode,
                     CategorySubgroupCode,
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
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   322,
                   GradeType,
                   GradeLevel,
                   -1,
                   SUM(CGLA_Other),
                   @CrunchTime,
                   @AmcosVersionId
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'NE'
            GROUP BY PayPlan,
                     CategoryGroupCode,
                     CategorySubgroupCode,
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
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   486,
                   GradeType,
                   GradeLevel,
                   -1,
                   SUM(CGLA_Other),
                   @CrunchTime,
                   @AmcosVersionId
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'RE'
            GROUP BY PayPlan,
                     CategoryGroupCode,
                     CategorySubgroupCode,
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
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4178,
                   GradeType,
                   GradeLevel,
                   -1,
                   SUM(RPA_NGPA),
                   @CrunchTime,
                   @AmcosVersionId
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'NO'
            GROUP BY PayPlan,
                     CategoryGroupCode,
                     CategorySubgroupCode,
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
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4187,
                   GradeType,
                   GradeLevel,
                   -1,
                   SUM(RPA_NGPA),
                   @CrunchTime,
                   @AmcosVersionId
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'RO'
            GROUP BY PayPlan,
                     CategoryGroupCode,
                     CategorySubgroupCode,
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
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4184,
                   GradeType,
                   GradeLevel,
                   -1,
                   SUM(OMAR_OMNG),
                   @CrunchTime,
                   @AmcosVersionId
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'NO'
            GROUP BY PayPlan,
                     CategoryGroupCode,
                     CategorySubgroupCode,
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
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4181,
                   GradeType,
                   GradeLevel,
                   -1,
                   SUM(OMAR_OMNG),
                   @CrunchTime,
                   @AmcosVersionId
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'RO'
            GROUP BY PayPlan,
                     CategoryGroupCode,
                     CategorySubgroupCode,
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
                CrunchTime,
                AmcosVersionId,
                LocationId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   167,
                   GradeType,
                   GradeLevel,
                   -1,
                   SUM(CGLA_MPA),
                   @CrunchTime,
                   @AmcosVersionId,
                   -1
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'AO'
            GROUP BY PayPlan,
                     CategoryGroupCode,
                     CategorySubgroupCode,
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
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   406,
                   GradeType,
                   GradeLevel,
                   -1,
                   SUM(CGLA_MPA),
                   @CrunchTime,
                   @AmcosVersionId
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'NO'
            GROUP BY PayPlan,
                     CategoryGroupCode,
                     CategorySubgroupCode,
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
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   570,
                   GradeType,
                   GradeLevel,
                   -1,
                   SUM(CGLA_MPA),
                   @CrunchTime,
                   @AmcosVersionId
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'RO'
            GROUP BY PayPlan,
                     CategoryGroupCode,
                     CategorySubgroupCode,
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
                CrunchTime,
                AmcosVersionId,
                LocationId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   188,
                   GradeType,
                   GradeLevel,
                   -1,
                   SUM(CGLA_OMA),
                   @CrunchTime,
                   @AmcosVersionId,
                   -1
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'AO'
            GROUP BY PayPlan,
                     CategoryGroupCode,
                     CategorySubgroupCode,
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
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   373,
                   GradeType,
                   GradeLevel,
                   -1,
                   SUM(CGLA_OMA),
                   @CrunchTime,
                   @AmcosVersionId
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'NO'
            GROUP BY PayPlan,
                     CategoryGroupCode,
                     CategorySubgroupCode,
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
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   537,
                   GradeType,
                   GradeLevel,
                   -1,
                   SUM(CGLA_OMA),
                   @CrunchTime,
                   @AmcosVersionId
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'RO'
            GROUP BY PayPlan,
                     CategoryGroupCode,
                     CategorySubgroupCode,
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
                CrunchTime,
                AmcosVersionId,
                LocationId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   198,
                   GradeType,
                   GradeLevel,
                   -1,
                   SUM(CGLA_Other),
                   @CrunchTime,
                   @AmcosVersionId,
                   -1
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'AO'
            GROUP BY PayPlan,
                     CategoryGroupCode,
                     CategorySubgroupCode,
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
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   382,
                   GradeType,
                   GradeLevel,
                   -1,
                   SUM(CGLA_Other),
                   @CrunchTime,
                   @AmcosVersionId
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'NO'
            GROUP BY PayPlan,
                     CategoryGroupCode,
                     CategorySubgroupCode,
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
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   546,
                   GradeType,
                   GradeLevel,
                   -1,
                   SUM(CGLA_Other),
                   @CrunchTime,
                   @AmcosVersionId
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'RO'
            GROUP BY PayPlan,
                     CategoryGroupCode,
                     CategorySubgroupCode,
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
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4179,
                   GradeType,
                   GradeLevel,
                   -1,
                   SUM(RPA_NGPA),
                   @CrunchTime,
                   @AmcosVersionId
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'NWO'
            GROUP BY PayPlan,
                     CategoryGroupCode,
                     CategorySubgroupCode,
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
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4188,
                   GradeType,
                   GradeLevel,
                   -1,
                   SUM(RPA_NGPA),
                   @CrunchTime,
                   @AmcosVersionId
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'RWO'
            GROUP BY PayPlan,
                     CategoryGroupCode,
                     CategorySubgroupCode,
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
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4185,
                   GradeType,
                   GradeLevel,
                   -1,
                   SUM(OMAR_OMNG),
                   @CrunchTime,
                   @AmcosVersionId
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'NWO'
            GROUP BY PayPlan,
                     CategoryGroupCode,
                     CategorySubgroupCode,
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
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4182,
                   GradeType,
                   GradeLevel,
                   -1,
                   SUM(OMAR_OMNG),
                   @CrunchTime,
                   @AmcosVersionId
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'RWO'
            GROUP BY PayPlan,
                     CategoryGroupCode,
                     CategorySubgroupCode,
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
                CrunchTime,
                AmcosVersionId,
                LocationId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   241,
                   GradeType,
                   GradeLevel,
                   -1,
                   SUM(CGLA_MPA),
                   @CrunchTime,
                   @AmcosVersionId,
                   -1
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'AWO'
            GROUP BY PayPlan,
                     CategoryGroupCode,
                     CategorySubgroupCode,
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
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   446,
                   GradeType,
                   GradeLevel,
                   -1,
                   SUM(CGLA_MPA),
                   @CrunchTime,
                   @AmcosVersionId
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'NWO'
            GROUP BY PayPlan,
                     CategoryGroupCode,
                     CategorySubgroupCode,
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
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   610,
                   GradeType,
                   GradeLevel,
                   -1,
                   SUM(CGLA_MPA),
                   @CrunchTime,
                   @AmcosVersionId
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'RWO'
            GROUP BY PayPlan,
                     CategoryGroupCode,
                     CategorySubgroupCode,
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
                CrunchTime,
                AmcosVersionId,
                LocationId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   256,
                   GradeType,
                   GradeLevel,
                   -1,
                   SUM(CGLA_OMA),
                   @CrunchTime,
                   @AmcosVersionId,
                   -1
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'AWO'
            GROUP BY PayPlan,
                     CategoryGroupCode,
                     CategorySubgroupCode,
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
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   424,
                   GradeType,
                   GradeLevel,
                   -1,
                   SUM(CGLA_OMA),
                   @CrunchTime,
                   @AmcosVersionId
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'NWO'
            GROUP BY PayPlan,
                     CategoryGroupCode,
                     CategorySubgroupCode,
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
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   588,
                   GradeType,
                   GradeLevel,
                   -1,
                   SUM(CGLA_OMA),
                   @CrunchTime,
                   @AmcosVersionId
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'RWO'
            GROUP BY PayPlan,
                     CategoryGroupCode,
                     CategorySubgroupCode,
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
                CrunchTime,
                AmcosVersionId,
                LocationId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   269,
                   GradeType,
                   GradeLevel,
                   -1,
                   SUM(CGLA_Other),
                   @CrunchTime,
                   @AmcosVersionId,
                   -1
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'AWO'
            GROUP BY PayPlan,
                     CategoryGroupCode,
                     CategorySubgroupCode,
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
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   433,
                   GradeType,
                   GradeLevel,
                   -1,
                   SUM(CGLA_Other),
                   @CrunchTime,
                   @AmcosVersionId
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'NWO'
            GROUP BY PayPlan,
                     CategoryGroupCode,
                     CategorySubgroupCode,
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
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   597,
                   GradeType,
                   GradeLevel,
                   -1,
                   SUM(CGLA_Other),
                   @CrunchTime,
                   @AmcosVersionId
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'RWO'
            GROUP BY PayPlan,
                     CategoryGroupCode,
                     CategorySubgroupCode,
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
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4208,
                   GradeType,
                   GradeLevel,
                   -1,
                   RPA_NGPA,
                   @CrunchTime,
                   @AmcosVersionId
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'NO'
                  AND CourseType = 'IET';
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
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4210,
                   GradeType,
                   GradeLevel,
                   -1,
                   OMAR_OMNG,
                   @CrunchTime,
                   @AmcosVersionId
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'NO'
                  AND CourseType = 'IET';
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
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4209,
                   GradeType,
                   GradeLevel,
                   -1,
                   RPA_NGPA,
                   @CrunchTime,
                   @AmcosVersionId
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'NWO'
                  AND CourseType = 'IET';
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
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4211,
                   GradeType,
                   GradeLevel,
                   -1,
                   OMAR_OMNG,
                   @CrunchTime,
                   @AmcosVersionId
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'NWO'
                  AND CourseType = 'IET';
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
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4204,
                   GradeType,
                   GradeLevel,
                   -1,
                   RPA_NGPA,
                   @CrunchTime,
                   @AmcosVersionId
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'RO'
                  AND CourseType = 'IET';
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
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4206,
                   GradeType,
                   GradeLevel,
                   -1,
                   OMAR_OMNG,
                   @CrunchTime,
                   @AmcosVersionId
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'RO'
                  AND CourseType = 'IET';
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
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4205,
                   GradeType,
                   GradeLevel,
                   -1,
                   RPA_NGPA,
                   @CrunchTime,
                   @AmcosVersionId
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'RWO'
                  AND CourseType = 'IET';
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
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4207,
                   GradeType,
                   GradeLevel,
                   -1,
                   OMAR_OMNG,
                   @CrunchTime,
                   @AmcosVersionId
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'RWO'
                  AND CourseType = 'IET';
        END;

        --delete any costs which are zero
        DELETE FROM crunch.Costs_AE
        WHERE Amount = 0
              AND AmcosVersionId = @AmcosVersionId;
        DELETE FROM crunch.Costs_AO
        WHERE Amount = 0
              AND AmcosVersionId = @AmcosVersionId;
        DELETE FROM crunch.Costs_AWO
        WHERE Amount = 0
              AND AmcosVersionId = @AmcosVersionId;
        DELETE FROM crunch.Costs_RE
        WHERE Amount = 0
              AND AmcosVersionId = @AmcosVersionId;
        DELETE FROM crunch.Costs_RO
        WHERE Amount = 0
              AND AmcosVersionId = @AmcosVersionId;
        DELETE FROM crunch.Costs_RWO
        WHERE Amount = 0
              AND AmcosVersionId = @AmcosVersionId;
        DELETE FROM crunch.Costs_NE
        WHERE Amount = 0
              AND AmcosVersionId = @AmcosVersionId;
        DELETE FROM crunch.Costs_NO
        WHERE Amount = 0
              AND AmcosVersionId = @AmcosVersionId;
        DELETE FROM crunch.Costs_NWO
        WHERE Amount = 0
              AND AmcosVersionId = @AmcosVersionId;
    END;
END;