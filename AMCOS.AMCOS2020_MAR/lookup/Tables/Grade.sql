CREATE TABLE [lookup].[Grade] (
    [PayPlan]                   NVARCHAR (3) NOT NULL,
    [GradeType]                 NVARCHAR (3) NOT NULL,
    [GradeLevel]                TINYINT      NOT NULL,
    [CareerTrainingWindowYears] TINYINT      NULL,
    [AmcosVersionIdStart]       INT          NULL,
    [AmcosVersionIdEnd]         INT          NOT NULL,
    CONSTRAINT [PK_Grade] PRIMARY KEY CLUSTERED ([PayPlan] ASC, [GradeType] ASC, [GradeLevel] ASC, [AmcosVersionIdEnd] ASC)
);



