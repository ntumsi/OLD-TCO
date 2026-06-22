CREATE TABLE [xwalk].[ZiptoDoS] (
    [ZIPCode]             NVARCHAR (5) NOT NULL,
    [DOSLocation]         NVARCHAR (5) NOT NULL,
    [AmcosVersionIdStart] INT          NOT NULL,
    [AmcosVersionIdEnd]   INT          NOT NULL,
    CONSTRAINT [PK_WageArea1] PRIMARY KEY CLUSTERED ([ZIPCode] ASC, [DOSLocation] ASC, [AmcosVersionIdEnd] ASC)
);



