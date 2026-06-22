CREATE TABLE [load_inventory].[Inventory_CivilianDemonstration2019] (
    [PayPlan]                  NVARCHAR (3)  NOT NULL,
    [OccupationalGroupNumber]  NVARCHAR (50) NOT NULL,
    [OccupationalSeriesNumber] NVARCHAR (50) NOT NULL,
    [StateCountry]             NVARCHAR (50) NOT NULL,
    [FunctionalAreaCode]       NVARCHAR (50) NOT NULL,
    [CostCenterCode]           NVARCHAR (50) NOT NULL,
    [GradeType]                NVARCHAR (3)  NOT NULL,
    [GradeLevel]               TINYINT       NOT NULL,
    [Step]                     TINYINT       NULL,
    [Inventory]                INT           NOT NULL,
    CONSTRAINT [PK_Inventory_CivilianDemonstration2019] PRIMARY KEY CLUSTERED ([PayPlan] ASC, [OccupationalGroupNumber] ASC, [OccupationalSeriesNumber] ASC, [StateCountry] ASC, [FunctionalAreaCode] ASC, [CostCenterCode] ASC, [GradeType] ASC, [GradeLevel] ASC)
);



