CREATE TABLE [load_inventory].[Inventory_Military_Officer] (
    [PayPlan]    NVARCHAR (3) NOT NULL,
    [BranchFA]   NCHAR (2)    NOT NULL,
    [AOC]        NVARCHAR (3) NOT NULL,
    [Quality]    TINYINT      NOT NULL,
    [GradeType]  NVARCHAR (3) NOT NULL,
    [GradeLevel] TINYINT      NOT NULL,
    [YOS]        TINYINT      NOT NULL,
    [Inventory]  INT          NOT NULL,
    CONSTRAINT [PK_Inventory_Military_Officer] PRIMARY KEY CLUSTERED ([PayPlan] ASC, [BranchFA] ASC, [AOC] ASC, [Quality] ASC, [GradeType] ASC, [GradeLevel] ASC, [YOS] ASC),
    CONSTRAINT [FK_Inventory_Military_Officer_AOC] FOREIGN KEY ([AOC]) REFERENCES [lookup].[AOC] ([AOC])
);

