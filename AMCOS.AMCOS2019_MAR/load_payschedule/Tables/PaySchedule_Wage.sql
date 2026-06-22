CREATE TABLE [load_payschedule].[PaySchedule_Wage] (
    [PayPlan]       NVARCHAR (3)    NOT NULL,
    [WageArea]      NVARCHAR (3)    NOT NULL,
    [GradeType]     NVARCHAR (3)    NOT NULL,
    [GradeLevel]    TINYINT         NOT NULL,
    [Step]          TINYINT         NOT NULL,
    [DateEffective] DATE            NOT NULL,
    [RateType]      NVARCHAR (25)   NULL,
    [Rate]          NUMERIC (18, 2) NULL,
    CONSTRAINT [PK_PaySchedule_Wage] PRIMARY KEY CLUSTERED ([PayPlan] ASC, [WageArea] ASC, [GradeType] ASC, [GradeLevel] ASC, [Step] ASC, [DateEffective] ASC),
    CONSTRAINT [FK_PaySchedule_Wage_WageArea] FOREIGN KEY ([WageArea]) REFERENCES [lookup].[WageArea] ([WageArea])
);

