CREATE TABLE [DMDC].[MembersAndDependents] (
    [AmcosVersionId]           INT          NOT NULL,
    [PayPlan]                  NVARCHAR (3) NOT NULL,
    [GradeType]                NVARCHAR (3) NOT NULL,
    [GradeLevel]               TINYINT      NOT NULL,
    [TotalMembers]             INT          NULL,
    [MembersWithDependents]    INT          NULL,
    [MembersWithoutDependents] INT          NULL,
    [NumberOfDependents]       INT          NULL,
    CONSTRAINT [PK_MembersAndDependents] PRIMARY KEY CLUSTERED ([AmcosVersionId] ASC, [PayPlan] ASC, [GradeType] ASC, [GradeLevel] ASC)
);

