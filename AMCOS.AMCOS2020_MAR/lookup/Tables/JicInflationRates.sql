CREATE TABLE [lookup].[JicInflationRates] (
    [ConversionType] NVARCHAR (25)    NOT NULL,
    [Year]           SMALLINT         NOT NULL,
    [Appropriation]  NVARCHAR (25)    NOT NULL,
    [Amount]         NUMERIC (18, 15) NOT NULL,
    [AmcosVersionId] INT              NOT NULL,
    CONSTRAINT [PK_JicInflationRates] PRIMARY KEY CLUSTERED ([ConversionType] ASC, [Year] ASC, [Appropriation] ASC, [AmcosVersionId] ASC)
);







