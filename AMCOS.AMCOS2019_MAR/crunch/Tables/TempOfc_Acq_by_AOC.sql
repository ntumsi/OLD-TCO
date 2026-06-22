CREATE TABLE [crunch].[TempOfc_Acq_by_AOC] (
    [PayPlan]              NVARCHAR (3) NOT NULL,
    [CategoryGroupCode]    NVARCHAR (4) NOT NULL,
    [CategorySubGroupCode] NVARCHAR (4) NOT NULL,
    [GradeType]            NVARCHAR (3) NOT NULL,
    [GradeLevel]           TINYINT      NOT NULL,
    [inv]                  INT          NULL,
    [CGLA_inv]             FLOAT (53)   NULL,
    [ofc_acq_mpa]          FLOAT (53)   NULL,
    [ofc_acq_oma]          FLOAT (53)   NULL,
    [bonus_mpa]            FLOAT (53)   NULL,
    [CGLA_bonus_mpa]       FLOAT (53)   NULL
);

