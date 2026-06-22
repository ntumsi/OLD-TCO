CREATE TABLE [web].[QlikApplication] (
    [Id]                INT            IDENTITY (1, 1) NOT NULL,
    [ApplicationTitle]  NVARCHAR (50)  NOT NULL,
    [DevApplicationId]  NVARCHAR (50)  NULL,
    [DevObjectId]       NVARCHAR (50)  NULL,
    [ProdApplicationId] NVARCHAR (50)  NULL,
    [ProdObjectId]      NVARCHAR (50)  NULL,
    [CssClass]          NVARCHAR (100) NULL,
    [Order]             INT            DEFAULT ((0)) NOT NULL,
    [IsFieldSelect]     BIT            DEFAULT ((0)) NOT NULL,
    [TestApplicationId] NVARCHAR (50)  NULL,
    [TestObjectId]      NVARCHAR (50)  NULL,
    [Description]       NVARCHAR (100) NULL,
    [HasExport]         BIT            CONSTRAINT [DF_QlikApplication_HasExport] DEFAULT ((0)) NOT NULL,
    PRIMARY KEY NONCLUSTERED ([Id] ASC)
);


GO;
CREATE CLUSTERED INDEX Idx_AppTitle ON web.QlikApplication(ApplicationTitle);
GO;