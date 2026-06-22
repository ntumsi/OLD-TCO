CREATE TABLE [lookup].[SubgroupMapping] (
    [PayPlan]                NVARCHAR (3) NOT NULL,
    [CategorySubgroupCode]   NVARCHAR (7) NOT NULL,
    [ToPayPlan]              NVARCHAR (3) NOT NULL,
    [ToCategorySubgroupCode] NVARCHAR (7) NOT NULL,
    [AmcosVersionIdStart]    INT          NULL,
    [AmcosVersionIdEnd]      INT          NOT NULL,
    CONSTRAINT [PK_SubGroup_Mapping] PRIMARY KEY CLUSTERED ([PayPlan] ASC, [CategorySubgroupCode] ASC, [ToPayPlan] ASC, [ToCategorySubgroupCode] ASC, [AmcosVersionIdEnd] ASC)
);



