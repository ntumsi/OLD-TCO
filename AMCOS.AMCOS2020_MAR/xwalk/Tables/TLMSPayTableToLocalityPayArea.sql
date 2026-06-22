CREATE TABLE [xwalk].[TLMSPayTableToLocalityPayArea] (
    [TLMSPayTable]   NVARCHAR (2) NOT NULL,
    [LocalityCode]   NVARCHAR (6) NOT NULL,
    [AmcosVersionId] INT          NOT NULL,
    CONSTRAINT [PK_TLMSPayTableToLocalityPayArea] PRIMARY KEY CLUSTERED ([TLMSPayTable] ASC, [LocalityCode] ASC, [AmcosVersionId] ASC)
);

