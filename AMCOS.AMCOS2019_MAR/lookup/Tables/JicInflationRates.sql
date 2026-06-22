CREATE TABLE [lookup].[JicInflationRates] (
    [ConversionType] NVARCHAR (25)    NOT NULL,
    [Appropriation]  NVARCHAR (25)    NOT NULL,
    [Year]           SMALLINT         NOT NULL,
    [Amount]         NUMERIC (18, 15) NOT NULL,
    CONSTRAINT [PK_JicInflationRates] PRIMARY KEY CLUSTERED ([ConversionType] ASC, [Appropriation] ASC, [Year] ASC)
);





