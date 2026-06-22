CREATE TABLE [data].[FmsWebSacsPersonnel] (
    [Id]       INT           IDENTITY (1, 1) NOT NULL,
    [RUNID]    INT           NULL,
    [UIC]      NVARCHAR (6)  NULL,
    [EDATEI]   INT           NULL,
    [RQBOI]    INT           NULL,
    [AUBOI]    INT           NULL,
    [SORCE]    INT           NULL,
    [MDUIC]    NVARCHAR (2)  NULL,
    [GRADE]    NVARCHAR (3)  NULL,
    [MOS]      NVARCHAR (5)  NULL,
    [RMKS1]    NVARCHAR (2)  NULL,
    [RMKS2]    NVARCHAR (2)  NULL,
    [RMKS3]    NVARCHAR (2)  NULL,
    [RMKS4]    NVARCHAR (2)  NULL,
    [AMSCO]    NVARCHAR (8)  NULL,
    [LIC]      NVARCHAR (2)  NULL,
    [ASI01]    NVARCHAR (2)  NULL,
    [ASI02]    NVARCHAR (2)  NULL,
    [ASI03]    NVARCHAR (2)  NULL,
    [ASI04]    NVARCHAR (2)  NULL,
    [SQI2D]    NVARCHAR (1)  NULL,
    [PSNTL]    NVARCHAR (22) NULL,
    [BRANCH]   NVARCHAR (2)  NULL,
    [IDENT]    NVARCHAR (1)  NULL,
    [PERS_CAT] NVARCHAR (1)  NULL,
    [RQSTR]    INT           NULL,
    [AUSTR]    INT           NULL,
    [CMF]      NVARCHAR (2)  NULL,
    CONSTRAINT [PK_FmsWebSacsPersonnel] PRIMARY KEY CLUSTERED ([Id] ASC)
);





