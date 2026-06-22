CREATE TABLE [BLS_OES].[OccupationalEmploymentStatisticsMetro] (
    [SOC]            NVARCHAR (7)   NOT NULL,
    [MSACode]        NCHAR (7)      NOT NULL,
    [TOT_EMP]        INT            NOT NULL,
    [EMP_PRSE]       NUMERIC (5, 2) NOT NULL,
    [A_MEAN]         NUMERIC (18)   NOT NULL,
    [MEAN_PRSE]      NUMERIC (5, 2) NOT NULL,
    [A_PCT10]        NUMERIC (18)   NOT NULL,
    [A_PCT25]        NUMERIC (18)   NOT NULL,
    [A_MEDIAN]       NUMERIC (18)   NOT NULL,
    [A_PCT75]        NUMERIC (18)   NOT NULL,
    [A_PCT90]        NUMERIC (18)   NOT NULL,
    [AmcosVersionId] INT            NOT NULL,
    CONSTRAINT [PK_OccupationalEmploymentStatisticsMetro] PRIMARY KEY CLUSTERED ([SOC] ASC, [MSACode] ASC, [AmcosVersionId] ASC)
);




GO
CREATE NONCLUSTERED INDEX [IX_PLMMetroArea_SOC]
    ON [BLS_OES].[OccupationalEmploymentStatisticsMetro]([SOC] ASC);

