

CREATE PROC [web].[ProjectRequirementInsertTda]
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
    @InventoryAmount INT
AS
BEGIN
    DECLARE @YearIndex INT = 0;
    DECLARE @ProjectYearDuration INT = web.GetProjectYearDuration(@CategoryId);

    WHILE @YearIndex < @ProjectYearDuration
    BEGIN
        EXEC web.PMCategorySkillInsert @CategoryId = @CategoryId,
                                       @UIC = @UIC,
                                       @PayPlan = @PayPlan,
                                       @CategoryGroupCode = @CategoryGroupCode,
                                       @CategorySubgroupCode = @CategorySubgroupCode,
                                       @CareerProgramNumber = @CareerProgramNumber,
                                       @LocationId = @LocationId,
                                       @LocationText = @LocationText,
                                       @STRL = @STRL,
                                       @GradeLevel = @GradeLevel,
                                       @DependentStatus = @DependentStatus,
                                       @NumberOfDependents = @NumberOfDependents,
                                       @ActiveDutyDays = @ActiveDutyDays,
                                       @OverheadPercent = @OverheadPercent,
                                       @InventoryYearIndex = @YearIndex,
                                       @InventoryAmount = @InventoryAmount;
        SET @YearIndex = @YearIndex + 1;
    END;
END;