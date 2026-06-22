CREATE TABLE [crunch].[TempDMDCPayProcessed] (
    [PayType]              NVARCHAR (50) NULL,
    [PayPlan]              NVARCHAR (3)  NULL,
    [CategoryGroupCode]    NVARCHAR (4)  NULL,
    [CategorySubgroupCode] NVARCHAR (4)  NULL,
    [GradeType]            NVARCHAR (3)  NULL,
    [GradeLevel]           TINYINT       NULL,
    [avg_cost]             FLOAT (53)    NULL,
    [AmcosVersionId]       INT           NULL,
    [avg_annual_pay]       FLOAT (53)    NULL,
    [avg_annual_payments]  FLOAT (53)    NULL,
    [pay_cap]              FLOAT (53)    NULL,
    [capped_avg_mpa_pay]   FLOAT (53)    NULL
);

