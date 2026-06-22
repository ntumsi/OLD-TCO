CREATE TABLE [xwalk].[OccupationalSeriesToCareerProgram] (
    [OccupationalSeriesNumber] NVARCHAR (4) NOT NULL,
    [CareerProgramNumber]      NCHAR (2)    NOT NULL,
    [AmcosVersionIdStart]      INT          NULL,
    [AmcosVersionIdEnd]        INT          NULL,
    CONSTRAINT [PK_OccupationalSeriesToCareerProgram] PRIMARY KEY CLUSTERED ([OccupationalSeriesNumber] ASC, [CareerProgramNumber] ASC)
);

