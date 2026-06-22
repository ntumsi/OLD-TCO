CREATE TABLE [dataload].[NonLocalityBAHRates] (
    [GradeType]             NVARCHAR (3)   NOT NULL,
    [GradeLevel]            TINYINT        NOT NULL,
    [RatePartial]           NUMERIC (7, 2) NULL,
    [RateWithoutDependents] NUMERIC (7, 2) NULL,
    [RateWithDependents]    NUMERIC (7, 2) NULL,
    [RateDifferential]      NUMERIC (7, 2) NULL,
    [AmcosVersionId]        INT            NOT NULL,
    CONSTRAINT [PK_NonLocalityBAHRates] PRIMARY KEY CLUSTERED ([GradeType] ASC, [GradeLevel] ASC, [AmcosVersionId] ASC)
);



