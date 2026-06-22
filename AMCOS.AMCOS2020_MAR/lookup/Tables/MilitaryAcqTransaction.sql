CREATE TABLE [lookup].[MilitaryAcqTransaction] (
    [Code]                NVARCHAR (255) NOT NULL,
    [Description]         NVARCHAR (255) NULL,
    [Type]                NVARCHAR (255) NULL,
    [Include_Exclude]     NVARCHAR (255) NULL,
    [AmcosVersionIdStart] INT            NOT NULL,
    [AmcosVersionIdEnd]   INT            NOT NULL,
    CONSTRAINT [PK_MilitaryAcqTransaction] PRIMARY KEY CLUSTERED ([Code] ASC, [AmcosVersionIdEnd] ASC)
);





