CREATE TABLE [crunch_temp].[Training_xwalk_atrrs_atrm] (
    [ATRM_Key]       NVARCHAR (50) NOT NULL,
    [ATRRS_Key]      NVARCHAR (50) NOT NULL,
    [AmcosVersionId] INT           NOT NULL,
    CONSTRAINT [PK_TempTraining_xwalk_atrrs_atrm] PRIMARY KEY NONCLUSTERED ([ATRM_Key] ASC, [ATRRS_Key] ASC, [AmcosVersionId] ASC)
);


GO
CREATE CLUSTERED INDEX [ClusteredIndex-20240729-194418]
    ON [crunch_temp].[Training_xwalk_atrrs_atrm]([ATRM_Key] ASC, [ATRRS_Key] ASC, [AmcosVersionId] ASC);

