CREATE TABLE [xwalk].[MetropolitanStatisticalAreaToFips] (
    [MSACode]             NVARCHAR (7) NOT NULL,
    [StateCode]           NCHAR (2)    NOT NULL,
    [CountyCode]          NCHAR (3)    NOT NULL,
    [AmcosVersionIdStart] INT          NULL,
    [AmcosVersionIdEnd]   INT          NULL,
    [AmcosVersionId]      INT          NULL
);





