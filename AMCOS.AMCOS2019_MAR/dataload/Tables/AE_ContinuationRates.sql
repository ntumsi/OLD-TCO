CREATE TABLE [dataload].[AE_ContinuationRates] (
    [CMF]    NCHAR (2)  NOT NULL,
    [YOS]    TINYINT    NOT NULL,
    [Amount] FLOAT (53) NULL,
    CONSTRAINT [PK_tblData_AE_ContinuationRates] PRIMARY KEY CLUSTERED ([CMF] ASC, [YOS] ASC)
);

