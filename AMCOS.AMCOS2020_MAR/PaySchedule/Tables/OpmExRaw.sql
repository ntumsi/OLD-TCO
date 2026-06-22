CREATE TABLE [PaySchedule].[OpmExRaw] (
    [PayPlan]        NVARCHAR (3)    NOT NULL,
    [Level]          NVARCHAR (15)   NOT NULL,
    [DateEffective]  DATE            NOT NULL,
    [RateType]       NVARCHAR (25)   NOT NULL,
    [Rate]           NUMERIC (10, 2) NULL,
    [AmcosVersionId] INT             NOT NULL,
    CONSTRAINT [PK_PaySchedule_EX_Series_raw] PRIMARY KEY CLUSTERED ([PayPlan] ASC, [Level] ASC, [RateType] ASC, [AmcosVersionId] ASC)
);

