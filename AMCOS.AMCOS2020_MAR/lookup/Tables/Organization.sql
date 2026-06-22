CREATE TABLE [lookup].[Organization] (
    [OrganizationName]        VARCHAR (50)  NOT NULL,
    [OrganizationDescription] VARCHAR (250) NULL,
    [OrganizationType]        VARCHAR (20)  NULL,
    CONSTRAINT [PK_Organization] PRIMARY KEY CLUSTERED ([OrganizationName] ASC)
);

