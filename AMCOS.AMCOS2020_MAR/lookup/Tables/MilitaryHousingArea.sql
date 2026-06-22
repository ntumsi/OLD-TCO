CREATE TABLE [lookup].[MilitaryHousingArea] (
    [MHA]            NVARCHAR (5)   NOT NULL,
    [Location]       NVARCHAR (10)  NOT NULL,
    [Description]    NVARCHAR (250) NULL,
    [DisplayName]    NVARCHAR (250) CONSTRAINT [DF__MilitaryH__Displ__7DE38492] DEFAULT ('') NULL,
    [AmcosVersionId] INT            NOT NULL,
    CONSTRAINT [PK_MilitaryHousingArea_1] PRIMARY KEY CLUSTERED ([MHA] ASC, [Location] ASC, [AmcosVersionId] ASC)
);













