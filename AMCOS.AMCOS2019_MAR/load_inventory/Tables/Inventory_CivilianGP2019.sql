CREATE TABLE [load_inventory].[Inventory_CivilianGP2019] (
    [PayPlan]                  NVARCHAR (3)  NOT NULL,
    [OccupationalGroupNumber]  NVARCHAR (4)  NOT NULL,
    [OccupationalSeriesNumber] NVARCHAR (4)  NOT NULL,
    [StateCountry]             NVARCHAR (50) NOT NULL,
    [FunctionalAreaCode]       NVARCHAR (50) NOT NULL,
    [CostCenterCode]           NVARCHAR (50) NOT NULL,
    [GradeType]                NVARCHAR (3)  NOT NULL,
    [GradeLevel]               TINYINT       NOT NULL,
    [Step]                     TINYINT       NOT NULL,
    [YOS]                      TINYINT       NULL,
    [Inventory]                INT           NOT NULL,
    CONSTRAINT [PK_Inventory_CivilianGP2019] PRIMARY KEY CLUSTERED ([PayPlan] ASC, [OccupationalGroupNumber] ASC, [OccupationalSeriesNumber] ASC, [StateCountry] ASC, [FunctionalAreaCode] ASC, [CostCenterCode] ASC, [GradeType] ASC, [GradeLevel] ASC, [Step] ASC),
    CONSTRAINT [FK_Inventory_CivilianGP2019_GS_OccupationalSeries] FOREIGN KEY ([OccupationalSeriesNumber]) REFERENCES [lookup].[GS_OccupationalSeries] ([OccupationalSeriesNumber])
);



