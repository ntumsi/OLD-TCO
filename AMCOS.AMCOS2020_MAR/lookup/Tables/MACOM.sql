CREATE TABLE [lookup].[MACOM] (
    [Macom]       CHAR (2)  NOT NULL,
    [Macom_Name]  CHAR (20) NOT NULL,
    [Description] CHAR (50) NOT NULL,
    CONSTRAINT [PK_MACOM] PRIMARY KEY CLUSTERED ([Macom] ASC)
);

