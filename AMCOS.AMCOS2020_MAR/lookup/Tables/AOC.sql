CREATE TABLE [lookup].[AOC] (
    [AOC]                 NVARCHAR (3)   NOT NULL,
    [Description]         NVARCHAR (250) NOT NULL,
    [AmcosVersionIdStart] INT            NULL,
    [AmcosVersionIdEnd]   INT            NOT NULL,
    CONSTRAINT [PK_AOC] PRIMARY KEY CLUSTERED ([AOC] ASC, [AmcosVersionIdEnd] ASC),
    CONSTRAINT [FK_AOC_AOC] FOREIGN KEY ([AOC], [AmcosVersionIdEnd]) REFERENCES [lookup].[AOC] ([AOC], [AmcosVersionIdEnd])
);



