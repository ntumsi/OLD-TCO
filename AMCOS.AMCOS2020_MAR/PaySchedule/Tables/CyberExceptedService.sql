CREATE TABLE [PaySchedule].[CyberExceptedService] (
    [GradeLevel]     TINYINT         NOT NULL,
    [Step]           INT             NOT NULL,
    [RateType]       NVARCHAR (50)   NOT NULL,
    [Rate]           NUMERIC (10, 2) NOT NULL,
    [WorkRoleCode]   NVARCHAR (3)    NOT NULL,
    [TLMSPayTable]   NVARCHAR (2)    NOT NULL,
    [AmcosVersionId] INT             NOT NULL,
    CONSTRAINT [PK_CyberExceptedService] PRIMARY KEY CLUSTERED ([GradeLevel] ASC, [Step] ASC, [WorkRoleCode] ASC, [TLMSPayTable] ASC, [AmcosVersionId] ASC)
);



