CREATE TABLE [load_inventory].[Inventory_Production] (
    [PayPlan]              NVARCHAR (3)  NOT NULL,
    [CategoryGroupCode]    NVARCHAR (7)  NOT NULL,
    [CategorySubgroupCode] NVARCHAR (7)  NOT NULL,
    [WageArea]             NVARCHAR (3)  NULL,
    [Quality]              TINYINT       NULL,
    [StateCountry]         NVARCHAR (50) NULL,
    [FunctionalAreaCode]   NVARCHAR (50) NULL,
    [CostCenterCode]       NVARCHAR (50) NULL,
    [GradeType]            NVARCHAR (3)  NOT NULL,
    [GradeLevel]           TINYINT       NOT NULL,
    [Step_YOS]             TINYINT       NULL,
    [Inventory]            INT           NOT NULL
);

