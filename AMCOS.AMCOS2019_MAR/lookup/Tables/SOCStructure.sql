CREATE TABLE [lookup].[SOCStructure] (
    [OccupationCode]  NVARCHAR (7)    NOT NULL,
    [GroupLevel]      NVARCHAR (10)   NULL,
    [OccupationTitle] NVARCHAR (255)  NULL,
    [Definition]      NVARCHAR (3000) NULL,
    CONSTRAINT [PK_SOCStructure] PRIMARY KEY CLUSTERED ([OccupationCode] ASC)
);

