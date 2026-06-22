CREATE TABLE [lookup].[ATRRSOfficerBranchCodes] (
    [Id]             INT            IDENTITY (1, 1) NOT NULL,
    [CMF]            NVARCHAR (3)   NULL,
    [Branch]         NVARCHAR (3)   NULL,
    [definition]     NVARCHAR (255) NULL,
    [AmcosVersionId] INT            NULL,
    CONSTRAINT [PK_ATRRSOfficerBranchCodes] PRIMARY KEY CLUSTERED ([Id] ASC)
);



