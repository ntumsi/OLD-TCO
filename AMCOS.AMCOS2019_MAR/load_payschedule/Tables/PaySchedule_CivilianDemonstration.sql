CREATE TABLE [load_payschedule].[PaySchedule_CivilianDemonstration] (
    [PayPlan]       NVARCHAR (3)    NOT NULL,
    [GradeType]     NVARCHAR (3)    NOT NULL,
    [PayBand]       TINYINT         NOT NULL,
    [Step]          NVARCHAR (3)    NOT NULL,
    [DateEffective] DATE            NOT NULL,
    [RateType]      NVARCHAR (25)   NOT NULL,
    [Rate]          NUMERIC (18, 2) NOT NULL,
    CONSTRAINT [PK_PaySchedule_CivilianDemonstration_1] PRIMARY KEY CLUSTERED ([PayPlan] ASC, [GradeType] ASC, [PayBand] ASC, [Step] ASC, [DateEffective] ASC, [RateType] ASC)
);

