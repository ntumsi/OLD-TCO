
-- =============================================
-- Author:		Name
-- Create date: 
-- Description:	
-- =============================================
CREATE FUNCTION [web].[PMValidateUnitRequirementCCE]
(
    @PayPlan NVARCHAR(3),
    @CategoryGroupCode NVARCHAR(10),
    @CategorySubgroupCode NVARCHAR(10),
    @CareerProgramNumber NCHAR(2),
    @LocationId INT,
    @Strl NVARCHAR(20),
    @GradeLevel TINYINT,
    @DependentStatus NVARCHAR(25),
    @NumberOfDependents INT,
    @AmcosVersionId INT
)
RETURNS @ValidUnitRequirementCCE TABLE
(
    [PayPlan] [NVARCHAR](3) NOT NULL,
    [CategoryGroupCode] [NVARCHAR](10) NOT NULL,
    [CategorySubgroupCode] [NVARCHAR](10) NOT NULL,
    [CareerProgramNumber] [NCHAR](2) NOT NULL,
    [LocationId] [INT] NOT NULL,
    [STRL] [NVARCHAR](20) NOT NULL,
    [GradeLevel] [TINYINT] NOT NULL,
    [DependentStatus] [NVARCHAR](25) NOT NULL,
    [NumberOfDependents] [INT] NOT NULL
)
AS
BEGIN

    IF EXISTS
    (
        SELECT *
        FROM data.Costs
        WHERE PayPlan = @PayPlan
              AND CategoryGroupCode = @CategoryGroupCode
              AND CategorySubgroupCode = @CategorySubgroupCode
              AND CareerProgramNumber = @CareerProgramNumber
              AND LocationId = @LocationId
              AND Strl = @Strl
              AND GradeLevel = @GradeLevel
              AND DependentStatus = @DependentStatus
              AND NumberOfDependents = @NumberOfDependents
              AND AmcosVersionId = @AmcosVersionId
    )
        INSERT INTO @ValidUnitRequirementCCE
        (
            [PayPlan],
            [CategoryGroupCode],
            [CategorySubgroupCode],
            [CareerProgramNumber],
            [LocationId],
            [STRL],
            [GradeLevel],
            [DependentStatus],
            [NumberOfDependents]
        )
        SELECT @PayPlan,
               @CategoryGroupCode,
               @CategorySubgroupCode,
               @CareerProgramNumber,
               @LocationId,
               @Strl,
               @GradeLevel,
               @DependentStatus,
               @NumberOfDependents;
    ELSE IF EXISTS
    (
        /* Location Group average */
        SELECT *
        FROM data.Costs
        WHERE PayPlan = @PayPlan
              AND CategoryGroupCode = @CategoryGroupCode
              AND CategorySubgroupCode = '-1'
              AND CareerProgramNumber = @CareerProgramNumber
              AND LocationId = @LocationId
              AND Strl = @Strl
              AND GradeLevel = @GradeLevel
              AND DependentStatus = @DependentStatus
              AND NumberOfDependents = @NumberOfDependents
              AND AmcosVersionId = @AmcosVersionId
    )
        INSERT INTO @ValidUnitRequirementCCE
        (
            [PayPlan],
            [CategoryGroupCode],
            [CategorySubgroupCode],
            [CareerProgramNumber],
            [LocationId],
            [STRL],
            [GradeLevel],
            [DependentStatus],
            [NumberOfDependents]
        )
        SELECT @PayPlan,
               @CategoryGroupCode,
               '-1',
               @CareerProgramNumber,
               @LocationId,
               @Strl,
               @GradeLevel,
               @DependentStatus,
               @NumberOfDependents;
    ELSE IF EXISTS
    (
        /* Location Pay Plan average */
        SELECT *
        FROM data.Costs
        WHERE PayPlan = @PayPlan
              AND CategoryGroupCode = '-1'
              AND CategorySubgroupCode = '-1'
              AND CareerProgramNumber = @CareerProgramNumber
              AND LocationId = @LocationId
              AND Strl = @Strl
              AND GradeLevel = @GradeLevel
              AND DependentStatus = @DependentStatus
              AND NumberOfDependents = @NumberOfDependents
              AND AmcosVersionId = @AmcosVersionId
    )
        INSERT INTO @ValidUnitRequirementCCE
        (
            [PayPlan],
            [CategoryGroupCode],
            [CategorySubgroupCode],
            [CareerProgramNumber],
            [LocationId],
            [STRL],
            [GradeLevel],
            [DependentStatus],
            [NumberOfDependents]
        )
        SELECT @PayPlan,
               '-1',
               '-1',
               @CareerProgramNumber,
               @LocationId,
               @Strl,
               @GradeLevel,
               @DependentStatus,
               @NumberOfDependents;
    ELSE IF EXISTS
    (
        /* Location non-specific Subgroup average */
        SELECT *
        FROM data.Costs
        WHERE PayPlan = @PayPlan
              AND CategoryGroupCode = @CategoryGroupCode
              AND CategorySubgroupCode = @CategorySubgroupCode
              AND CareerProgramNumber = @CareerProgramNumber
              AND LocationId = -1
              AND Strl = @Strl
              AND GradeLevel = @GradeLevel
              AND DependentStatus = @DependentStatus
              AND NumberOfDependents = @NumberOfDependents
              AND AmcosVersionId = @AmcosVersionId
    )
        INSERT INTO @ValidUnitRequirementCCE
        (
            [PayPlan],
            [CategoryGroupCode],
            [CategorySubgroupCode],
            [CareerProgramNumber],
            [LocationId],
            [STRL],
            [GradeLevel],
            [DependentStatus],
            [NumberOfDependents]
        )
        SELECT @PayPlan,
               @CategoryGroupCode,
               @CategorySubgroupCode,
               @CareerProgramNumber,
               -1,
               @Strl,
               @GradeLevel,
               @DependentStatus,
               @NumberOfDependents;
    ELSE IF EXISTS
    (
        /* Location non-specific Group average */
        SELECT *
        FROM data.Costs
        WHERE PayPlan = @PayPlan
              AND CategoryGroupCode = @CategoryGroupCode
              AND CategorySubgroupCode = '-1'
              AND CareerProgramNumber = @CareerProgramNumber
              AND LocationId = -1
              AND Strl = @Strl
              AND GradeLevel = @GradeLevel
              AND DependentStatus = @DependentStatus
              AND NumberOfDependents = @NumberOfDependents
              AND AmcosVersionId = @AmcosVersionId
    )
        INSERT INTO @ValidUnitRequirementCCE
        (
            [PayPlan],
            [CategoryGroupCode],
            [CategorySubgroupCode],
            [CareerProgramNumber],
            [LocationId],
            [STRL],
            [GradeLevel],
            [DependentStatus],
            [NumberOfDependents]
        )
        SELECT @PayPlan,
               @CategoryGroupCode,
               '-1',
               @CareerProgramNumber,
               -1,
               @Strl,
               @GradeLevel,
               @DependentStatus,
               @NumberOfDependents;
    ELSE IF EXISTS
    (
        /* Location non-specific Pay Plan average */
        SELECT *
        FROM data.Costs
        WHERE PayPlan = @PayPlan
              AND CategoryGroupCode = '-1'
              AND CategorySubgroupCode = '-1'
              AND CareerProgramNumber = @CareerProgramNumber
              AND LocationId = -1
              AND Strl = @Strl
              AND GradeLevel = @GradeLevel
              AND DependentStatus = @DependentStatus
              AND NumberOfDependents = @NumberOfDependents
              AND AmcosVersionId = @AmcosVersionId
    )
        INSERT INTO @ValidUnitRequirementCCE
        (
            [PayPlan],
            [CategoryGroupCode],
            [CategorySubgroupCode],
            [CareerProgramNumber],
            [LocationId],
            [STRL],
            [GradeLevel],
            [DependentStatus],
            [NumberOfDependents]
        )
        SELECT @PayPlan,
               '-1',
               '-1',
               @CareerProgramNumber,
               -1,
               @Strl,
               @GradeLevel,
               @DependentStatus,
               @NumberOfDependents;
    ELSE
        /* No matches; Insert the personnel requirement as-is */
        INSERT INTO @ValidUnitRequirementCCE
        (
            [PayPlan],
            [CategoryGroupCode],
            [CategorySubgroupCode],
            [CareerProgramNumber],
            [LocationId],
            [STRL],
            [GradeLevel],
            [DependentStatus],
            [NumberOfDependents]
        )
        SELECT @PayPlan,
               @CategoryGroupCode,
               @CategorySubgroupCode,
               @CareerProgramNumber,
               @LocationId,
               @Strl,
               @GradeLevel,
               @DependentStatus,
               @NumberOfDependents;
    RETURN;
END;