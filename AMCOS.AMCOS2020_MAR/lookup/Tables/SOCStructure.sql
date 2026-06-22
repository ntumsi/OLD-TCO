CREATE TABLE [lookup].[SOCStructure] (
    [OccupationCode]      NVARCHAR (7)    NOT NULL,
    [GroupLevel]          NVARCHAR (10)   NULL,
    [OccupationTitle]     NVARCHAR (255)  NULL,
    [Definition]          NVARCHAR (3000) NULL,
    [AmcosVersionIdStart] INT             NULL,
    [AmcosVersionIdEnd]   INT             NOT NULL,
    CONSTRAINT [PK_SOCStructure] PRIMARY KEY CLUSTERED ([OccupationCode] ASC, [AmcosVersionIdEnd] ASC)
);



