CREATE TABLE [dataload].[MilitaryAccessions] (
    [PayPlan]        NVARCHAR (3) NOT NULL,
    [Param]          NVARCHAR (5) NOT NULL,
    [MOS]            NVARCHAR (3) NOT NULL,
    [GradeType]      NCHAR (1)    NOT NULL,
    [GradeLevel]     TINYINT      NOT NULL,
    [AmcosVersionId] INT          NOT NULL,
    [Amount]         FLOAT (53)   NOT NULL,
    CONSTRAINT [PK_MilitaryAccessions] PRIMARY KEY CLUSTERED ([PayPlan] ASC, [Param] ASC, [MOS] ASC, [GradeType] ASC, [GradeLevel] ASC),
    CONSTRAINT [FK_MilitaryAccessions_MOS] FOREIGN KEY ([MOS]) REFERENCES [lookup].[MOS] ([MOS]),
    CONSTRAINT [FK_MilitaryAccessions_Version] FOREIGN KEY ([AmcosVersionId]) REFERENCES [lookup].[AMCOSVersion] ([AmcosVersionId])
);



