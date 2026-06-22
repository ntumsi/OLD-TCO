CREATE TABLE [lookup].[OPM_SpecialRate] (
    [SpecialRateTableNumber]   NVARCHAR (4)   NOT NULL,
    [OccupationalSeriesNumber] NVARCHAR (4)   NOT NULL,
    [LocalityId]               INT            NOT NULL,
    [OccupationName]           NVARCHAR (100) NULL,
    CONSTRAINT [PK_OPM_SpecialRate] PRIMARY KEY CLUSTERED ([SpecialRateTableNumber] ASC, [OccupationalSeriesNumber] ASC, [LocalityId] ASC),
    CONSTRAINT [FK_OPM_SpecialRate_LocalityRates] FOREIGN KEY ([LocalityId]) REFERENCES [lookup].[LocalityRates] ([Id])
);

