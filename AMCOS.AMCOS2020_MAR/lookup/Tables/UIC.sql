CREATE TABLE [lookup].[UIC] (
    [UIC]                 NVARCHAR (6)  NOT NULL,
    [EDATEUIC]            NVARCHAR (50) NULL,
    [Name]                NVARCHAR (75) NULL,
    [LocationName]        NVARCHAR (25) NULL,
    [MACOM]               NVARCHAR (2)  NULL,
    [SBCOM]               NVARCHAR (2)  NULL,
    [TPACO]               NVARCHAR (2)  NULL,
    [PPACO]               NVARCHAR (2)  NULL,
    [UICUR]               NVARCHAR (50) NULL,
    [GELOC]               NVARCHAR (4)  NULL,
    [UDATE]               NVARCHAR (50) NULL,
    [TCODE]               NCHAR (1)     NULL,
    [ARLOC]               NVARCHAR (5)  NULL,
    [ZIP]                 NVARCHAR (7)  NULL,
    [TPSN]                NVARCHAR (7)  NULL,
    [Status]              NCHAR (1)     NULL,
    [AmcosVersionIdStart] INT           NULL,
    [AmcosVersionIdEnd]   INT           NOT NULL,
    CONSTRAINT [PK_UIC] PRIMARY KEY CLUSTERED ([UIC] ASC, [AmcosVersionIdEnd] ASC)
);



