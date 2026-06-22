
CREATE PROCEDURE [web].[PMCopyProjectCategory]
(
    @FromCategoryId INT,
    @ToCategoryId INT
)
AS
BEGIN

    DECLARE @SkillId INT;
    DECLARE @NewPMCategorySkillId INT;
    DECLARE @PayPlan VARCHAR(5);
    DECLARE @CategoryGroupCode VARCHAR(10);
    DECLARE @CategorySubgroupCode VARCHAR(10);
    DECLARE @CareerProgramNumber NCHAR(2);
    DECLARE @LocationId INT;
    DECLARE @LocationText NVARCHAR(150);
    DECLARE @STRL NVARCHAR(20);
    DECLARE @GradeLevel TINYINT;
    DECLARE @DependentStatus NVARCHAR(25);
    DECLARE @NumberOfDependents INT;
    DECLARE @ActiveDutyDays INT;
    DECLARE @OverheadPercent FLOAT;

    DECLARE cSkills CURSOR LOCAL READ_ONLY FOR WITH CategoryFrom
                                               AS (
                                                  SELECT SkillId,
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
                                                  WHERE CategoryId = @FromCategoryId),
                                                    CategoryTo
                                               AS (SELECT SkillId,
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
                                                   WHERE CategoryId = @ToCategoryId)
    SELECT CategoryFrom.SkillId,
           CategoryFrom.PayPlan,
           CategoryFrom.CategoryGroupCode,
           CategoryFrom.CategorySubgroupCode,
           CategoryFrom.CareerProgramNumber,
           CategoryFrom.LocationId,
           CategoryFrom.LocationText,
           CategoryFrom.STRL,
           CategoryFrom.GradeLevel,
           CategoryFrom.DependentStatus,
           CategoryFrom.NumberOfDependents,
           CategoryFrom.ActiveDutyDays,
           CategoryFrom.OverheadPercent
    FROM CategoryFrom
        LEFT JOIN CategoryTo
            ON CategoryFrom.PayPlan = CategoryTo.PayPlan
               AND CategoryFrom.CategoryGroupCode = CategoryTo.CategoryGroupCode
               AND CategoryFrom.CategorySubgroupCode = CategoryTo.CategorySubgroupCode
               AND CategoryFrom.CareerProgramNumber = CategoryTo.CareerProgramNumber
               AND CategoryFrom.LocationId = CategoryTo.LocationId
               AND CategoryTo.LocationText = CategoryFrom.LocationText
               AND CategoryFrom.STRL = CategoryTo.STRL
               AND CategoryFrom.GradeLevel = CategoryTo.GradeLevel
               AND CategoryFrom.DependentStatus = CategoryTo.DependentStatus
               AND CategoryTo.NumberOfDependents = CategoryFrom.NumberOfDependents
               AND ISNULL(CategoryFrom.ActiveDutyDays, 0) = ISNULL(CategoryTo.ActiveDutyDays, 0)
               AND ISNULL(CategoryFrom.OverheadPercent, 0) = ISNULL(CategoryTo.OverheadPercent, 0)
    WHERE CategoryTo.SkillId IS NULL;
    OPEN cSkills;

    FETCH cSkills
    INTO @SkillId,
         @PayPlan,
         @CategoryGroupCode,
         @CategorySubgroupCode,
         @CareerProgramNumber,
         @LocationId,
         @LocationText,
         @STRL,
         @GradeLevel,
         @DependentStatus,
         @NumberOfDependents,
         @ActiveDutyDays,
         @OverheadPercent;

    WHILE @@FETCH_STATUS = 0
    BEGIN
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
            VALUES
            (@ToCategoryId, @PayPlan, @CategoryGroupCode, @CategorySubgroupCode, @CareerProgramNumber, @LocationId,
             @LocationText, @STRL, @GradeLevel, @DependentStatus, @NumberOfDependents, @ActiveDutyDays,
             @OverheadPercent);

            SELECT @NewPMCategorySkillId = IDENT_CURRENT('webuser.PMCategorySkill');

            INSERT INTO webuser.PMCategorySkillInventory
            (
                SkillId,
                [Year],
                Amount
            )
            SELECT @NewPMCategorySkillId,
                   [Year],
                   Amount
            FROM webuser.PMCategorySkillInventory
            WHERE SkillId = @SkillId;
        END;

        FETCH cSkills
        INTO @SkillId,
             @PayPlan,
             @CategoryGroupCode,
             @CategorySubgroupCode,
             @CareerProgramNumber,
             @LocationId,
             @LocationText,
             @STRL,
             @GradeLevel,
             @DependentStatus,
             @NumberOfDependents,
             @ActiveDutyDays,
             @OverheadPercent;
    END;

    CLOSE cSkills;
    DEALLOCATE cSkills;
END;