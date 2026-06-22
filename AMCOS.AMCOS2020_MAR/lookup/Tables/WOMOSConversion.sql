CREATE TABLE [lookup].[WOMOSConversion] (
    [WOMOSOld]       NVARCHAR (4) NOT NULL,
    [WOMOSNew]       NVARCHAR (4) NOT NULL,
    [GradeLevel]     TINYINT      NOT NULL,
    [AmcosVersionId] INT          NOT NULL,
    CONSTRAINT [PK_WOMOSConversion] PRIMARY KEY CLUSTERED ([WOMOSOld] ASC, [GradeLevel] ASC, [AmcosVersionId] ASC)
);

