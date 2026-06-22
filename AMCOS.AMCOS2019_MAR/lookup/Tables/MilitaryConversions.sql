CREATE TABLE [lookup].[MilitaryConversions] (
    [OldMOS]         NVARCHAR (4) NOT NULL,
    [Grade]          NVARCHAR (1) NOT NULL,
    [NewMOS]         NVARCHAR (4) NULL,
    [AmcosVersionId] INT          NOT NULL,
    CONSTRAINT [PK_MilitaryConversions] PRIMARY KEY CLUSTERED ([OldMOS] ASC, [Grade] ASC, [AmcosVersionId] ASC)
);





