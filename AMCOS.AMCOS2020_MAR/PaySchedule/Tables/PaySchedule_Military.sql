CREATE TABLE [PaySchedule].[PaySchedule_Military] (
    [PayPlan]        NVARCHAR (3)    NOT NULL,
    [GradeType]      NVARCHAR (3)    NOT NULL,
    [GradeLevel]     TINYINT         NOT NULL,
    [YOS]            TINYINT         NOT NULL,
    [DateEffective]  DATE            NOT NULL,
    [RateType]       NVARCHAR (25)   NULL,
    [Rate]           NUMERIC (18, 2) NOT NULL,
    [AmcosVersionId] INT             NOT NULL,
    CONSTRAINT [PK_PaySchedule_Military] PRIMARY KEY CLUSTERED ([PayPlan] ASC, [GradeType] ASC, [GradeLevel] ASC, [YOS] ASC, [DateEffective] ASC, [AmcosVersionId] ASC)
);

