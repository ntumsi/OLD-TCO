CREATE TABLE [dataload].[OccupationalEmploymentStatisticsMetro] (
    [SOC]       NVARCHAR (7)   NOT NULL,
    [AreaCode]  NVARCHAR (7)   NOT NULL,
    [TOT_EMP]   INT            NOT NULL,
    [EMP_PRSE]  NUMERIC (5, 2) NOT NULL,
    [A_MEAN]    NUMERIC (18)   NOT NULL,
    [MEAN_PRSE] NUMERIC (5, 2) NOT NULL,
    [A_PCT10]   NUMERIC (18)   NOT NULL,
    [A_PCT25]   NUMERIC (18)   NOT NULL,
    [A_MEDIAN]  NUMERIC (18)   NOT NULL,
    [A_PCT75]   NUMERIC (18)   NOT NULL,
    [A_PCT90]   NUMERIC (18)   NOT NULL,
    CONSTRAINT [PK_OccupationalEmploymentStatisticsMetro_1] PRIMARY KEY CLUSTERED ([SOC] ASC, [AreaCode] ASC)
);


GO
CREATE NONCLUSTERED INDEX [IX_PLMMetroArea_SOC]
    ON [dataload].[OccupationalEmploymentStatisticsMetro]([SOC] ASC);

