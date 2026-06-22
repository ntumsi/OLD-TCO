CREATE TABLE [dataload].[SingleValues] (
    [PayPlan]        NVARCHAR (10)   NOT NULL,
    [paramName]      NVARCHAR (100)  NOT NULL,
    [paramValue]     NUMERIC (26, 6) NULL,
    [paramDesc]      NVARCHAR (500)  NULL,
    [AmcosVersionId] INT             NOT NULL,
    [comments]       NVARCHAR (300)  NULL,
    CONSTRAINT [PK_SingleValues] PRIMARY KEY CLUSTERED ([PayPlan] ASC, [paramName] ASC, [AmcosVersionId] ASC)
);









