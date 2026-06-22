CREATE TABLE [load_inventory].[Inventory_Military_Enlisted] (
    [PayPlan]    NVARCHAR (3) NOT NULL,
    [CMF]        NCHAR (2)    NOT NULL,
    [MOS]        NVARCHAR (3) NOT NULL,
    [Quality]    TINYINT      NOT NULL,
    [GradeType]  NVARCHAR (3) NOT NULL,
    [GradeLevel] TINYINT      NOT NULL,
    [YOS]        TINYINT      NOT NULL,
    [Inventory]  INT          NOT NULL,
    CONSTRAINT [PK_Inventory_Military_Enlisted] PRIMARY KEY CLUSTERED ([PayPlan] ASC, [CMF] ASC, [MOS] ASC, [Quality] ASC, [GradeType] ASC, [GradeLevel] ASC, [YOS] ASC),
    CONSTRAINT [FK_Inventory_Military_Enlisted_MOS] FOREIGN KEY ([MOS]) REFERENCES [lookup].[MOS] ([MOS])
);

