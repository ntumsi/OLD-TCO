CREATE TABLE [crunch_temp].[CostOfSelectiveRetentionBonus] (
    [PayPlan]              NVARCHAR (3)    NOT NULL,
    [CategoryGroupCode]    NVARCHAR (4)    NOT NULL,
    [CategorySubgroupCode] NVARCHAR (4)    NOT NULL,
    [GradeType]            NVARCHAR (3)    NOT NULL,
    [GradeLevel]           TINYINT         NOT NULL,
    [Inventory]            INT             NOT NULL,
    [CGLAInventory]        INT             NOT NULL,
    [AverageAnnualPay]     NUMERIC (16, 2) NOT NULL,
    [PayCap]               NUMERIC (16, 2) NOT NULL,
    [CGLA_MPA_Pay]         NUMERIC (16, 2) NOT NULL
);


GO
CREATE NONCLUSTERED INDEX [NonClusteredIndex-20250626-140504]
    ON [crunch_temp].[CostOfSelectiveRetentionBonus]([PayPlan] ASC, [CategoryGroupCode] ASC, [CategorySubgroupCode] ASC, [GradeLevel] ASC);

