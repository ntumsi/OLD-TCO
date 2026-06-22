CREATE TABLE [lookup].[GS_OccupationalSeries] (
    [OccupationalSeriesNumber] NVARCHAR (5)   NOT NULL,
    [SeriesTitle]              NVARCHAR (250) NOT NULL,
    [WorkRoleCodeRequired]     BIT            NULL,
    [AmcosVersionIdStart]      INT            NULL,
    [AmcosVersionIdEnd]        INT            NOT NULL,
    CONSTRAINT [PK_GS_OccupationalSeries] PRIMARY KEY CLUSTERED ([OccupationalSeriesNumber] ASC, [AmcosVersionIdEnd] ASC)
);









