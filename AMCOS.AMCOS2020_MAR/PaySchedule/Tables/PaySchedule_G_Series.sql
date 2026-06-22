CREATE TABLE [PaySchedule].[PaySchedule_G_Series] (
    [PayPlan]              NVARCHAR (3)    NOT NULL,
    [CategoryGroupCode]    NVARCHAR (4)    NOT NULL,
    [CategorySubgroupCode] NVARCHAR (5)    NOT NULL,
    [WorkRoleCode]         NVARCHAR (3)    CONSTRAINT [DF__PaySchedu__Cyber__33C13DAD] DEFAULT ('-1') NOT NULL,
    [LocationId]           INT             NOT NULL,
    [GradeType]            NVARCHAR (3)    NOT NULL,
    [GradeLevel]           TINYINT         NOT NULL,
    [Step]                 TINYINT         NOT NULL,
    [Rate]                 NUMERIC (10, 2) NOT NULL,
    [AmcosVersionId]       INT             NOT NULL,
    CONSTRAINT [PK_PaySchedule_G_Series] PRIMARY KEY CLUSTERED ([PayPlan] ASC, [CategoryGroupCode] ASC, [CategorySubgroupCode] ASC, [WorkRoleCode] ASC, [LocationId] ASC, [GradeType] ASC, [GradeLevel] ASC, [Step] ASC, [AmcosVersionId] ASC)
);



