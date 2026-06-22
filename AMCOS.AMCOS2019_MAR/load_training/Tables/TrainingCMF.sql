CREATE TABLE [load_training].[TrainingCMF] (
    [PayPlan]        NVARCHAR (3)    NOT NULL,
    [CMF]            NCHAR (2)       NOT NULL,
    [CourseType]     NVARCHAR (4)    NOT NULL,
    [APPN]           NVARCHAR (25)   NOT NULL,
    [GradeType]      NVARCHAR (3)    NOT NULL,
    [GradeLevel]     TINYINT         NOT NULL,
    [WeaponSystemId] INT             NOT NULL,
    [Amount]         NUMERIC (26, 8) NULL,
    CONSTRAINT [PK_TrainingCMF_1] PRIMARY KEY CLUSTERED ([PayPlan] ASC, [CMF] ASC, [CourseType] ASC, [APPN] ASC, [GradeType] ASC, [GradeLevel] ASC, [WeaponSystemId] ASC)
);

