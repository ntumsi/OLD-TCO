CREATE TABLE [dataload].[SingleValues] (
    [Id]         INT             IDENTITY (1, 1) NOT NULL,
    [PayPlan]    NVARCHAR (3)    NOT NULL,
    [paramName]  NVARCHAR (100)  NOT NULL,
    [paramValue] NUMERIC (26, 6) NULL,
    [paramDesc]  NVARCHAR (500)  NULL,
    CONSTRAINT [PK_SingleValues] PRIMARY KEY CLUSTERED ([Id] ASC)
);

