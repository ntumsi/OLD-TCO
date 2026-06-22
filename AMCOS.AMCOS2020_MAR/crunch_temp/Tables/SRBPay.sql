CREATE TABLE [crunch_temp].[SRBPay] (
    [PayPlan]              NVARCHAR (3)    NOT NULL,
    [CategoryGroupCode]    NVARCHAR (4)    NOT NULL,
    [CategorySubgroupCode] NVARCHAR (4)    NOT NULL,
    [GradeType]            NVARCHAR (3)    NOT NULL,
    [GradeLevel]           TINYINT         NOT NULL,
    [Inventory]            INT             NOT NULL,
    [CGLAInventory]        INT             NOT NULL,
    [avg_annual_pay]       NUMERIC (16, 2) NOT NULL,
    [pay_cap]              NUMERIC (16, 2) NOT NULL,
    [CGLA_MPA_Pay]         NUMERIC (16, 2) NOT NULL
);

