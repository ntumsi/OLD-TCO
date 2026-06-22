CREATE TABLE [PaySchedule].[OpmSpecialRates] (
    [PayPlan]                NVARCHAR (3)   NOT NULL,
    [SpecialRateTableNumber] NVARCHAR (4)   NOT NULL,
    [GradeType]              NVARCHAR (3)   NOT NULL,
    [GradeLevel]             TINYINT        NOT NULL,
    [Step]                   TINYINT        NOT NULL,
    [DateEffective]          DATETIME       NOT NULL,
    [RateType]               NVARCHAR (25)  NULL,
    [Rate]                   NUMERIC (8, 2) NULL,
    [AmcosVersionId]         INT            NOT NULL,
    CONSTRAINT [PK_OpmSpecialRates] PRIMARY KEY CLUSTERED ([PayPlan] ASC, [SpecialRateTableNumber] ASC, [GradeType] ASC, [GradeLevel] ASC, [Step] ASC, [DateEffective] ASC, [AmcosVersionId] ASC)
);

