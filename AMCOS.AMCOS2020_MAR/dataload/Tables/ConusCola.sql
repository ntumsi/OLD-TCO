CREATE TABLE [dataload].[ConusCola] (
    [GradeType]      NVARCHAR (3)   NOT NULL,
    [GradeLevel]     TINYINT        NOT NULL,
    [YOS]            NVARCHAR (255) NOT NULL,
    [WithDependents] BIT            NOT NULL,
    [Amount]         NUMERIC (3)    NULL,
    [AmcosVersionId] INT            NOT NULL,
    CONSTRAINT [PK_ConusCola] PRIMARY KEY CLUSTERED ([GradeType] ASC, [GradeLevel] ASC, [YOS] ASC, [WithDependents] ASC, [AmcosVersionId] ASC)
);



