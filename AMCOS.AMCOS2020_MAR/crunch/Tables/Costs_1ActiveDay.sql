CREATE TABLE [crunch].[Costs_1ActiveDay] (
    [PayPlan]              NVARCHAR (3)    NOT NULL,
    [CategoryGroupCode]    NCHAR (2)       NOT NULL,
    [CategorySubgroupCode] NVARCHAR (4)    NOT NULL,
    [WeaponSystemId]       INT             NOT NULL,
    [GradeType]            NVARCHAR (3)    NOT NULL,
    [GradeLevel]           TINYINT         NOT NULL,
    [CostElementId]        INT             NOT NULL,
    [Amount]               NUMERIC (16, 2) NOT NULL,
    [CrunchTime]           SMALLDATETIME   NULL,
    [AmcosVersionId]       INT             NOT NULL,
    CONSTRAINT [PK_Costs_1ActiveDay] PRIMARY KEY CLUSTERED ([PayPlan] ASC, [CategoryGroupCode] ASC, [CategorySubgroupCode] ASC, [WeaponSystemId] ASC, [GradeType] ASC, [GradeLevel] ASC, [CostElementId] ASC, [AmcosVersionId] ASC)
);










GO


