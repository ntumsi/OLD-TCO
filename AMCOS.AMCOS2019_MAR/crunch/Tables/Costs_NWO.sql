CREATE TABLE [crunch].[Costs_NWO] (
    [PayPlan]        NVARCHAR (3)    NOT NULL,
    [Branch]         NCHAR (2)       NOT NULL,
    [WOMOS]          NVARCHAR (4)    NOT NULL,
    [CostElementId]  INT             NOT NULL,
    [GradeType]      NVARCHAR (3)    NOT NULL,
    [GradeLevel]     TINYINT         NOT NULL,
    [WeaponSystemId] INT             NOT NULL,
    [Amount]         NUMERIC (26, 6) NOT NULL,
    [CrunchTime]     SMALLDATETIME   NULL,
    CONSTRAINT [PK_Costs_NWO] PRIMARY KEY CLUSTERED ([PayPlan] ASC, [Branch] ASC, [WOMOS] ASC, [CostElementId] ASC, [GradeType] ASC, [GradeLevel] ASC, [WeaponSystemId] ASC)
);

