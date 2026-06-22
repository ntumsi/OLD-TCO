CREATE TABLE [crunch].[TimeInGrade] (
    [PayPlan]        NVARCHAR (3)   NOT NULL,
    [GradeLevel]     INT            NOT NULL,
    [MedianYoS]      NUMERIC (6, 1) NOT NULL,
    [TIG]            NUMERIC (6, 1) NOT NULL,
    [AmcosVersionId] INT            NOT NULL,
    CONSTRAINT [PK_TimeInGrade] PRIMARY KEY CLUSTERED ([PayPlan] ASC, [GradeLevel] ASC, [AmcosVersionId] ASC)
);



