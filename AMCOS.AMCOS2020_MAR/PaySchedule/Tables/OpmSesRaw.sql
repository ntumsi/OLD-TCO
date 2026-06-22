CREATE TABLE [PaySchedule].[OpmSesRaw] (
    [PayPlan]        NVARCHAR (3)   NOT NULL,
    [DateEffective]  DATE           NOT NULL,
    [RateType]       NVARCHAR (25)  NOT NULL,
    [MaxPay]         NUMERIC (8, 2) NOT NULL,
    [MinPay]         NUMERIC (8, 2) NOT NULL,
    [AmcosVersionId] INT            NOT NULL,
    CONSTRAINT [PK_PaySchedule_SES_raw] PRIMARY KEY CLUSTERED ([PayPlan] ASC, [RateType] ASC, [AmcosVersionId] ASC)
);

