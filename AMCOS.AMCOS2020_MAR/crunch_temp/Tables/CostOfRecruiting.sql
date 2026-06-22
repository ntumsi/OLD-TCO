CREATE TABLE [crunch_temp].[CostOfRecruiting] (
    [PayPlan]                   NVARCHAR (3)    NOT NULL,
    [CategoryGroupCode]         NVARCHAR (4)    NOT NULL,
    [CategorySubGroupCode]      NVARCHAR (4)    NOT NULL,
    [GradeType]                 NVARCHAR (3)    NOT NULL,
    [GradeLevel]                TINYINT         NOT NULL,
    [Inventory]                 INT             NULL,
    [BonusAverageAnnualPay]     NUMERIC (16, 2) NULL,
    [bonus_avg_annual_payments] NUMERIC (16, 2) NULL,
    [BonusPayCap]               NUMERIC (16, 2) NULL,
    [bonus_capped_amt]          NUMERIC (16, 2) NULL,
    [CGLAInventory]             NUMERIC (16, 2) NULL,
    [CGLA_Bonus]                NUMERIC (16, 2) NULL,
    [MPA_recruiting]            NUMERIC (16, 2) NULL,
    [OMA_recruiting]            NUMERIC (16, 2) NULL,
    [MPA_total]                 NUMERIC (16, 2) NULL
);

