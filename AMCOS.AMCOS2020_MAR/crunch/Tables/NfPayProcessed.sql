CREATE TABLE [crunch].[NfPayProcessed] (
    [PayPlan]        NVARCHAR (3)    NOT NULL,
    [GradeType]      NVARCHAR (3)    NOT NULL,
    [PayBand]        TINYINT         NOT NULL,
    [MinPay]         NUMERIC (18, 2) NOT NULL,
    [MaxPay]         NUMERIC (18, 2) NOT NULL,
    [LocationId]     INT             NOT NULL,
    [AmcosVersionId] INT             NOT NULL,
    CONSTRAINT [PK_PayScheduleNF] PRIMARY KEY CLUSTERED ([PayPlan] ASC, [GradeType] ASC, [PayBand] ASC, [LocationId] ASC, [AmcosVersionId] ASC)
);

