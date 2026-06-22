CREATE TABLE [lookup].[LocalityPayArea] (
    [LocalityCode]    NVARCHAR (6)   NOT NULL,
    [LocalityPayArea] NVARCHAR (100) NOT NULL,
    [AmcosVersionId]  INT            NOT NULL,
    CONSTRAINT [PK_LocalityPayArea_1] PRIMARY KEY CLUSTERED ([LocalityCode] ASC, [AmcosVersionId] ASC)
);

