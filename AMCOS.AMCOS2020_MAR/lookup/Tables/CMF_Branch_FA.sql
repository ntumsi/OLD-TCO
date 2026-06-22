CREATE TABLE [lookup].[CMF_Branch_FA] (
    [Code]                NCHAR (2)      NOT NULL,
    [GradeType]           NCHAR (1)      NOT NULL,
    [Description]         NVARCHAR (250) NOT NULL,
    [CodeType]            NVARCHAR (25)  NULL,
    [AmcosVersionIdStart] INT            NULL,
    [AmcosVersionIdEnd]   INT            NOT NULL,
    CONSTRAINT [PK_CMF_Branch_FA] PRIMARY KEY CLUSTERED ([Code] ASC, [GradeType] ASC, [AmcosVersionIdEnd] ASC)
);





