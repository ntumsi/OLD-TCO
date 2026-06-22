CREATE TABLE [crunch].[WASS_Processed] (
    [PayPlan]        VARCHAR (3)     NOT NULL,
    [Group]          VARCHAR (20)    NOT NULL,
    [Subgroup]       VARCHAR (4)     NOT NULL,
    [GradeType]      VARCHAR (3)     NOT NULL,
    [GradeLevel]     VARCHAR (2)     NOT NULL,
    [Step]           VARCHAR (2)     NOT NULL,
    [LocationId]     INT             NOT NULL,
    [Inventory]      INT             NOT NULL,
    [AmcosVersionId] INT             NOT NULL,
    [AvgPay]         NUMERIC (18, 2) NULL,
    CONSTRAINT [PK_WASS_Inv] PRIMARY KEY CLUSTERED ([PayPlan] ASC, [Group] ASC, [Subgroup] ASC, [Step] ASC, [LocationId] ASC, [GradeType] ASC, [GradeLevel] ASC, [AmcosVersionId] ASC)
);

