CREATE TABLE [lookup].[GS_OccupationalSeries] (
    [OccupationalSeriesNumber] NVARCHAR (4)   NOT NULL,
    [SeriesTitle]              NVARCHAR (250) NOT NULL,
    CONSTRAINT [PK_GS_OccupationalSeries] PRIMARY KEY CLUSTERED ([OccupationalSeriesNumber] ASC)
);

