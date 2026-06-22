CREATE TABLE [xwalk].[DLOCtoDoS] (
    [DLOC]                NVARCHAR (9) NOT NULL,
    [DOSLocation]         NVARCHAR (5) NOT NULL,
    [AmcosVersionIdStart] INT          NOT NULL,
    [AmcosVersionIdEnd]   INT          NOT NULL,
    CONSTRAINT [PK_DLOCtoDoS] PRIMARY KEY CLUSTERED ([DLOC] ASC, [DOSLocation] ASC, [AmcosVersionIdEnd] ASC)
);





