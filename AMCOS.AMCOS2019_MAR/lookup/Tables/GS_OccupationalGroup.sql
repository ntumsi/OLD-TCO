CREATE TABLE [lookup].[GS_OccupationalGroup] (
    [OccupationalGroupNumber] NVARCHAR (4)   NOT NULL,
    [GroupTitle]              NVARCHAR (250) NULL,
    CONSTRAINT [PK_GS_OccupationalGroups] PRIMARY KEY CLUSTERED ([OccupationalGroupNumber] ASC)
);

