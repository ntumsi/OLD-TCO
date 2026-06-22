CREATE TABLE [webuser].[PMCategorySkill] (
    [UserId]                 NVARCHAR (50) NOT NULL,
    [ProjectId]              INT           NOT NULL,
    [CategoryId]             INT           NOT NULL,
    [SkillId]                INT           IDENTITY (1, 1) NOT NULL,
    [PayPlan]                NVARCHAR (3)  NOT NULL,
    [CategoryGroupCode]      NVARCHAR (10) NOT NULL,
    [CategorySubGroupCode]   NVARCHAR (10) NOT NULL,
    [GradeType]              NVARCHAR (3)  NOT NULL,
    [GradeLevel]             TINYINT       NOT NULL,
    [Type]                   NVARCHAR (5)  NULL,
    [AreaCode]               NVARCHAR (50) NULL,
    [LocalityId]             INT           NULL,
    [SpecialRateTableNumber] NVARCHAR (4)  NULL,
    [StateCountry]           NVARCHAR (50) NULL,
    [FunctionalAreaCode]     NVARCHAR (50) NULL,
    [CostCenterCode]         NVARCHAR (50) NULL,
    [activeDays]             SMALLINT      NULL,
    [overheadPct]            FLOAT (53)    NULL,
    CONSTRAINT [PK_PMCategorySkill] PRIMARY KEY CLUSTERED ([UserId] ASC, [ProjectId] ASC, [CategoryId] ASC, [SkillId] ASC, [PayPlan] ASC, [CategoryGroupCode] ASC, [CategorySubGroupCode] ASC, [GradeType] ASC, [GradeLevel] ASC)
);


GO
CREATE NONCLUSTERED INDEX [IX_PMCategorySkill]
    ON [webuser].[PMCategorySkill]([PayPlan] ASC, [LocalityId] ASC, [SpecialRateTableNumber] ASC, [StateCountry] ASC);

