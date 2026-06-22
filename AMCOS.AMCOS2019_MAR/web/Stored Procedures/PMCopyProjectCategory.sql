
CREATE PROCEDURE [web].[PMCopyProjectCategory]
(
    @ProjectId INT,
    @FromCategoryId INT,
    @ToCategoryId INT
)
AS
BEGIN

    DECLARE @SkillID INT;
    DECLARE @NewPMCategorySkillId INT;
    DECLARE @UserID VARCHAR(50);
    DECLARE @PayPlan VARCHAR(5);
    DECLARE @CategoryGroupCode VARCHAR(10);
    DECLARE @CategorySubGroupCode VARCHAR(10);
    DECLARE @GradeType NVARCHAR(3);
    DECLARE @GradeLevel TINYINT;
    DECLARE @Type NVARCHAR(5);
    DECLARE @AreaCode NVARCHAR(50);
    DECLARE @LocalityID INT;
    DECLARE @SpecialRateTableNumber NVARCHAR(4);
    DECLARE @StateCountry NVARCHAR(50);
    DECLARE @FunctionalAreaCode NVARCHAR(50);
    DECLARE @CostCenterCode NVARCHAR(50);
    DECLARE @activeDays INT;
    DECLARE @overheadPct FLOAT;

    DECLARE cSkills CURSOR LOCAL READ_ONLY FOR WITH CategoryFrom
                                               AS (
                                                  SELECT UserId,
                                                         ProjectId,
                                                         CategoryId,
                                                         SkillId,
                                                         PayPlan,
                                                         CategoryGroupCode,
                                                         CategorySubGroupCode,
                                                         GradeType,
                                                         GradeLevel,
                                                         Type,
                                                         AreaCode,
                                                         LocalityId,
                                                         SpecialRateTableNumber,
                                                         StateCountry,
                                                         FunctionalAreaCode,
                                                         CostCenterCode,
                                                         activeDays,
                                                         overheadPct
                                                  FROM webuser.PMCategorySkill
                                                  WHERE ProjectId = @ProjectId
                                                        AND CategoryId = @FromCategoryId),
                                                    CategoryTo
                                               AS (SELECT UserId,
                                                          ProjectId,
                                                          CategoryId,
                                                          SkillId,
                                                          PayPlan,
                                                          CategoryGroupCode,
                                                          CategorySubGroupCode,
                                                          GradeType,
                                                          GradeLevel,
                                                          Type,
                                                          AreaCode,
                                                          LocalityId,
                                                          SpecialRateTableNumber,
                                                          StateCountry,
                                                          FunctionalAreaCode,
                                                          CostCenterCode,
                                                          activeDays,
                                                          overheadPct
                                                   FROM webuser.PMCategorySkill
                                                   WHERE ProjectId = @ProjectId
                                                         AND CategoryId = @ToCategoryId)
    SELECT CategoryFrom.UserId,
           CategoryFrom.[SkillId],
           CategoryFrom.[PayPlan],
           CategoryFrom.[CategoryGroupCode],
           CategoryFrom.[CategorySubGroupCode],
           CategoryFrom.[GradeType],
           CategoryFrom.[GradeLevel],
           CategoryFrom.[Type],
           CategoryFrom.[AreaCode],
           CategoryFrom.[LocalityId],
           CategoryFrom.[SpecialRateTableNumber],
           CategoryFrom.[StateCountry],
           CategoryFrom.[FunctionalAreaCode],
           CategoryFrom.[CostCenterCode],
           CategoryFrom.[activeDays],
           CategoryFrom.[overheadPct]
    FROM CategoryFrom
        LEFT JOIN CategoryTo
            ON CategoryFrom.ProjectId = CategoryTo.ProjectId
               AND CategoryFrom.PayPlan = CategoryTo.PayPlan
               AND CategoryFrom.CategoryGroupCode = CategoryTo.CategoryGroupCode
               AND CategoryFrom.CategorySubGroupCode = CategoryTo.CategorySubGroupCode
               AND CategoryFrom.GradeType = CategoryTo.GradeType
               AND CategoryFrom.GradeLevel = CategoryTo.GradeLevel
               AND ISNULL(CategoryFrom.AreaCode, 0) = ISNULL(CategoryTo.AreaCode, 0)
               AND ISNULL(CategoryFrom.LocalityId, 0) = ISNULL(CategoryTo.LocalityId, 0)
               AND ISNULL(CategoryFrom.SpecialRateTableNumber, 0) = ISNULL(CategoryTo.SpecialRateTableNumber, 0)
               AND ISNULL(CategoryFrom.StateCountry, 0) = ISNULL(CategoryTo.StateCountry, 0)
               AND ISNULL(CategoryFrom.FunctionalAreaCode, 0) = ISNULL(CategoryTo.FunctionalAreaCode, 0)
               AND ISNULL(CategoryFrom.CostCenterCode, 0) = ISNULL(CategoryTo.CostCenterCode, 0)
               AND ISNULL(CategoryFrom.activeDays, 0) = ISNULL(CategoryTo.activeDays, 0)
               AND ISNULL(CategoryFrom.overheadPct, 0) = ISNULL(CategoryTo.overheadPct, 0)
    WHERE CategoryTo.ProjectId IS NULL;
    OPEN cSkills;

    FETCH cSkills
    INTO @UserID,
         @SkillID,
         @PayPlan,
         @CategoryGroupCode,
         @CategorySubGroupCode,
         @GradeType,
         @GradeLevel,
         @Type,
         @AreaCode,
         @LocalityID,
         @SpecialRateTableNumber,
         @StateCountry,
         @FunctionalAreaCode,
         @CostCenterCode,
         @activeDays,
         @overheadPct;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        BEGIN
            INSERT INTO webuser.PMCategorySkill
            (
                UserId,
                ProjectId,
                CategoryId,
                PayPlan,
                CategoryGroupCode,
                CategorySubGroupCode,
                GradeType,
                GradeLevel,
                Type,
                AreaCode,
                LocalityId,
                SpecialRateTableNumber,
                StateCountry,
                FunctionalAreaCode,
                CostCenterCode,
                activeDays,
                overheadPct
            )
            VALUES
            (@UserID, @ProjectId, @ToCategoryId, @PayPlan, @CategoryGroupCode, @CategorySubGroupCode, @GradeType,
             @GradeLevel, @Type, @AreaCode, @LocalityID, @SpecialRateTableNumber, @StateCountry, @FunctionalAreaCode,
             @CostCenterCode, @activeDays, @overheadPct);

            SELECT @NewPMCategorySkillId = IDENT_CURRENT('webuser.PMCategorySkill');

            INSERT INTO webuser.PMCategorySkillInventory
            (
                UserId,
                ProjectId,
                CategoryId,
                SkillId,
                [Year],
                Amount
            )
            SELECT @UserID,
                   @ProjectId,
                   @ToCategoryId,
                   @NewPMCategorySkillId,
                   [Year],
                   Amount
            FROM webuser.PMCategorySkillInventory
            WHERE ProjectId = @ProjectId
                  AND CategoryId = @FromCategoryId
                  AND SkillId = @SkillID;
        END;

        FETCH cSkills
        INTO @UserID,
             @SkillID,
             @PayPlan,
             @CategoryGroupCode,
             @CategorySubGroupCode,
             @GradeType,
             @GradeLevel,
             @Type,
             @AreaCode,
             @LocalityID,
             @SpecialRateTableNumber,
             @StateCountry,
             @FunctionalAreaCode,
             @CostCenterCode,
             @activeDays,
             @overheadPct;
    END;

    CLOSE cSkills;
    DEALLOCATE cSkills;

END;