CREATE TABLE [dataload].[ConusColaLocations] (
    [ZIPCode]          NVARCHAR (5)  NOT NULL,
    [DutyStationIndex] NCHAR (2)     NOT NULL,
    [MHADescription]   NVARCHAR (50) NULL,
    [AmcosVersionId]   INT           NOT NULL,
    CONSTRAINT [PK_ConusColaLocations] PRIMARY KEY CLUSTERED ([ZIPCode] ASC, [DutyStationIndex] ASC, [AmcosVersionId] ASC)
);





