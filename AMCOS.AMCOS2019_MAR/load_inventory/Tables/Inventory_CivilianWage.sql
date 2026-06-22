CREATE TABLE [load_inventory].[Inventory_CivilianWage] (
    [PayPlan]                  NVARCHAR (3) NOT NULL,
    [OccupationalGroupNumber]  NVARCHAR (4) NOT NULL,
    [OccupationalSeriesNumber] NVARCHAR (4) NOT NULL,
    [WageArea]                 NVARCHAR (3) NOT NULL,
    [GradeType]                NVARCHAR (3) NOT NULL,
    [GradeLevel]               TINYINT      NOT NULL,
    [Step]                     TINYINT      NOT NULL,
    [YOS]                      TINYINT      NOT NULL,
    [Inventory]                INT          NOT NULL,
    CONSTRAINT [PK_Inventory_CivilianWage] PRIMARY KEY CLUSTERED ([PayPlan] ASC, [OccupationalGroupNumber] ASC, [OccupationalSeriesNumber] ASC, [WageArea] ASC, [GradeType] ASC, [GradeLevel] ASC, [Step] ASC, [YOS] ASC),
    CONSTRAINT [FK_Inventory_CivilianWage_WageArea] FOREIGN KEY ([WageArea]) REFERENCES [lookup].[WageArea] ([WageArea])
);



