CREATE PROC [web].[ProjectAddUnit]
    @CategoryId INT,
    @UIC NVARCHAR(6),
    @NotSelectedPayPlans NVARCHAR(500),
    @UnitLocation NVARCHAR(150),
    @MtoeProjectInventoryYear NVARCHAR(25) = NULL,
    @MtoeSyncExtendedDurationFillValue NVARCHAR(25) = 'OTOE',
    @UserOverheadPercent FLOAT = 150,
    @AmcosVersionId INT,
    @Debug AS BIT = 0
AS
/* This query finds units that have personnel, but no corresponding cost in AMCOS */
--SELECT TOP 100
--       UIC,
--       UICTitle,
--       PayPlan,
--       CategoryGroupCode,
--       CategorySubgroupCode,
--       LocationId,
--       LocationText,
--       STRL,
--       GradeLevel,
--       DependentStatus,
--       NumberOfDependents,
--       ActiveDutyDays,
--       OverheadPercent,
--       Inventory,
--       UnitYear,
--       AsOf,
--       AuthorizationDocument
--FROM warehouse.UnitPersonnel u
--WHERE NOT EXISTS
--(
--    SELECT PayPlan,
--           CMF,
--           AOC,
--           MHA,
--           LocationId,
--           DependentStatus,
--           WeaponSystemId,
--           GradeType,
--           GradeLevel,
--           CostElementId,
--           Amount,
--           CrunchTime,
--           AmcosVersionId
--    FROM crunch.Costs_AO
--    WHERE AmcosVersionId = 202201
--          AND PayPlan = u.PayPlan
--          AND CMF = u.CategoryGroupCode
--          AND AOC = u.CategorySubgroupCode
--          AND LocationId = u.LocationId
--          AND DependentStatus = u.DependentStatus
--          AND GradeLevel = u.GradeLevel
--)
--      AND u.PayPlan = 'AO';
--LastMtoe
--Otoe
BEGIN
    SET NOCOUNT ON;
    SET ARITHABORT ON;

    DECLARE @ProjectDurationYears INT = web.GetProjectYearDuration(@CategoryId);
    DECLARE @InventoryYearIndex INT;
    DECLARE @PayPlan NVARCHAR(3);
    DECLARE @CategoryGroupCode NVARCHAR(10);
    DECLARE @CategorySubgroupCode NVARCHAR(10);
    DECLARE @LocationId INT;
    DECLARE @LocationText NVARCHAR(150);
    DECLARE @STRL NVARCHAR(20);
    DECLARE @GradeLevel TINYINT;
    DECLARE @DependentStatus NVARCHAR(25);
    DECLARE @NumberOfDependents INT;
    DECLARE @ActiveDutyDays SMALLINT;
    DECLARE @OverheadPercent FLOAT;
    DECLARE @Inventory INT;
    DECLARE @UnitYear INT;
    DECLARE @YearIndex INT;
    DECLARE @AuthorizationDocument NVARCHAR(50);

    CREATE TABLE #ValidatedUnitPersonnel
    (
        [UIC] [NVARCHAR](6) NOT NULL,
        [AuthorizationDocument] [NVARCHAR](50) NOT NULL,
        [PayPlan] [NVARCHAR](3) NOT NULL,
        [CategoryGroupCode] [NVARCHAR](10) NOT NULL,
        [CategorySubgroupCode] [NVARCHAR](10) NOT NULL,
        [CareerProgramNumber] [NCHAR](2) NOT NULL,
        [LocationId] [INT] NOT NULL,
        [LocationText] [NVARCHAR](150) NOT NULL,
        [STRL] [NVARCHAR](20) NOT NULL,
        [GradeLevel] [TINYINT] NOT NULL,
        [DependentStatus] [NVARCHAR](25) NOT NULL,
        [NumberOfDependents] [INT] NOT NULL,
        [ActiveDutyDays] [SMALLINT] NOT NULL,
        [OverheadPercent] [FLOAT] NOT NULL,
        [UnitYear] [INT] NOT NULL,
        [YearIndex] [INT] NOT NULL,
        [Inventory] [INT] NOT NULL,
    );

    IF @Debug = 1
    BEGIN
        SELECT 'Rows from web.GetUnitPersonnel()';
        SELECT UIC,
               AuthorizationDocument,
               PayPlan,
               CategoryGroupCode,
               CategorySubgroupCode,
               LocationId,
               LocationText,
               STRL,
               GradeLevel,
               DependentStatus,
               NumberOfDependents,
               ActiveDutyDays,
               OverheadPercent,
               UnitYear,
               ROW_NUMBER() OVER (PARTITION BY UIC,
                                               AuthorizationDocument,
                                               PayPlan,
                                               CategoryGroupCode,
                                               CategorySubgroupCode,
                                               LocationId,
                                               LocationText,
                                               STRL,
                                               GradeLevel,
                                               DependentStatus,
                                               NumberOfDependents,
                                               ActiveDutyDays,
                                               OverheadPercent
                                  ORDER BY UnitYear
                                 ) AS YearIndex,
               Inventory
        FROM web.GetUnitPersonnel(
                                     @CategoryId,
                                     @UIC,
                                     @NotSelectedPayPlans,
                                     @UnitLocation,
                                     @MtoeProjectInventoryYear,
                                     @MtoeSyncExtendedDurationFillValue,
                                     @UserOverheadPercent
                                 )
        ORDER BY PayPlan,
                 CategoryGroupCode,
                 CategorySubgroupCode,
                 LocationId,
                 LocationText,
                 STRL,
                 GradeLevel,
                 DependentStatus,
                 NumberOfDependents,
                 ActiveDutyDays,
                 OverheadPercent,
                 UnitYear,
                 YearIndex;
    END;

    DECLARE cursor_results CURSOR LOCAL FAST_FORWARD FOR
    SELECT UIC,
           AuthorizationDocument,
           PayPlan,
           CategoryGroupCode,
           CategorySubgroupCode,
           LocationId,
           LocationText,
           STRL,
           GradeLevel,
           DependentStatus,
           NumberOfDependents,
           ActiveDutyDays,
           OverheadPercent,
           UnitYear,
           ROW_NUMBER() OVER (PARTITION BY UIC,
                                           AuthorizationDocument,
                                           PayPlan,
                                           CategoryGroupCode,
                                           CategorySubgroupCode,
                                           LocationId,
                                           LocationText,
                                           STRL,
                                           GradeLevel,
                                           DependentStatus,
                                           NumberOfDependents,
                                           ActiveDutyDays,
                                           OverheadPercent
                              ORDER BY UnitYear
                             ) AS YearIndex,
           Inventory
    FROM web.GetUnitPersonnel(
                                 @CategoryId,
                                 @UIC,
                                 @NotSelectedPayPlans,
                                 @UnitLocation,
                                 @MtoeProjectInventoryYear,
                                 @MtoeSyncExtendedDurationFillValue,
                                 @UserOverheadPercent
                             );


    OPEN cursor_results;
    FETCH NEXT FROM cursor_results
    INTO @UIC,
         @AuthorizationDocument,
         @PayPlan,
         @CategoryGroupCode,
         @CategorySubgroupCode,
         @LocationId,
         @LocationText,
         @STRL,
         @GradeLevel,
         @DependentStatus,
         @NumberOfDependents,
         @ActiveDutyDays,
         @OverheadPercent,
         @UnitYear,
         @YearIndex,
         @Inventory;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        INSERT INTO #ValidatedUnitPersonnel
        (
            UIC,
            AuthorizationDocument,
            PayPlan,
            CategoryGroupCode,
            CategorySubgroupCode,
            CareerProgramNumber,
            LocationId,
            LocationText,
            STRL,
            GradeLevel,
            DependentStatus,
            NumberOfDependents,
            ActiveDutyDays,
            OverheadPercent,
            UnitYear,
            YearIndex,
            Inventory
        )
        SELECT @UIC,
               @AuthorizationDocument,
               PayPlan,
               CategoryGroupCode,
               CategorySubgroupCode,
               CareerProgramNumber,
               LocationId,
               @LocationText,
               STRL,
               GradeLevel,
               DependentStatus,
               NumberOfDependents,
               @ActiveDutyDays,
               @OverheadPercent,
               @UnitYear,
               @YearIndex,
               @Inventory
        FROM web.PMValidateUnitRequirement(
                                              @PayPlan,
                                              @CategoryGroupCode,
                                              @CategorySubgroupCode,
                                              '-1',
                                              @LocationId,
                                              @STRL,
                                              @GradeLevel,
                                              @DependentStatus,
                                              @NumberOfDependents,
                                              @AmcosVersionId
                                          )
        WHERE @YearIndex <= @ProjectDurationYears;

        FETCH NEXT FROM cursor_results
        INTO @UIC,
             @AuthorizationDocument,
             @PayPlan,
             @CategoryGroupCode,
             @CategorySubgroupCode,
             @LocationId,
             @LocationText,
             @STRL,
             @GradeLevel,
             @DependentStatus,
             @NumberOfDependents,
             @ActiveDutyDays,
             @OverheadPercent,
             @UnitYear,
             @YearIndex,
             @Inventory;
    END;

    CLOSE cursor_results;
    DEALLOCATE cursor_results;

    IF @Debug = 1
    BEGIN
        SELECT 'Rows from #ValidatedUnitPersonnel';
        SELECT UIC,
               AuthorizationDocument,
               PayPlan,
               CategoryGroupCode,
               CategorySubgroupCode,
               CareerProgramNumber,
               LocationId,
               LocationText,
               STRL,
               GradeLevel,
               DependentStatus,
               NumberOfDependents,
               ActiveDutyDays,
               OverheadPercent,
               UnitYear,
               YearIndex,
               Inventory
        FROM #ValidatedUnitPersonnel
        ORDER BY PayPlan,
                 CategoryGroupCode,
                 CategorySubgroupCode,
                 LocationId,
                 LocationText,
                 STRL,
                 GradeLevel,
                 DependentStatus,
                 NumberOfDependents,
                 ActiveDutyDays,
                 OverheadPercent,
                 UnitYear,
                 YearIndex;
    END;


    /* Group the requirements and sum the duplicate rows */
    CREATE TABLE #DistinctUnitPersonnel
    (
        [UIC] [NVARCHAR](6) NOT NULL,
        [AuthorizationDocument] [NVARCHAR](50) NOT NULL,
        [PayPlan] [NVARCHAR](3) NOT NULL,
        [CategoryGroupCode] [NVARCHAR](10) NOT NULL,
        [CategorySubgroupCode] [NVARCHAR](10) NOT NULL,
        [CareerProgramNumber] [NCHAR](2) NOT NULL,
        [LocationId] [INT] NOT NULL,
        [LocationText] [NVARCHAR](150) NOT NULL,
        [STRL] [NVARCHAR](20) NOT NULL,
        [GradeLevel] [TINYINT] NOT NULL,
        [DependentStatus] [NVARCHAR](25) NOT NULL,
        [NumberOfDependents] [INT] NOT NULL,
        [ActiveDutyDays] [SMALLINT] NOT NULL,
        [OverheadPercent] [FLOAT] NOT NULL,
        [UnitYear] [INT] NOT NULL,
        [YearIndex] [INT] NOT NULL,
        [Inventory] [INT] NOT NULL
    );
    INSERT INTO #DistinctUnitPersonnel
    (
        UIC,
        AuthorizationDocument,
        PayPlan,
        CategoryGroupCode,
        CategorySubgroupCode,
        CareerProgramNumber,
        LocationId,
        LocationText,
        STRL,
        GradeLevel,
        DependentStatus,
        NumberOfDependents,
        ActiveDutyDays,
        OverheadPercent,
        UnitYear,
        YearIndex,
        Inventory
    )
    SELECT UIC,
           AuthorizationDocument,
           PayPlan,
           CategoryGroupCode,
           CategorySubgroupCode,
           CareerProgramNumber,
           LocationId,
           LocationText,
           STRL,
           GradeLevel,
           DependentStatus,
           NumberOfDependents,
           ActiveDutyDays,
           OverheadPercent,
           UnitYear,
           YearIndex,
           SUM(Inventory)
    FROM #ValidatedUnitPersonnel
    GROUP BY UIC,
             AuthorizationDocument,
             PayPlan,
             CategoryGroupCode,
             CategorySubgroupCode,
             CareerProgramNumber,
             LocationId,
             LocationText,
             STRL,
             GradeLevel,
             DependentStatus,
             NumberOfDependents,
             ActiveDutyDays,
             OverheadPercent,
             UnitYear,
             YearIndex;
    IF @Debug = 1
    BEGIN
        SELECT 'Rows from #DistinctUnitPersonnel';
        SELECT *
        FROM #DistinctUnitPersonnel;
    END;

    IF @Debug = 0
    BEGIN
        DECLARE cursor_results CURSOR LOCAL FAST_FORWARD FOR
        SELECT UIC,
               AuthorizationDocument,
               PayPlan,
               CategoryGroupCode,
               CategorySubgroupCode,
               LocationId,
               LocationText,
               STRL,
               GradeLevel,
               DependentStatus,
               NumberOfDependents,
               ActiveDutyDays,
               OverheadPercent,
               UnitYear,
               YearIndex,
               Inventory
        FROM #DistinctUnitPersonnel;

        OPEN cursor_results;
        FETCH NEXT FROM cursor_results
        INTO @UIC,
             @AuthorizationDocument,
             @PayPlan,
             @CategoryGroupCode,
             @CategorySubgroupCode,
             @LocationId,
             @LocationText,
             @STRL,
             @GradeLevel,
             @DependentStatus,
             @NumberOfDependents,
             @ActiveDutyDays,
             @OverheadPercent,
             @UnitYear,
             @YearIndex,
             @Inventory;

        WHILE @@FETCH_STATUS = 0
        BEGIN
            /* Perform the inserts */
            IF @AuthorizationDocument = 'MTOE'
            BEGIN
                /* Insert into webuser.PMCategorySkill and PMCategorySkillInventory */
                SET @InventoryYearIndex = @YearIndex - 1;
                --SELECT '@CategoryId=' + CAST(@CategoryId AS NVARCHAR(25));
                --SELECT '@PayPlan=' + CAST(@PayPlan AS NVARCHAR(25));
                --SELECT '@CategoryGroupCode=' + CAST(@CategoryGroupCode AS NVARCHAR(25));
                --SELECT '@CategorySubgroupCode=' + CAST(@CategorySubgroupCode AS NVARCHAR(25));
                --SELECT '@CareerProgramNumber=-1';
                --SELECT '@LocationId=' + CAST(@LocationId AS NVARCHAR(25));
                --SELECT '@LocationText=' + CAST(@LocationText AS NVARCHAR(25));
                --SELECT '@STRL=' + CAST(@STRL AS NVARCHAR(25));
                --SELECT '@GradeLevel=' + CAST(@GradeLevel AS NVARCHAR(25));
                --SELECT '@DependentStatus=' + CAST(@DependentStatus AS NVARCHAR(25));
                --SELECT '@NumberOfDependents=' + CAST(@NumberOfDependents AS NVARCHAR(25));
                --SELECT '@ActiveDutyDays=' + CAST(@ActiveDutyDays AS NVARCHAR(25));
                --SELECT '@OverheadPercent=' + CAST(@OverheadPercent AS NVARCHAR(25));
                --SELECT '@InventoryYearIndex=' + CAST(@InventoryYearIndex AS NVARCHAR(25));
                --SELECT '@InventoryAmount=' + CAST(@Inventory AS NVARCHAR(25));
                EXEC web.ProjectRequirementInsertMtoe @CategoryId = @CategoryId,
                                                      @UIC = @UIC,
                                                      @PayPlan = @PayPlan,
                                                      @CategoryGroupCode = @CategoryGroupCode,
                                                      @CategorySubgroupCode = @CategorySubgroupCode,
                                                      @CareerProgramNumber = '-1',
                                                      @LocationId = @LocationId,
                                                      @LocationText = @LocationText,
                                                      @STRL = @STRL,
                                                      @GradeLevel = @GradeLevel,
                                                      @DependentStatus = @DependentStatus,
                                                      @NumberOfDependents = @NumberOfDependents,
                                                      @ActiveDutyDays = @ActiveDutyDays,
                                                      @OverheadPercent = @OverheadPercent,
                                                      @InventoryYearIndex = @InventoryYearIndex,
                                                      @InventoryAmount = @Inventory;
            END;
            ELSE
                EXEC web.ProjectRequirementInsertTda @CategoryId = @CategoryId,                     -- int
                                                     @UIC = @UIC,
                                                     @PayPlan = @PayPlan,                           -- nvarchar(3)
                                                     @CategoryGroupCode = @CategoryGroupCode,       -- nvarchar(10)
                                                     @CategorySubgroupCode = @CategorySubgroupCode, -- nvarchar(10)
                                                     @CareerProgramNumber = N'-1',                  -- nchar(2)
                                                     @LocationId = @LocationId,                     -- int
                                                     @LocationText = @LocationText,                 -- nvarchar(150)
                                                     @STRL = @STRL,                                 -- nvarchar(20)
                                                     @GradeLevel = @GradeLevel,                     -- tinyint
                                                     @DependentStatus = @DependentStatus,           -- nvarchar(25)
                                                     @NumberOfDependents = @NumberOfDependents,     -- int
                                                     @ActiveDutyDays = @ActiveDutyDays,             -- smallint
                                                     @OverheadPercent = @OverheadPercent,           -- float
                                                     @InventoryAmount = @Inventory;                 -- int
            FETCH NEXT FROM cursor_results
            INTO @UIC,
                 @AuthorizationDocument,
                 @PayPlan,
                 @CategoryGroupCode,
                 @CategorySubgroupCode,
                 @LocationId,
                 @LocationText,
                 @STRL,
                 @GradeLevel,
                 @DependentStatus,
                 @NumberOfDependents,
                 @ActiveDutyDays,
                 @OverheadPercent,
                 @UnitYear,
                 @YearIndex,
                 @Inventory;

        END;

        CLOSE cursor_results;
        DEALLOCATE cursor_results;
    END;
END;