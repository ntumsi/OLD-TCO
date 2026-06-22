CREATE TABLE [lookup].[ATRRSATRMCrosswalk] (
    [ATRRS_Key]      NVARCHAR (255) NOT NULL,
    [ATRM_Key]       NVARCHAR (255) NULL,
    [AmcosVersionId] INT            NOT NULL,
    CONSTRAINT [PK_ATRRSATRMCrosswalk] PRIMARY KEY CLUSTERED ([ATRRS_Key] ASC, [AmcosVersionId] ASC)
);



