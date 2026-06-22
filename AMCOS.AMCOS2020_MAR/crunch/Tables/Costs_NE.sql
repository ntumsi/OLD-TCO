CREATE TABLE [crunch].[Costs_NE] (
    [PayPlan]        NVARCHAR (3)    NOT NULL,
    [CMF]            NCHAR (2)       NOT NULL,
    [MOS]            NVARCHAR (3)    NOT NULL,
    [CostElementId]  INT             NOT NULL,
    [GradeType]      NVARCHAR (3)    NOT NULL,
    [GradeLevel]     TINYINT         NOT NULL,
    [WeaponSystemId] INT             NOT NULL,
    [Amount]         NUMERIC (16, 2) NOT NULL,
    [CrunchTime]     SMALLDATETIME   NULL,
    [AmcosVersionId] INT             NOT NULL,
    CONSTRAINT [PK_Costs_NE_1] PRIMARY KEY CLUSTERED ([PayPlan] ASC, [CMF] ASC, [MOS] ASC, [CostElementId] ASC, [GradeType] ASC, [GradeLevel] ASC, [WeaponSystemId] ASC, [AmcosVersionId] ASC)
);





