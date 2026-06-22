CREATE TABLE [crunch].[Costs_AE] (
    [PayPlan]         NVARCHAR (3)    NOT NULL,
    [CMF]             NCHAR (2)       NOT NULL,
    [MOS]             NVARCHAR (3)    NOT NULL,
    [MHA]             NVARCHAR (5)    CONSTRAINT [DF_Costs_AE_MHA] DEFAULT (N'-1') NOT NULL,
    [LocationId]      INT             NOT NULL,
    [DependentStatus] NVARCHAR (25)   CONSTRAINT [DF_Costs_AE_DependentStatus] DEFAULT (N'-1') NOT NULL,
    [WeaponSystemId]  INT             NOT NULL,
    [GradeType]       NVARCHAR (3)    NOT NULL,
    [GradeLevel]      TINYINT         NOT NULL,
    [CostElementId]   INT             NOT NULL,
    [Amount]          NUMERIC (16, 2) NOT NULL,
    [CrunchTime]      SMALLDATETIME   NULL,
    [AmcosVersionId]  INT             NOT NULL,
    CONSTRAINT [PK_Costs_AE] PRIMARY KEY CLUSTERED ([PayPlan] ASC, [CMF] ASC, [MOS] ASC, [MHA] ASC, [LocationId] ASC, [DependentStatus] ASC, [WeaponSystemId] ASC, [GradeType] ASC, [GradeLevel] ASC, [CostElementId] ASC, [AmcosVersionId] ASC)
);






























GO



GO



GO
CREATE NONCLUSTERED INDEX [IX_Costs_AE_AddUnit]
    ON [crunch].[Costs_AE]([PayPlan] ASC, [CMF] ASC, [MOS] ASC, [LocationId] ASC, [DependentStatus] ASC, [GradeLevel] ASC, [AmcosVersionId] ASC)
    INCLUDE([CostElementId]);


GO


