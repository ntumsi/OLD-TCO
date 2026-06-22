CREATE TABLE [load_payschedule].[PaySchedule_GS] (
    [PayPlan]       NVARCHAR (3)    NOT NULL,
    [GradeType]     NVARCHAR (3)    NOT NULL,
    [GradeLevel]    TINYINT         NOT NULL,
    [Step]          TINYINT         NOT NULL,
    [DateEffective] DATE            NOT NULL,
    [RateType]      NVARCHAR (25)   NOT NULL,
    [Rate]          NUMERIC (10, 2) NULL,
    CONSTRAINT [PK_PaySchedule_GS_1] PRIMARY KEY CLUSTERED ([PayPlan] ASC, [GradeType] ASC, [GradeLevel] ASC, [Step] ASC, [DateEffective] ASC, [RateType] ASC),
    CONSTRAINT [FK_PaySchedule_GS_tblDef_PayPlans] FOREIGN KEY ([PayPlan]) REFERENCES [lookup].[PayPlan] ([PayPlan])
);



