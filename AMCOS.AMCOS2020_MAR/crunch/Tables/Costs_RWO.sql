CREATE TABLE [crunch].[Costs_RWO] (
    [PayPlan]        NVARCHAR (3)    NOT NULL,
    [Branch]         NCHAR (2)       NOT NULL,
    [WOMOS]          NVARCHAR (4)    NOT NULL,
    [WeaponSystemId] INT             NOT NULL,
    [GradeType]      NVARCHAR (3)    NOT NULL,
    [GradeLevel]     TINYINT         NOT NULL,
    [CostElementId]  INT             NOT NULL,
    [Amount]         NUMERIC (16, 2) NOT NULL,
    [CrunchTime]     SMALLDATETIME   NULL,
    [AmcosVersionId] INT             NOT NULL,
    CONSTRAINT [PK_Costs_RWO] PRIMARY KEY CLUSTERED ([PayPlan] ASC, [Branch] ASC, [WOMOS] ASC, [WeaponSystemId] ASC, [GradeType] ASC, [GradeLevel] ASC, [CostElementId] ASC, [AmcosVersionId] ASC)
);







