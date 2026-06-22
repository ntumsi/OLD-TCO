CREATE TABLE [lookup].[AOCConversion] (
    [AOCOld]         NVARCHAR (3) NOT NULL,
    [AOCNew]         NVARCHAR (3) NOT NULL,
    [GradeLevel]     TINYINT      NOT NULL,
    [AmcosVersionId] INT          NOT NULL,
    CONSTRAINT [PK_AOCConversion] PRIMARY KEY CLUSTERED ([AOCOld] ASC, [GradeLevel] ASC, [AmcosVersionId] ASC)
);



