CREATE TABLE [analysis].[Outliers] (
    [PayPlan]              NVARCHAR (3)    NOT NULL,
    [GradeLevel]           TINYINT         NOT NULL,
    [CategoryGroupCode]    NCHAR (4)       NOT NULL,
    [CategorySubgroupCode] NVARCHAR (5)    NOT NULL,
    [CareerProgramNumber]  NCHAR (2)       NOT NULL,
    [LocationId]           INT             NOT NULL,
    [NumberOfDependents]   INT             NOT NULL,
    [DependentStatus]      NVARCHAR (25)   NOT NULL,
    [STRL]                 NVARCHAR (20)   NOT NULL,
    [Amount]               NUMERIC (18, 2) NOT NULL,
    [WeaponSystemId]       INT             DEFAULT ((-1)) NOT NULL,
    [CostElementId]        INT             DEFAULT ((-1)) NOT NULL,
    [AmcosVersionId]       INT             NOT NULL,
    [Label]                BIT             NOT NULL,
    CONSTRAINT [PK_analysis_outliers] PRIMARY KEY CLUSTERED ([PayPlan] ASC, [GradeLevel] ASC, [CategoryGroupCode] ASC, [CategorySubgroupCode] ASC, [CareerProgramNumber] ASC, [LocationId] ASC, [NumberOfDependents] ASC, [DependentStatus] ASC, [STRL] ASC, [CostElementId] ASC, [WeaponSystemId] ASC, [AmcosVersionId] ASC)
);

