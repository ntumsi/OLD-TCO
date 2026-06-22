CREATE TABLE [load_inventory].[Inventory_Military_Warrant] (
    [PayPlan]    NVARCHAR (3) NOT NULL,
    [Branch]     NCHAR (2)    NOT NULL,
    [WOMOS]      NVARCHAR (4) NOT NULL,
    [Quality]    TINYINT      NOT NULL,
    [GradeType]  NVARCHAR (3) NOT NULL,
    [GradeLevel] TINYINT      NOT NULL,
    [YOS]        TINYINT      NOT NULL,
    [Inventory]  INT          NOT NULL,
    CONSTRAINT [PK_Inventory_Military_Warrant] PRIMARY KEY CLUSTERED ([PayPlan] ASC, [Branch] ASC, [WOMOS] ASC, [Quality] ASC, [GradeType] ASC, [GradeLevel] ASC, [YOS] ASC),
    CONSTRAINT [FK_Inventory_Military_Warrant_WOMOS] FOREIGN KEY ([WOMOS]) REFERENCES [lookup].[WOMOS] ([WOMOS])
);

