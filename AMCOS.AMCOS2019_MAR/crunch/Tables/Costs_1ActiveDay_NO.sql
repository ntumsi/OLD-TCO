CREATE TABLE [crunch].[Costs_1ActiveDay_NO] (
    [PayPlan]        NVARCHAR (3)  NOT NULL,
    [CMF]            NCHAR (2)     NOT NULL,
    [AOC]            NVARCHAR (3)  NOT NULL,
    [CostElementId]  INT           NOT NULL,
    [GradeType]      NVARCHAR (3)  NOT NULL,
    [GradeLevel]     TINYINT       NOT NULL,
    [WeaponSystemId] INT           NOT NULL,
    [Amount]         FLOAT (53)    NULL,
    [CrunchTime]     SMALLDATETIME NULL,
    CONSTRAINT [PK_Costs_1ActiveDay_NO_1] PRIMARY KEY CLUSTERED ([PayPlan] ASC, [CMF] ASC, [AOC] ASC, [CostElementId] ASC, [GradeType] ASC, [GradeLevel] ASC, [WeaponSystemId] ASC)
);

