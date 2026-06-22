CREATE TABLE [crunch_temp].[CostOfOfficerAcquisitionByAoc] (
    [PayPlan]              NVARCHAR (3)    NOT NULL,
    [CategoryGroupCode]    NVARCHAR (4)    NOT NULL,
    [CategorySubGroupCode] NVARCHAR (4)    NOT NULL,
    [GradeType]            NVARCHAR (3)    NOT NULL,
    [GradeLevel]           TINYINT         NOT NULL,
    [inv]                  INT             NULL,
    [CGLAInventory]        NUMERIC (16, 2) NULL,
    [ofc_acq_mpa]          NUMERIC (16, 2) NULL,
    [ofc_acq_oma]          NUMERIC (16, 2) NULL,
    [bonus_mpa]            NUMERIC (16, 2) NULL,
    [CGLA_bonus_mpa]       NUMERIC (16, 2) NULL
);

