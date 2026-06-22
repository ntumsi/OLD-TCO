CREATE TABLE [lookup].[Wage_OccupationalSeries] (
    [OccupationalSeriesNumber] NVARCHAR (4)   NOT NULL,
    [SeriesTitle]              NVARCHAR (100) NOT NULL,
    [AmcosVersionIdStart]      INT            NOT NULL,
    [AmcosVersionIdEnd]        INT            NOT NULL,
    CONSTRAINT [PK_Wage_OccupationalSeries_1] PRIMARY KEY CLUSTERED ([OccupationalSeriesNumber] ASC, [AmcosVersionIdStart] ASC, [AmcosVersionIdEnd] ASC)
);



