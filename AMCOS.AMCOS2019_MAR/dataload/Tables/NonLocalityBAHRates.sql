CREATE TABLE [dataload].[NonLocalityBAHRates] (
    [AmcosVersionId]        INT            NOT NULL,
    [GradeType]             NVARCHAR (3)   NOT NULL,
    [GradeLevel]            TINYINT        NOT NULL,
    [RatePartial]           NUMERIC (7, 2) NULL,
    [RateWithoutDependents] NUMERIC (7, 2) NULL,
    [RateWithDependents]    NUMERIC (7, 2) NULL,
    [RateDifferential]      NUMERIC (7, 2) NULL,
    CONSTRAINT [PK_NonLocalityBAHRates] PRIMARY KEY CLUSTERED ([AmcosVersionId] ASC, [GradeType] ASC, [GradeLevel] ASC)
);



