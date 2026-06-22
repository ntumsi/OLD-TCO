CREATE TABLE [crunch_temp].[DMDCBonus] (
    [PayType]             NVARCHAR (50) NULL,
    [PayPlan]             NVARCHAR (3)  NULL,
    [CMF]                 NVARCHAR (2)  NULL,
    [subgrp]              NVARCHAR (4)  NULL,
    [GradeType]           NVARCHAR (2)  NULL,
    [GradeLevel]          NVARCHAR (2)  NULL,
    [avg_cost]            FLOAT (53)    NULL,
    [AmcosVersionId]      INT           NULL,
    [avg_annual_pay]      FLOAT (53)    NULL,
    [avg_annual_payments] FLOAT (53)    NULL,
    [pay_cap]             FLOAT (53)    NULL,
    [capped_avg_mpa_pay]  FLOAT (53)    NULL
);

