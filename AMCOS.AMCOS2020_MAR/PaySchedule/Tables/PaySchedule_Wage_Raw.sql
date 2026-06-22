CREATE TABLE [PaySchedule].[PaySchedule_Wage_Raw] (
    [AreaCode]      NVARCHAR (3)    NOT NULL,
    [TypeData]      NVARCHAR (1)    NOT NULL,
    [SurveyNumber]  NVARCHAR (50)   NOT NULL,
    [TypeSchedule]  NVARCHAR (1)    NOT NULL,
    [Level]         NVARCHAR (1)    NOT NULL,
    [Grade]         TINYINT         NOT NULL,
    [rate1]         NUMERIC (18, 2) NOT NULL,
    [ind1]          NVARCHAR (50)   NULL,
    [rate2]         NUMERIC (18, 2) NOT NULL,
    [ind2]          NVARCHAR (50)   NULL,
    [rate3]         NUMERIC (18, 2) NOT NULL,
    [ind3]          NVARCHAR (50)   NULL,
    [rate4]         NUMERIC (18, 2) NULL,
    [ind4]          NVARCHAR (50)   NULL,
    [rate5]         NUMERIC (18, 2) NULL,
    [ind5]          NVARCHAR (50)   NULL,
    [EffectiveDate] DATE            NOT NULL,
    [FundType]      NVARCHAR (50)   NOT NULL,
    [link]          NVARCHAR (100)  NOT NULL,
    CONSTRAINT [PK_PaySchedule_Wage_Raw_1] PRIMARY KEY CLUSTERED ([AreaCode] ASC, [TypeData] ASC, [SurveyNumber] ASC, [TypeSchedule] ASC, [Level] ASC, [Grade] ASC, [EffectiveDate] ASC, [FundType] ASC, [link] ASC)
);

