CREATE TABLE [DMDC].[AMOSTABS] (
    [MOS]                       NVARCHAR (4) NULL,
    [PayPlan]                   NVARCHAR (3) NULL,
    [GradeType]                 NVARCHAR (3) NULL,
    [GradeLevel]                TINYINT      NULL,
    [YOS]                       VARCHAR (50) NULL,
    [Inventory]                 VARCHAR (50) NULL,
    [AFQT>=31_YOS>12]           VARCHAR (50) NULL,
    [AFQT>=31]                  VARCHAR (50) NULL,
    [PriorServiceYOS>=12Months] VARCHAR (50) NULL,
    [AvgYOS_NPS]                VARCHAR (50) NULL
);

