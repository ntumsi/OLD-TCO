CREATE TABLE [xwalk].[SpecialRateTablesByOccupation] (
    [OccupationalSeriesNumber] NVARCHAR (4)   NOT NULL,
    [SeriesTitle]              NVARCHAR (100) NOT NULL,
    [TableNumber]              NVARCHAR (4)   NOT NULL,
    [AmcosVersionId]           INT            NOT NULL,
    CONSTRAINT [PK_SpecialRateTablesByOccupation] PRIMARY KEY CLUSTERED ([OccupationalSeriesNumber] ASC, [SeriesTitle] ASC, [TableNumber] ASC, [AmcosVersionId] ASC)
);



