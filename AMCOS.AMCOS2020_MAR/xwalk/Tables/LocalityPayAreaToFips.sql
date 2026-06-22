CREATE TABLE [xwalk].[LocalityPayAreaToFips] (
    [LocalityCode]   NVARCHAR (6)   NOT NULL,
    [StateCode]      NVARCHAR (2)   NOT NULL,
    [CountyCode]     NVARCHAR (3)   NOT NULL,
    [CityCode]       NVARCHAR (4)   NOT NULL,
    [PlaceName]      NVARCHAR (200) NULL,
    [AmcosVersionId] INT            NOT NULL,
    CONSTRAINT [PK_LocalityPayAreaToFips] PRIMARY KEY CLUSTERED ([LocalityCode] ASC, [StateCode] ASC, [CountyCode] ASC, [CityCode] ASC, [AmcosVersionId] ASC)
);



