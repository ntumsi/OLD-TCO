CREATE TABLE [xwalk].[ATRRSATRMCrosswalk] (
    [ATRRS_Key]      NVARCHAR (200) NOT NULL,
    [ATRM_Key]       NVARCHAR (200) NOT NULL,
    [AmcosVersionId] INT            NOT NULL,
    CONSTRAINT [PK_ATRRSATRMCrosswalk] PRIMARY KEY CLUSTERED ([ATRRS_Key] ASC, [ATRM_Key] ASC, [AmcosVersionId] ASC)
);

