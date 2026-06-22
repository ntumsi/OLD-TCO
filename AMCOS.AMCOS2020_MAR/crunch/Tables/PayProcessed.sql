CREATE TABLE [crunch].[PayProcessed] (
    [PayPlan]              NVARCHAR (3)    NOT NULL,
    [CategoryGroupCode]    NVARCHAR (4)    NOT NULL,
    [CategorySubgroupCode] NVARCHAR (4)    NOT NULL,
    [GradeType]            NVARCHAR (3)    NOT NULL,
    [GradeLevel]           TINYINT         NOT NULL,
    [PayType]              NVARCHAR (300)  NOT NULL,
    [avg_cost]             NUMERIC (18, 2) NULL,
    [avg_annual_pay]       NUMERIC (18, 2) NULL,
    [avg_annual_payments]  NUMERIC (18, 2) NULL,
    [AmcosVersionId]       INT             NOT NULL,
    CONSTRAINT [PK_PayProcessed] PRIMARY KEY CLUSTERED ([PayPlan] ASC, [CategoryGroupCode] ASC, [CategorySubgroupCode] ASC, [GradeType] ASC, [GradeLevel] ASC, [PayType] ASC, [AmcosVersionId] ASC)
);







