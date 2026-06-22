CREATE TABLE [warehouse].[PPXwalk] (
    [GS_SES_BasePayPlan]      NVARCHAR (3)  NOT NULL,
    [GS_SES_BaseGradeLevel]   NVARCHAR (10) NOT NULL,
    [GS_SES_BaseSubgroupCode] NVARCHAR (5)  NOT NULL,
    [GS_SES_BaseLocationID]   INT           NOT NULL,
    [TargetPayPlan]           NVARCHAR (3)  NOT NULL,
    [TargetGradeLevel]        NVARCHAR (10) NOT NULL,
    [TargetSubgroupCode]      NVARCHAR (10) NOT NULL,
    [TargetLocationID]        INT           NOT NULL,
    [TargetSTRL]              NVARCHAR (20) NOT NULL,
    CONSTRAINT [PK_xwalkGradeLevel] PRIMARY KEY CLUSTERED ([GS_SES_BasePayPlan] ASC, [GS_SES_BaseGradeLevel] ASC, [GS_SES_BaseSubgroupCode] ASC, [GS_SES_BaseLocationID] ASC, [TargetPayPlan] ASC, [TargetGradeLevel] ASC, [TargetSubgroupCode] ASC, [TargetLocationID] ASC, [TargetSTRL] ASC)
);

