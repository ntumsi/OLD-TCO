CREATE TABLE [lookup].[CType] (
    [code]                INT            NOT NULL,
    [Description]         NVARCHAR (150) NOT NULL,
    [AmcosVersionIdStart] INT            NULL,
    [AmcosVersionIdEnd]   INT            NOT NULL,
    CONSTRAINT [PK_CType] PRIMARY KEY CLUSTERED ([code] ASC, [AmcosVersionIdEnd] ASC)
);

