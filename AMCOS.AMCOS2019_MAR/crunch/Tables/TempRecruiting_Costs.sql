CREATE TABLE [crunch].[TempRecruiting_Costs] (
    [PayPlan]                   NVARCHAR (3) NOT NULL,
    [CategoryGroupCode]         NVARCHAR (4) NOT NULL,
    [CategorySubGroupCode]      NVARCHAR (4) NOT NULL,
    [GradeType]                 NVARCHAR (3) NOT NULL,
    [GradeLevel]                TINYINT      NOT NULL,
    [Inventory]                 INT          NULL,
    [bonus_avg_annual_pay]      FLOAT (53)   NULL,
    [bonus_avg_annual_payments] FLOAT (53)   NULL,
    [bonus_pay_cap]             FLOAT (53)   NULL,
    [bonus_capped_amt]          FLOAT (53)   NULL,
    [CGLA_inv]                  FLOAT (53)   NULL,
    [CGLA_Bonus]                FLOAT (53)   NULL,
    [MPA_recruiting]            FLOAT (53)   NULL,
    [OMA_recruiting]            FLOAT (53)   NULL,
    [MPA_total]                 FLOAT (53)   NULL
);

