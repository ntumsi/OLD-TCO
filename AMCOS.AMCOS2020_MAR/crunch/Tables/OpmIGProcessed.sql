CREATE TABLE [crunch].[OpmIGProcessed] (
    [PayPlan]        NVARCHAR (3)    NOT NULL,
    [GradeLevel]     TINYINT         NOT NULL,
    [RateType]       NVARCHAR (25)   NOT NULL,
    [Rate]           NUMERIC (10, 2) NULL,
    [AmcosVersionId] INT             NOT NULL,
    CONSTRAINT [PK_PaySchedule_IG_Series_processed] PRIMARY KEY CLUSTERED ([PayPlan] ASC, [GradeLevel] ASC, [RateType] ASC, [AmcosVersionId] ASC)
);

