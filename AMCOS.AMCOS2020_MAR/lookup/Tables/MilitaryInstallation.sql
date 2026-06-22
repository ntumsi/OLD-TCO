CREATE TABLE [lookup].[MilitaryInstallation] (
    [MI_Id]               INT               IDENTITY (1, 1) NOT NULL,
    [MACOMName]           NVARCHAR (50)     NULL,
    [InstallationName]    NVARCHAR (150)    NULL,
    [BaseCode]            NVARCHAR (50)     NULL,
    [BaseName]            NVARCHAR (50)     NULL,
    [STACO]               NVARCHAR (50)     NULL,
    [StationName]         NVARCHAR (150)    NULL,
    [Status]              NVARCHAR (50)     NULL,
    [SiteCode]            NVARCHAR (50)     NULL,
    [Component]           NVARCHAR (50)     NULL,
    [Service]             NVARCHAR (50)     NULL,
    [Address]             NVARCHAR (150)    NULL,
    [City]                NVARCHAR (50)     NULL,
    [State]               NVARCHAR (50)     NULL,
    [ZIPCode]             NVARCHAR (50)     NULL,
    [Phone]               NVARCHAR (50)     NULL,
    [Facid]               NVARCHAR (50)     NULL,
    [Geloc]               NVARCHAR (50)     NULL,
    [Geona]               NVARCHAR (50)     NULL,
    [Congdis]             NVARCHAR (50)     NULL,
    [BoundaryGeom]        [sys].[geometry]  NULL,
    [PointGeo]            [sys].[geography] NULL,
    [source]              NVARCHAR (50)     NULL,
    [AmcosVersionIdStart] INT               NULL,
    [AmcosVersionIdEnd]   INT               NOT NULL,
    CONSTRAINT [PK_MilitaryInstallation] PRIMARY KEY CLUSTERED ([MI_Id] ASC, [AmcosVersionIdEnd] ASC)
);






GO
CREATE NONCLUSTERED INDEX [NonClusteredIndex-20200109-173819]
    ON [lookup].[MilitaryInstallation]([BaseCode] ASC, [BaseName] ASC, [InstallationName] ASC, [ZIPCode] ASC);

