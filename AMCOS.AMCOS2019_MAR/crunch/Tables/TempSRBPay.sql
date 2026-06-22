CREATE TABLE [crunch].[TempSRBPay] (
    [PayPlan]              NVARCHAR (3) NOT NULL,
    [CategoryGroupCode]    NVARCHAR (4) NOT NULL,
    [CategorySubGroupCode] NVARCHAR (4) NOT NULL,
    [GradeType]            NVARCHAR (3) NOT NULL,
    [GradeLevel]           TINYINT      NOT NULL,
    [Inventory]            INT          NOT NULL,
    [CGLAInventory]        INT          NOT NULL,
    [avg_annual_pay]       FLOAT (53)   NOT NULL,
    [pay_cap]              FLOAT (53)   NOT NULL,
    [CGLA_MPA_Pay]         FLOAT (53)   NOT NULL
);

