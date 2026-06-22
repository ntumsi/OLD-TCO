CREATE TABLE [xwalk].[SeriestoSOC] (
    [SOC]                 NVARCHAR (7) NOT NULL,
    [Series]              NVARCHAR (5) NOT NULL,
    [AmcosVersionIdStart] INT          NOT NULL,
    [AmcosVersionIdEnd]   INT          NOT NULL,
    CONSTRAINT [PK_OccupationalEmploymentStatisticsMetro] PRIMARY KEY CLUSTERED ([SOC] ASC, [Series] ASC, [AmcosVersionIdEnd] ASC)
);

