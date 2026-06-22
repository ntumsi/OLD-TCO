CREATE TABLE [lookup].[GFEBS_FunctionalArea] (
    [FunctionalAreaCode] NVARCHAR (50)  NOT NULL,
    [FunctionalAreaText] NVARCHAR (250) NULL,
    CONSTRAINT [PK_GFEBS_FunctionalArea] PRIMARY KEY CLUSTERED ([FunctionalAreaCode] ASC)
);

