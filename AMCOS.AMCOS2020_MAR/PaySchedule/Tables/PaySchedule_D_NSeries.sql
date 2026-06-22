CREATE TABLE [PaySchedule].[PaySchedule_D_NSeries] (
    [PayPlan]        NVARCHAR (3)    NOT NULL,
    [Strl]           NVARCHAR (20)   NOT NULL,
    [GradeType]      NVARCHAR (3)    NOT NULL,
    [PayBand]        TINYINT         NOT NULL,
    [MinPay]         NUMERIC (18, 2) NOT NULL,
    [MaxPay]         NUMERIC (18, 2) NOT NULL,
    [LocationId]     INT             NOT NULL,
    [AmcosVersionId] INT             NOT NULL,
    CONSTRAINT [PK_PaySchedule_D_NSeries_table] PRIMARY KEY CLUSTERED ([PayPlan] ASC, [Strl] ASC, [GradeType] ASC, [PayBand] ASC, [LocationId] ASC, [AmcosVersionId] ASC)
);

