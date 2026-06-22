CREATE TABLE [lookup].[GSA_GLC] (
    [Id]            INT            IDENTITY (1, 1) NOT NULL,
    [Territory]     NVARCHAR (1)   NOT NULL,
    [Location_Name] NVARCHAR (150) NOT NULL,
    [Location_Code] NVARCHAR (2)   NULL,
    [City_Code]     NVARCHAR (4)   NOT NULL,
    [City_Name]     NVARCHAR (150) NOT NULL,
    [County_Code]   NVARCHAR (3)   NOT NULL,
    [County_Name]   NVARCHAR (150) NOT NULL,
    CONSTRAINT [PK_GSA_GLC] PRIMARY KEY CLUSTERED ([Id] ASC)
);









