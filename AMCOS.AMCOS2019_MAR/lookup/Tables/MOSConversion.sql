CREATE TABLE [lookup].[MOSConversion] (
    [MOSOld]         NVARCHAR (3) NOT NULL,
    [MOSNew]         NVARCHAR (3) NOT NULL,
    [GradeLevel]     TINYINT      NOT NULL,
    [AmcosVersionId] INT          NOT NULL,
    CONSTRAINT [PK_MOSConversion] PRIMARY KEY CLUSTERED ([MOSOld] ASC, [GradeLevel] ASC, [AmcosVersionId] ASC)
);



