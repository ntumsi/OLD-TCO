CREATE TABLE [crunch].[DMDCPayProcessed] (
    [PayPlan]              NVARCHAR (3)  NULL,
    [CategoryGroupCode]    NVARCHAR (4)  NULL,
    [CategorySubgroupCode] NVARCHAR (4)  NULL,
    [GradeType]            NVARCHAR (3)  NULL,
    [GradeLevel]           TINYINT       NULL,
    [PayType]              NVARCHAR (50) NULL,
    [avg_cost]             FLOAT (53)    NULL,
    [avg_annual_pay]       FLOAT (53)    NULL,
    [avg_annual_payments]  FLOAT (53)    NULL,
    [AmcosVersionId]       INT           NULL
);





