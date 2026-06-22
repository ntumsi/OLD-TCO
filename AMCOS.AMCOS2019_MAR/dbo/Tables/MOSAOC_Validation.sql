CREATE TABLE [dbo].[MOSAOC_Validation] (
    [MOS]            NVARCHAR (4) NOT NULL,
    [GradeType]      NVARCHAR (3) NOT NULL,
    [GradeLevel]     TINYINT      NOT NULL,
    [AmcosVersionId] INT          NOT NULL,
    [Value]          CHAR (1)     NULL,
    CONSTRAINT [PK_MOSAOC_Validation] PRIMARY KEY CLUSTERED ([MOS] ASC, [GradeType] ASC, [GradeLevel] ASC, [AmcosVersionId] ASC)
);







