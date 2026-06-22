CREATE TABLE [crunch].[Costs_AO] (
    [PayPlan]         NVARCHAR (3)    NOT NULL,
    [CMF]             NCHAR (2)       NOT NULL,
    [AOC]             NVARCHAR (3)    NOT NULL,
    [MHA]             NVARCHAR (5)    CONSTRAINT [DF_Costs_AO_MHA] DEFAULT ((-1)) NOT NULL,
    [LocationId]      INT             NOT NULL,
    [DependentStatus] NVARCHAR (25)   CONSTRAINT [DF_Costs_AO_DependentStatus] DEFAULT ((-1)) NOT NULL,
    [WeaponSystemId]  INT             NOT NULL,
    [GradeType]       NVARCHAR (3)    NOT NULL,
    [GradeLevel]      TINYINT         NOT NULL,
    [CostElementId]   INT             NOT NULL,
    [Amount]          NUMERIC (16, 2) NOT NULL,
    [CrunchTime]      SMALLDATETIME   NULL,
    [AmcosVersionId]  INT             NOT NULL,
    CONSTRAINT [PK_Costs_AO] PRIMARY KEY CLUSTERED ([PayPlan] ASC, [CMF] ASC, [AOC] ASC, [MHA] ASC, [DependentStatus] ASC, [LocationId] ASC, [CostElementId] ASC, [GradeType] ASC, [GradeLevel] ASC, [WeaponSystemId] ASC, [AmcosVersionId] ASC)
);


























GO



GO



GO
CREATE NONCLUSTERED INDEX [IX_Costs_AO_AddUnit]
    ON [crunch].[Costs_AO]([PayPlan] ASC, [CMF] ASC, [AOC] ASC, [LocationId] ASC, [DependentStatus] ASC, [GradeLevel] ASC, [AmcosVersionId] ASC)
    INCLUDE([CostElementId]);

