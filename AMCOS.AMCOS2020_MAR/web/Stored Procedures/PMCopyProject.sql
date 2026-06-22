

CREATE PROCEDURE [web].[PMCopyProject]
(
    @ProjectId INT,
    @ProjectName VARCHAR(50),
    @Description TEXT
)
AS
BEGIN
    DECLARE @CategoryId INT;
    DECLARE @SkillId INT;
    DECLARE @NewProjectId INT;
    DECLARE @NewCategoryId INT;
    DECLARE @NewSkillId INT;
    DECLARE @oldProjectName VARCHAR(50);

    SELECT @oldProjectName = ProjectName
    FROM webuser.PMProject
    WHERE ProjectId = @ProjectId;

    /* PMProject */
    INSERT INTO webuser.PMProject
    (
        UserId,
        ProjectName,
        YearStart,
        YearDuration,
        ProjectCreator,
        ProjectType,
        ReserveDaysInActive,
        ReserveDaysActive,
        CreateDate,
        LastUpdate,
        Description,
        DiscountRate
    )
    SELECT UserId,
           @ProjectName,
           YearStart,
           YearDuration,
           ProjectCreator,
           ProjectType,
           ReserveDaysInActive,
           ReserveDaysActive,
           GETDATE(),
           GETDATE(),
           @Description,
           DiscountRate
    FROM webuser.PMProject
    WHERE ProjectId = @ProjectId;

    SELECT @NewProjectId = @@IDENTITY;

    /* PMCategory */
    DECLARE cCategory CURSOR FOR
    SELECT CategoryId
    FROM webuser.PMCategory
    WHERE ProjectId = @ProjectId
    ORDER BY CategoryId;

    OPEN cCategory;

    FETCH cCategory
    INTO @CategoryId;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        INSERT INTO webuser.PMCategory
        (
            ProjectId,
            CategoryName
        )
        SELECT @NewProjectId,
               (CASE
                    WHEN CategoryName = @oldProjectName THEN
                        @ProjectName
                    ELSE
                        CategoryName
                END
               )
        FROM webuser.PMCategory
        WHERE ProjectId = @ProjectId
              AND CategoryId = @CategoryId;

        SELECT @NewCategoryId = @@IDENTITY;

        DECLARE cSkills CURSOR FOR
        SELECT SkillId
        FROM webuser.PMCategorySkill
        WHERE CategoryId = @CategoryId
        ORDER BY SkillId;

        OPEN cSkills;

        FETCH cSkills
        INTO @SkillId;

        WHILE @@FETCH_STATUS = 0
        BEGIN
            INSERT INTO webuser.PMCategorySkill
            (
                CategoryId,
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
                OverheadPercent
            )
            SELECT @NewCategoryId,
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
                   OverheadPercent
            FROM webuser.PMCategorySkill
            WHERE CategoryId = @CategoryId
                  AND SkillId = @SkillId;

            SELECT @NewSkillId = @@IDENTITY;

            INSERT INTO webuser.PMCategorySkillInventory
            (
                SkillId,
                [Year],
                Amount
            )
            SELECT @NewSkillId,
                   [Year],
                   Amount
            FROM webuser.PMCategorySkillInventory
            WHERE SkillId = @SkillId;

            FETCH cSkills
            INTO @SkillId;
        END;

        CLOSE cSkills;
        DEALLOCATE cSkills;

        FETCH cCategory
        INTO @CategoryId;
    END;

    CLOSE cCategory;
    DEALLOCATE cCategory;

    RETURN;
END;