CREATE TABLE [lookup].[MilitarySOC] (
    [Code]                NVARCHAR (1)   NOT NULL,
    [Description]         NVARCHAR (255) NULL,
    [AmcosVersionIdStart] INT            NULL,
    [AmcosVersionIdEnd]   INT            NOT NULL,
    CONSTRAINT [PK_MilitarySOC] PRIMARY KEY CLUSTERED ([Code] ASC, [AmcosVersionIdEnd] ASC)
);





