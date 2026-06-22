CREATE TABLE [PaySchedule].[DCPASNfRaw] (
    [PayBand]       TINYINT         NOT NULL,
    [PayMinAnnual]  NUMERIC (18, 2) NOT NULL,
    [PayMinHourly]  NUMERIC (18, 2) NOT NULL,
    [PayMaxAnnual]  NUMERIC (18, 2) NOT NULL,
    [PayMaxHourly]  NUMERIC (18, 2) NOT NULL,
    [WageSchedule]  NVARCHAR (3)    NOT NULL,
    [EffectiveDate] DATE            NOT NULL,
    [Link]          NVARCHAR (150)  NOT NULL,
    CONSTRAINT [PK_Payschedule_DCPASNfRaw] PRIMARY KEY CLUSTERED ([PayBand] ASC, [WageSchedule] ASC, [EffectiveDate] ASC, [Link] ASC) WITH (IGNORE_DUP_KEY = ON)
);

