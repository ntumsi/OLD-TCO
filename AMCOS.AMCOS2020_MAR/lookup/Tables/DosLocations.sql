CREATE TABLE [lookup].[DosLocations] (
    [LocationCode]        NVARCHAR (50)  NOT NULL,
    [Country]             NVARCHAR (50)  NOT NULL,
    [Location]            NVARCHAR (50)  NOT NULL,
    [AmcosVersionIdStart] INT            DEFAULT ((1)) NOT NULL,
    [AmcosVersionIdEnd]   INT            DEFAULT ((999999)) NOT NULL,
    [Latitude]            NUMERIC (7, 4) NULL,
    [Longitude]           NUMERIC (7, 4) NULL,
    CONSTRAINT [DOSLocationsPK] PRIMARY KEY CLUSTERED ([LocationCode] ASC, [AmcosVersionIdEnd] ASC)
);



