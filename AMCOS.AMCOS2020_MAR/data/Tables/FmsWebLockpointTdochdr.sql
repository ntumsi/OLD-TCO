CREATE TABLE [data].[FmsWebLockpointTdochdr] (
    [CCNUM_MACOM]    NVARCHAR (2)  NULL,
    [DOCNO]          NVARCHAR (10) NOT NULL,
    [CCNUM_CHGNR_FY] NVARCHAR (4)  NOT NULL,
    [DOCST]          NVARCHAR (1)  NULL,
    [ANLCD]          NVARCHAR (32) NULL,
    [ARIND]          NVARCHAR (1)  NULL,
    [BCCNO]          NVARCHAR (6)  NULL,
    [BDOCN]          NVARCHAR (10) NULL,
    [CLASS]          NVARCHAR (1)  NULL,
    [CUASC]          NVARCHAR (4)  NULL,
    [DEDTE]          DATETIME      NULL,
    [DOCOW]          NVARCHAR (1)  NULL,
    [DOCSD]          DATETIME      NULL,
    [EFLAG]          NVARCHAR (1)  NULL,
    [LAACT]          NVARCHAR (6)  NULL,
    [LNAME_TDH]      NVARCHAR (55) NULL,
    [LVLDOWN]        DATETIME      NULL,
    [LVLUP]          DATETIME      NULL,
    [PPACO]          NVARCHAR (2)  NULL,
    [PRTCD]          NVARCHAR (1)  NULL,
    [REPCO_TDH]      NVARCHAR (1)  NULL,
    [DP99]           NVARCHAR (6)  NULL,
    [SDOCN]          NVARCHAR (10) NULL,
    [SHADOW]         NVARCHAR (1)  NULL,
    [SHPCD]          NVARCHAR (1)  NULL,
    [SHPDT]          DATETIME      NULL,
    [SITECD]         NVARCHAR (4)  NULL,
    [STCCNO]         NVARCHAR (6)  NULL,
    [STRPR]          DATETIME      NULL,
    [TPACO]          NVARCHAR (2)  NULL,
    [TRDTE]          DATETIME      NULL,
    [TRFRM]          NVARCHAR (2)  NULL,
    [UICER]          NVARCHAR (1)  NULL,
    [UICOD]          NVARCHAR (6)  NOT NULL,
    [AmcosVersionId] INT           NOT NULL,
    CONSTRAINT [PK_FmsWebLockpointTdochdr] PRIMARY KEY CLUSTERED ([DOCNO] ASC, [CCNUM_CHGNR_FY] ASC, [UICOD] ASC, [AmcosVersionId] ASC)
);





