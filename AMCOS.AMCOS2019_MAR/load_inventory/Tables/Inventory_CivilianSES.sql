CREATE TABLE [load_inventory].[Inventory_CivilianSES] (
    [PayPlan]                  NVARCHAR (3) NOT NULL,
    [OccupationalGroupNumber]  NVARCHAR (4) NOT NULL,
    [OccupationalSeriesNumber] NVARCHAR (4) NOT NULL,
    [GradeType]                NVARCHAR (3) NOT NULL,
    [GradeLevel]               TINYINT      NOT NULL,
    [YOS]                      TINYINT      NOT NULL,
    [Inventory]                INT          NOT NULL,
    CONSTRAINT [PK_Inventory_CivilianSES] PRIMARY KEY CLUSTERED ([PayPlan] ASC, [OccupationalGroupNumber] ASC, [OccupationalSeriesNumber] ASC, [GradeType] ASC, [GradeLevel] ASC, [YOS] ASC),
    CONSTRAINT [FK_Inventory_CivilianSES_GS_OccupationalSeries] FOREIGN KEY ([OccupationalSeriesNumber]) REFERENCES [lookup].[GS_OccupationalSeries] ([OccupationalSeriesNumber])
);

