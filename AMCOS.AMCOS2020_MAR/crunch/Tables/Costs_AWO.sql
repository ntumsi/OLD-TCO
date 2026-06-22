CREATE TABLE [crunch].[Costs_AWO] (
    [PayPlan]         NVARCHAR (3)    NOT NULL,
    [Branch]          NCHAR (2)       NOT NULL,
    [WOMOS]           NVARCHAR (4)    NOT NULL,
    [MHA]             NVARCHAR (5)    CONSTRAINT [DF_Costs_AWO_MHA] DEFAULT ((-1)) NOT NULL,
    [LocationId]      INT             NOT NULL,
    [DependentStatus] NVARCHAR (25)   CONSTRAINT [DF_Costs_AWO_DependentStatus] DEFAULT ((-1)) NOT NULL,
    [WeaponSystemId]  INT             NOT NULL,
    [GradeType]       NVARCHAR (3)    NOT NULL,
    [GradeLevel]      TINYINT         NOT NULL,
    [CostElementId]   INT             NOT NULL,
    [Amount]          NUMERIC (16, 2) NOT NULL,
    [CrunchTime]      SMALLDATETIME   NULL,
    [AmcosVersionId]  INT             NOT NULL,
    CONSTRAINT [PK_Costs_AWO] PRIMARY KEY CLUSTERED ([PayPlan] ASC, [Branch] ASC, [WOMOS] ASC, [MHA] ASC, [DependentStatus] ASC, [LocationId] ASC, [CostElementId] ASC, [GradeType] ASC, [GradeLevel] ASC, [WeaponSystemId] ASC, [AmcosVersionId] ASC)
);






















GO



GO



GO
CREATE NONCLUSTERED INDEX [IX_Costs_AWO_AddUnit]
    ON [crunch].[Costs_AWO]([PayPlan] ASC, [Branch] ASC, [WOMOS] ASC, [LocationId] ASC, [DependentStatus] ASC, [GradeLevel] ASC, [AmcosVersionId] ASC)
    INCLUDE([CostElementId]);

