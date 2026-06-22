CREATE TABLE [xwalk].[SpecialRateTablesByAgency] (
    [Agency]         NVARCHAR (50)  NULL,
    [Subelement]     NVARCHAR (50)  NULL,
    [Title]          NVARCHAR (200) NOT NULL,
    [TableNumber]    NVARCHAR (4)   NOT NULL,
    [AmcosVersionId] INT            NOT NULL,
    CONSTRAINT [PK_SpecialRateTablesByAgency] PRIMARY KEY CLUSTERED ([Title] ASC, [TableNumber] ASC, [AmcosVersionId] ASC)
);



