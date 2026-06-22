CREATE TABLE [lookup].[LocalityPayArea_FIPS] (
    [FIPSCode]   NVARCHAR (10)  NOT NULL,
    [PayArea]    NVARCHAR (100) NOT NULL,
    [PlaceName]  NVARCHAR (150) NOT NULL,
    [LocalityID] INT            NOT NULL,
    CONSTRAINT [PK_LocalityPayArea_FIPS] PRIMARY KEY CLUSTERED ([FIPSCode] ASC)
);


GO
CREATE NONCLUSTERED INDEX [IDX_LocalityPayArea_FIPS]
    ON [lookup].[LocalityPayArea_FIPS]([FIPSCode] ASC)
    INCLUDE([PayArea], [LocalityID]);

