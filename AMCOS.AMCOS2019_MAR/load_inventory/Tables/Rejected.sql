CREATE TABLE [load_inventory].[Rejected] (
    [PayPlan]          NVARCHAR (3)  NOT NULL,
    [CategoryGroup]    NVARCHAR (50) NULL,
    [CategorySubgroup] NVARCHAR (50) NULL,
    [Quality]          TINYINT       NULL,
    [GradeType]        NVARCHAR (3)  NULL,
    [Grade]            NVARCHAR (2)  NULL,
    [Step]             NVARCHAR (2)  NULL,
    [YOS]              TINYINT       NOT NULL,
    [Count]            INT           NOT NULL
);



