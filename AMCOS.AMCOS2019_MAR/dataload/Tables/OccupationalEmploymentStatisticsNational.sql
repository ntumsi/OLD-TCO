CREATE TABLE [dataload].[OccupationalEmploymentStatisticsNational] (
    [SOC]       NVARCHAR (7)   NOT NULL,
    [TOT_EMP]   INT            NOT NULL,
    [EMP_PRSE]  NUMERIC (5, 2) NOT NULL,
    [A_MEAN]    NUMERIC (18)   NOT NULL,
    [MEAN_PRSE] NUMERIC (5, 2) NOT NULL,
    [A_PCT10]   NUMERIC (18)   NOT NULL,
    [A_PCT25]   NUMERIC (18)   NOT NULL,
    [A_MEDIAN]  NUMERIC (18)   NOT NULL,
    [A_PCT75]   NUMERIC (18)   NOT NULL,
    [A_PCT90]   NUMERIC (18)   NOT NULL,
    CONSTRAINT [PK_OccupationalEmploymentStatisticsNational_1] PRIMARY KEY CLUSTERED ([SOC] ASC)
);

