CREATE TABLE [PaySchedule].[PaySchedule_G_Series_raw] (
    [PayPlan]        NVARCHAR (3)    NOT NULL,
    [GradeType]      NVARCHAR (3)    NOT NULL,
    [GradeLevel]     TINYINT         NOT NULL,
    [Step]           TINYINT         NOT NULL,
    [DateEffective]  DATE            NOT NULL,
    [RateType]       NVARCHAR (25)   NOT NULL,
    [Rate]           NUMERIC (10, 2) NULL,
    [AmcosVersionId] INT             NOT NULL,
    CONSTRAINT [PK_PaySchedule_G_Series_raw] PRIMARY KEY CLUSTERED ([PayPlan] ASC, [GradeType] ASC, [GradeLevel] ASC, [Step] ASC, [RateType] ASC, [AmcosVersionId] ASC)
);



