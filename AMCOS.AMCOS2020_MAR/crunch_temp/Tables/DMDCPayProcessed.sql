CREATE TABLE [crunch_temp].[DMDCPayProcessed] (
    [PayType]              NVARCHAR (50)   NULL,
    [PayPlan]              NVARCHAR (3)    NULL,
    [CategoryGroupCode]    NVARCHAR (4)    NULL,
    [CategorySubgroupCode] NVARCHAR (4)    NULL,
    [GradeType]            NVARCHAR (3)    NULL,
    [GradeLevel]           TINYINT         NULL,
    [avg_cost]             NUMERIC (16, 2) NULL,
    [AmcosVersionId]       INT             NULL,
    [avg_annual_pay]       NUMERIC (16, 2) NULL,
    [avg_annual_payments]  NUMERIC (16, 2) NULL,
    [pay_cap]              NUMERIC (16, 2) NULL,
    [capped_avg_mpa_pay]   NUMERIC (16, 2) NULL
);


GO
CREATE NONCLUSTERED INDEX [NonClusteredIndex-20250626-140417]
    ON [crunch_temp].[DMDCPayProcessed]([PayPlan] ASC, [CategoryGroupCode] ASC, [CategorySubgroupCode] ASC, [GradeLevel] ASC);

