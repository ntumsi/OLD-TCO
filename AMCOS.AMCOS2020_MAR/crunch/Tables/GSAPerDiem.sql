CREATE TABLE [crunch].[GSAPerDiem] (
    [ZipCode]                        NVARCHAR (5) NOT NULL,
    [FiscalYear]                     SMALLINT     NOT NULL,
    [MaximumLodgingRate]             INT          NOT NULL,
    [MaximumMealsAndIncidentalsRate] INT          NOT NULL,
    [DateEffective]                  DATETIME     NOT NULL,
    [AmcosVersionId]                 INT          NOT NULL,
    CONSTRAINT [PK_ZipCode_AMCOSVersionID] PRIMARY KEY CLUSTERED ([ZipCode] ASC, [AmcosVersionId] ASC)
);

