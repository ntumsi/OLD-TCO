CREATE TABLE [web].[PayPlanTag] (
    [PayPlan] NVARCHAR (3)  NOT NULL,
    [Tag]     NVARCHAR (25) NOT NULL,
    CONSTRAINT [PK_PayPlanTag] PRIMARY KEY CLUSTERED ([PayPlan] ASC, [Tag] ASC)
);

