CREATE TABLE [lookup].[ArmyCareerProgram] (
    [CareerProgramNumber] NCHAR (2)     NOT NULL,
    [Title]               NVARCHAR (75) NULL,
    [AmcosVersionIdStart] INT           NULL,
    [AmcosVersionIdEnd]   INT           NOT NULL,
    CONSTRAINT [PK_CareerProgram] PRIMARY KEY CLUSTERED ([CareerProgramNumber] ASC, [AmcosVersionIdEnd] ASC)
);

