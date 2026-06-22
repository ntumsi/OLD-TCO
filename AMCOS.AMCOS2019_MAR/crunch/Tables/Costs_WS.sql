CREATE TABLE [crunch].[Costs_WS] (
    [PayPlan]       NVARCHAR (3)  NOT NULL,
    [WageArea]      NVARCHAR (3)  NOT NULL,
    [CostElementId] INT           NOT NULL,
    [GradeType]     NVARCHAR (3)  NOT NULL,
    [GradeLevel]    TINYINT       NOT NULL,
    [Amount]        FLOAT (53)    NOT NULL,
    [CrunchTime]    SMALLDATETIME NULL,
    CONSTRAINT [PK_Costs_WS] PRIMARY KEY CLUSTERED ([PayPlan] ASC, [WageArea] ASC, [CostElementId] ASC, [GradeType] ASC, [GradeLevel] ASC)
);

