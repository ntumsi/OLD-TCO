CREATE TABLE [lookup].[MOS] (
    [MOS]                 NVARCHAR (3)   NOT NULL,
    [Description]         NVARCHAR (250) NULL,
    [Parent_MOS]          NVARCHAR (3)   NULL,
    [AmcosVersionIdStart] INT            NULL,
    [AmcosVersionIdEnd]   INT            NOT NULL,
    CONSTRAINT [PK_MOS] PRIMARY KEY CLUSTERED ([MOS] ASC, [AmcosVersionIdEnd] ASC)
);









