CREATE TABLE [PaySchedule].[PaySchedule_NSeries_Xwalk] (
    [PayPlan]             NVARCHAR (3)    NOT NULL,
    [GradeType]           NVARCHAR (3)    NOT NULL,
    [PayBand]             TINYINT         NOT NULL,
    [Min_GS_GL]           NVARCHAR (3)    NOT NULL,
    [Max_GS_GL]           NVARCHAR (3)    NOT NULL,
    [Additional]          NUMERIC (18, 2) NULL,
    [DateEffective]       DATE            NOT NULL,
    [AmcosVersionIdStart] INT             NOT NULL,
    [AmcosVersionIdEnd]   INT             NOT NULL,
    CONSTRAINT [PK_PaySchedule_NSeries] PRIMARY KEY CLUSTERED ([PayPlan] ASC, [GradeType] ASC, [PayBand] ASC, [AmcosVersionIdEnd] ASC)
);

