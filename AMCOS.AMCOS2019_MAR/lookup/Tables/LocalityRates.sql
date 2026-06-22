CREATE TABLE [lookup].[LocalityRates] (
    [Id]                  INT             NOT NULL,
    [Description]         NVARCHAR (100)  NOT NULL,
    [Location]            NVARCHAR (200)  NULL,
    [Amount]              NUMERIC (18, 4) NULL,
    [StateName]           NVARCHAR (6)    NULL,
    [AreaCode]            NVARCHAR (8)    NULL,
    [StateCode]           NCHAR (2)       NULL,
    [CountyCode]          NVARCHAR (3)    NULL,
    [CityCode]            NVARCHAR (4)    NULL,
    [LocalityId]          INT             NULL,
    [IsLocalityPayArea]   BIT             NULL,
    [SortOrder]           TINYINT         NULL,
    [LocalityPayAreaCode] NCHAR (2)       NULL,
    CONSTRAINT [PK_LocalityRates] PRIMARY KEY CLUSTERED ([Id] ASC)
);



