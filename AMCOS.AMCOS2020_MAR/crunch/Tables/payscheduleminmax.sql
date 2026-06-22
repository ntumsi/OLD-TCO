CREATE TABLE [crunch].[PayScheduleMinMax] (
    [PayPlan]              NVARCHAR (3)    NOT NULL,
    [CategoryGroupCode]    NVARCHAR (4)    NOT NULL,
    [CategorySubgroupCode] NVARCHAR (5)    NOT NULL,
    [CareerProgramNumber]  NCHAR (2)       NOT NULL,
    [LocationId]           INT             NOT NULL,
    [STRL]                 NVARCHAR (20)   NOT NULL,
    [GradeType]            NVARCHAR (3)    NOT NULL,
    [GradeLevel]           TINYINT         NOT NULL,
    [MinRate]              NUMERIC (18, 2) NOT NULL,
    [MaxRate]              NUMERIC (18, 2) NOT NULL,
    [AmcosVersionId]       INT             NOT NULL,
    [Appropriation]        NVARCHAR (25)   DEFAULT ('-1') NOT NULL,
    CONSTRAINT [PK_PayScheduleMinMax] PRIMARY KEY CLUSTERED ([PayPlan] ASC, [CategoryGroupCode] ASC, [CategorySubgroupCode] ASC, [CareerProgramNumber] ASC, [LocationId] ASC, [STRL] ASC, [GradeType] ASC, [GradeLevel] ASC, [AmcosVersionId] ASC)
);





