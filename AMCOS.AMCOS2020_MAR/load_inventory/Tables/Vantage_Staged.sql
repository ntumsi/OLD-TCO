CREATE TABLE [load_inventory].[Vantage_Staged] (
    [CivType]          NVARCHAR (3)  NULL,
    [PayPlan]          NVARCHAR (3)  NULL,
    [CategoryGroup]    NVARCHAR (20) NULL,
    [CategorySubgroup] NVARCHAR (4)  NULL,
    [Quality]          NCHAR (1)     NULL,
    [GradeType]        NVARCHAR (2)  NULL,
    [GradeLevel]       NVARCHAR (2)  NULL,
    [Step]             NVARCHAR (2)  NULL,
    [UIC]              NVARCHAR (20) NULL,
    [YOS]              SMALLINT      NULL,
    [Count]            SMALLINT      NULL,
    [DutyLocationCode] NCHAR (9)     NULL,
    [RCC]              NCHAR (1)     NULL,
    [AmcosVersionId]   INT           NULL
);

