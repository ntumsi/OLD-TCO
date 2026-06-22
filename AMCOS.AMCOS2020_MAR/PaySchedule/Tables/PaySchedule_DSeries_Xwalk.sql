CREATE TABLE [PaySchedule].[PaySchedule_DSeries_Xwalk] (
    [PayPlan]             NVARCHAR (3)    NOT NULL,
    [Strl]                NVARCHAR (20)   NOT NULL,
    [GradeType]           NVARCHAR (3)    NOT NULL,
    [PayBand]             TINYINT         NOT NULL,
    [Min_GS_GL]           NVARCHAR (3)    NOT NULL,
    [Max_GS_GL]           NVARCHAR (3)    NOT NULL,
    [Additional]          NUMERIC (18, 2) NULL,
    [DateEffective]       DATE            NOT NULL,
    [AmcosVersionIdStart] INT             NOT NULL,
    [AmcosVersionIdEnd]   INT             NOT NULL,
    CONSTRAINT [PK_PaySchedule_DSeries] PRIMARY KEY CLUSTERED ([PayPlan] ASC, [Strl] ASC, [GradeType] ASC, [PayBand] ASC, [AmcosVersionIdEnd] ASC)
);

