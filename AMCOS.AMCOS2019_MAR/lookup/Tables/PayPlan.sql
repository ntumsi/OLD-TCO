CREATE TABLE [lookup].[PayPlan] (
    [PayPlan]               NVARCHAR (3)  NOT NULL,
    [Description]           NVARCHAR (50) NOT NULL,
    [CategoryGroupLabel]    NVARCHAR (50) NULL,
    [CategorySubgroupLabel] NVARCHAR (50) NULL,
    CONSTRAINT [PK_PayPlan] PRIMARY KEY CLUSTERED ([PayPlan] ASC)
);







