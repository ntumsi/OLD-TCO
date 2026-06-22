CREATE TABLE [xwalk].[GradeLevel] (
    [BasePayPlan]         NVARCHAR (3)   NOT NULL,
    [BaseGradeLevel_low]  NVARCHAR (10)  NOT NULL,
    [BaseGradeLevel_high] NVARCHAR (10)  NOT NULL,
    [TargetPayPlan]       NVARCHAR (3)   NOT NULL,
    [TargetGradeLevel]    NVARCHAR (10)  NOT NULL,
    [Source]              NVARCHAR (500) NOT NULL,
    [AmcosVersionIdStart] INT            NOT NULL,
    [AmcosVersionIdEnd]   INT            NOT NULL,
    CONSTRAINT [PK_xwalkGradeLevel] PRIMARY KEY CLUSTERED ([BasePayPlan] ASC, [BaseGradeLevel_low] ASC, [BaseGradeLevel_high] ASC, [TargetPayPlan] ASC, [TargetGradeLevel] ASC, [AmcosVersionIdEnd] ASC)
);

