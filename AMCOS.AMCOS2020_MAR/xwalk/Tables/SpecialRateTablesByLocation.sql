CREATE TABLE [xwalk].[SpecialRateTablesByLocation] (
    [LocationName]   NVARCHAR (100) NOT NULL,
    [LocalityCode]   NVARCHAR (6)   NULL,
    [State]          NVARCHAR (2)   NOT NULL,
    [StateCode]      NVARCHAR (2)   NOT NULL,
    [CountyCode]     NVARCHAR (3)   NOT NULL,
    [CityCode]       NVARCHAR (4)   NOT NULL,
    [TableNumber]    NVARCHAR (4)   NOT NULL,
    [AmcosVersionId] INT            NOT NULL
);





