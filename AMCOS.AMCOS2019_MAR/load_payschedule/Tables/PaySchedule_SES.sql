CREATE TABLE [load_payschedule].[PaySchedule_SES] (
    [PayPlan]                  NVARCHAR (3)   NOT NULL,
    [OccupationalSeriesNumber] NVARCHAR (4)   NOT NULL,
    [GradeType]                NVARCHAR (3)   NOT NULL,
    [GradeLevel]               TINYINT        NOT NULL,
    [Step]                     TINYINT        NOT NULL,
    [DateEffective]            DATE           NOT NULL,
    [RateType]                 NVARCHAR (25)  NULL,
    [Rate]                     NUMERIC (8, 2) NULL,
    CONSTRAINT [PK_PaySchedule_SES_1] PRIMARY KEY CLUSTERED ([PayPlan] ASC, [OccupationalSeriesNumber] ASC, [GradeType] ASC, [GradeLevel] ASC, [Step] ASC, [DateEffective] ASC),
    CONSTRAINT [FK_PaySchedule_SES_tblDef_PayPlans] FOREIGN KEY ([PayPlan]) REFERENCES [lookup].[PayPlan] ([PayPlan])
);





