CREATE TABLE [load_payschedule].[PayScheduleGL] (
    [PayPlan]       NVARCHAR (3)    NOT NULL,
    [GradeType]     NVARCHAR (3)    NOT NULL,
    [GradeLevel]    TINYINT         NOT NULL,
    [Step]          TINYINT         NOT NULL,
    [DateEffective] DATE            NOT NULL,
    [RateType]      NVARCHAR (25)   NOT NULL,
    [Rate]          NUMERIC (18, 2) NULL,
    CONSTRAINT [PK_PayScheduleGL] PRIMARY KEY CLUSTERED ([PayPlan] ASC, [GradeType] ASC, [GradeLevel] ASC, [Step] ASC, [DateEffective] ASC, [RateType] ASC),
    CONSTRAINT [FK_PayScheduleGL_PayPlan] FOREIGN KEY ([PayPlan]) REFERENCES [lookup].[PayPlan] ([PayPlan])
);

