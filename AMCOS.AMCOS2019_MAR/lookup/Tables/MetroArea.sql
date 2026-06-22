CREATE TABLE [lookup].[MetroArea] (
    [AreaCode]     NVARCHAR (7)   NOT NULL,
    [AreaTypeCode] NCHAR (1)      NOT NULL,
    [StateCode]    NCHAR (2)      NOT NULL,
    [AreaName]     NVARCHAR (100) NOT NULL,
    CONSTRAINT [PK_MetroArea_1] PRIMARY KEY CLUSTERED ([AreaCode] ASC)
);

