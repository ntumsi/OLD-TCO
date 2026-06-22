CREATE TABLE [PaySchedule].[PaySchedule_CY_Xwalk] (
    [PayPlan]             NVARCHAR (3) NOT NULL,
    [GradeType]           NVARCHAR (3) NOT NULL,
    [PayBand]             TINYINT      NOT NULL,
    [Min_GS_GL]           NVARCHAR (3) NOT NULL,
    [Max_GS_GL]           NVARCHAR (3) NOT NULL,
    [AmcosVersionIdStart] INT          NOT NULL,
    [AmcosVersionIdEnd]   INT          NOT NULL,
    CONSTRAINT [PaySchedule_CY_XwalkPK] PRIMARY KEY CLUSTERED ([PayPlan] ASC, [GradeType] ASC, [PayBand] ASC, [AmcosVersionIdEnd] ASC)
);

