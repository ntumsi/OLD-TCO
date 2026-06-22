CREATE TABLE [webuser].[PMCategorySkill] (
    [SkillId]                 INT            IDENTITY (1, 1) NOT NULL,
    [CategoryId]              INT            NOT NULL,
    [Uic]                     NVARCHAR (6)   NULL,
    [PayPlan]                 NVARCHAR (3)   NOT NULL,
    [CategoryGroupCode]       NVARCHAR (10)  NOT NULL,
    [CategorySubgroupCode]    NVARCHAR (10)  NOT NULL,
    [CareerProgramNumber]     NCHAR (2)      NOT NULL,
    [LocationId]              INT            NOT NULL,
    [LocationText]            NVARCHAR (150) NOT NULL,
    [STRL]                    NVARCHAR (20)  NOT NULL,
    [GradeLevel]              TINYINT        NOT NULL,
    [DependentStatus]         NVARCHAR (25)  NOT NULL,
    [NumberOfDependents]      INT            NOT NULL,
    [ActiveDutyDays]          SMALLINT       NOT NULL,
    [OverheadPercent]         FLOAT (53)     NOT NULL,
    [_Type]                   NVARCHAR (5)   NULL,
    [_AreaCode]               NVARCHAR (50)  NULL,
    [_LocalityId]             INT            NULL,
    [_SpecialRateTableNumber] NVARCHAR (4)   NULL,
    [_StateCountry]           NVARCHAR (50)  NULL,
    [_FunctionalAreaCode]     NVARCHAR (50)  NULL,
    [_CostCenterCode]         NVARCHAR (50)  NULL,
    CONSTRAINT [PK_PMCategorySkill] PRIMARY KEY CLUSTERED ([SkillId] ASC)
);






















GO
CREATE NONCLUSTERED INDEX [IX_PMCategorySkill_AddUnit]
    ON [webuser].[PMCategorySkill]([CategoryId] ASC, [PayPlan] ASC, [CategoryGroupCode] ASC, [CategorySubgroupCode] ASC, [CareerProgramNumber] ASC, [LocationId] ASC, [LocationText] ASC, [STRL] ASC, [GradeLevel] ASC, [DependentStatus] ASC, [NumberOfDependents] ASC, [ActiveDutyDays] ASC, [OverheadPercent] ASC);

