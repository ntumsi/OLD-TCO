-- =============================================
-- Author:		Name
-- Create date: 
-- Description:	
-- =============================================
CREATE FUNCTION [web].[PMValidateUnitRequirement]
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
RETURNS @ValidUnitRequirement TABLE
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

    IF @PayPlan = 'CCE'
        INSERT INTO @ValidUnitRequirement
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
        SELECT PayPlan,
               CategoryGroupCode,
               CategorySubgroupCode,
               CareerProgramNumber,
               LocationId,
               STRL,
               GradeLevel,
               DependentStatus,
               NumberOfDependents
        FROM web.PMValidateUnitRequirementCCE(
                                                 @PayPlan,
                                                 @CategoryGroupCode,
                                                 @CategorySubgroupCode,
                                                 @CareerProgramNumber,
                                                 @LocationId,
                                                 @Strl,
                                                 @GradeLevel,
                                                 @DependentStatus,
                                                 @NumberOfDependents,
                                                 @AmcosVersionId
                                             );
    ELSE
        INSERT INTO @ValidUnitRequirement
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
        SELECT PayPlan,
               CategoryGroupCode,
               CategorySubgroupCode,
               CareerProgramNumber,
               LocationId,
               STRL,
               GradeLevel,
               DependentStatus,
               NumberOfDependents
        FROM web.PMValidateUnitRequirementNonCCE(
                                                    @PayPlan,
                                                    @CategoryGroupCode,
                                                    @CategorySubgroupCode,
                                                    @CareerProgramNumber,
                                                    @LocationId,
                                                    @Strl,
                                                    @GradeLevel,
                                                    @DependentStatus,
                                                    @NumberOfDependents,
                                                    @AmcosVersionId
                                                );

    RETURN;
END;