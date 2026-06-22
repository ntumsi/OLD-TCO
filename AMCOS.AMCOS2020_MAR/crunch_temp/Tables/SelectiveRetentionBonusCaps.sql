CREATE TABLE [crunch_temp].[SelectiveRetentionBonusCaps] (
    [MOS]            NVARCHAR (3)    NOT NULL,
    [GradeLevel]     NVARCHAR (2)    NOT NULL,
    [Tier]           INT             NOT NULL,
    [BonusCap]       NUMERIC (16, 2) NULL,
    [AmcosVersionId] INT             NOT NULL
);

