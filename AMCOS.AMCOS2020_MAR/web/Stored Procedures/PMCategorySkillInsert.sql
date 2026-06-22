CREATE PROC [web].[PMCategorySkillInsert]
    @CategoryId INT,
    @UIC NVARCHAR(6),
    @PayPlan NVARCHAR(3),
    @CategoryGroupCode NVARCHAR(10),
    @CategorySubgroupCode NVARCHAR(10),
    @CareerProgramNumber NCHAR(2),
    @LocationId INT,
    @LocationText NVARCHAR(150),
    @STRL NVARCHAR(20),
    @GradeLevel TINYINT,
    @DependentStatus NVARCHAR(25),
    @NumberOfDependents INT,
    @ActiveDutyDays SMALLINT,
    @OverheadPercent FLOAT,
    @InventoryYearIndex INT,
    @InventoryAmount INT
AS
BEGIN
    DECLARE @SkillId INT;
    IF EXISTS
    (
        SELECT *
        FROM webuser.PMCategorySkill
        WHERE CategoryId = @CategoryId
              AND PayPlan = @PayPlan
              AND CategoryGroupCode = @CategoryGroupCode
              AND CategorySubgroupCode = @CategorySubgroupCode
              AND CareerProgramNumber = @CareerProgramNumber
              AND LocationId = @LocationId
              AND LocationText = @LocationText
              AND STRL = @STRL
              AND GradeLevel = @GradeLevel
              AND DependentStatus = @DependentStatus
              AND NumberOfDependents = @NumberOfDependents
              AND ActiveDutyDays = @ActiveDutyDays
              AND OverheadPercent = @OverheadPercent
    )
    BEGIN
        /* Record exists--add/update the inventory */
        SELECT @SkillId = SkillId
        FROM webuser.PMCategorySkill
        WHERE CategoryId = @CategoryId
              AND PayPlan = @PayPlan
              AND CategoryGroupCode = @CategoryGroupCode
              AND CategorySubgroupCode = @CategorySubgroupCode
              AND CareerProgramNumber = @CareerProgramNumber
              AND LocationId = @LocationId
              AND LocationText = @LocationText
              AND STRL = @STRL
              AND GradeLevel = @GradeLevel
              AND DependentStatus = @DependentStatus
              AND NumberOfDependents = @NumberOfDependents
              AND ActiveDutyDays = @ActiveDutyDays
              AND OverheadPercent = @OverheadPercent;

        EXEC web.PMCategorySkillInventoryInsert @SkillId = @SkillId,
                                                @InventoryYear = @InventoryYearIndex,
                                                @InventoryAmount = @InventoryAmount;
    END;
    ELSE
    BEGIN
        INSERT INTO webuser.PMCategorySkill
        (
            [CategoryId],
            [Uic],
            [PayPlan],
            [CategoryGroupCode],
            [CategorySubgroupCode],
            [CareerProgramNumber],
            [LocationId],
            [LocationText],
            [STRL],
            [GradeLevel],
            [DependentStatus],
            [NumberOfDependents],
            [ActiveDutyDays],
            [OverheadPercent]
        )
        VALUES
        (@CategoryId, @UIC, @PayPlan, @CategoryGroupCode, @CategorySubgroupCode, @CareerProgramNumber, @LocationId,
         @LocationText, @STRL, @GradeLevel, @DependentStatus, @NumberOfDependents, @ActiveDutyDays, @OverheadPercent);
        SELECT @SkillId = SCOPE_IDENTITY();
        --TDA:  Inventory is static.  Use the given inventory value for each year for the project duration
        --MTOE: User chooses to sync the project year to the SACS.  Start with the project start year and use the corresponding inventory for the unit year
        --      Repeat for number of years in project duration
        --      If the project duration is longer than the SACS file has unit years, user must choose to use the OTOE year or the last unit year to fill remaining project year inventory
        --MTOE: User chooses to select a unit year (year or OTOE).  The corresponding inventory will be used for the duration of the project
        EXEC web.PMCategorySkillInventoryInsert @SkillId = @SkillId,
                                                @InventoryYear = @InventoryYearIndex,
                                                @InventoryAmount = @InventoryAmount;
    END;


END;