CREATE TABLE [dataload].[BAHRates] (
    [MHA]            NVARCHAR (5)   NOT NULL,
    [GradeType]      NVARCHAR (3)   NOT NULL,
    [GradeLevel]     TINYINT        NOT NULL,
    [WithDependents] BIT            NOT NULL,
    [Amount]         NUMERIC (7, 2) NULL,
    [AmcosVersionId] INT            NOT NULL,
    CONSTRAINT [PK_BAHRates] PRIMARY KEY CLUSTERED ([MHA] ASC, [GradeType] ASC, [GradeLevel] ASC, [WithDependents] ASC, [AmcosVersionId] ASC)
);



