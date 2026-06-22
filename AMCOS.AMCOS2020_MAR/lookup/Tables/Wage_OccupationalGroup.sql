CREATE TABLE [lookup].[Wage_OccupationalGroup] (
    [OccupationalGroupNumber] NVARCHAR (4)   NOT NULL,
    [GroupTitle]              NVARCHAR (100) NOT NULL,
    [AmcosVersionIdStart]     INT            NOT NULL,
    [AmcosVersionIdEnd]       INT            NOT NULL,
    CONSTRAINT [PK_Wage_OccupationalGroup] PRIMARY KEY CLUSTERED ([OccupationalGroupNumber] ASC, [AmcosVersionIdStart] ASC, [AmcosVersionIdEnd] ASC)
);



