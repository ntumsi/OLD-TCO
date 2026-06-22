CREATE TABLE [lookup].[SubgroupMapping] (
    [PayPlan]                NVARCHAR (3) NOT NULL,
    [CategorySubGroupCode]   NVARCHAR (7) NOT NULL,
    [ToPayPlan]              NVARCHAR (3) NOT NULL,
    [ToCategorySubGroupCode] NVARCHAR (7) NOT NULL,
    CONSTRAINT [PK_SubGroup_Mapping] PRIMARY KEY CLUSTERED ([PayPlan] ASC, [CategorySubGroupCode] ASC, [ToPayPlan] ASC, [ToCategorySubGroupCode] ASC)
);

