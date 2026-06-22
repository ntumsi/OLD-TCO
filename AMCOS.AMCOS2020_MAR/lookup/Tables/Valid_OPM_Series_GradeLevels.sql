CREATE TABLE [lookup].[Valid_OPM_Series_GradeLevels] (
    [Series]              NVARCHAR (4) NOT NULL,
    [GradeLevel]          INT          NOT NULL,
    [Valid]               BIT          NOT NULL,
    [amcosversionidstart] INT          NOT NULL,
    [amcosversionidend]   INT          NOT NULL,
    CONSTRAINT [PK_Valid_OPM_Series_GradeLevels] PRIMARY KEY CLUSTERED ([Series] ASC, [GradeLevel] ASC, [amcosversionidstart] ASC, [amcosversionidend] ASC)
);

