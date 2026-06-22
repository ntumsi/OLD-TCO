CREATE TABLE [crunch].[OpmCaProcessed] (
    [PayPlan]               NVARCHAR (3)    NOT NULL,
    [Gradelevel]            TINYINT         NOT NULL,
    [GradeLevelDescription] NVARCHAR (20)   NOT NULL,
    [LocationId]            INT             NOT NULL,
    [RateType]              NVARCHAR (25)   NOT NULL,
    [Rate]                  NUMERIC (18, 2) NOT NULL,
    [AmcosVersionId]        INT             NOT NULL,
    CONSTRAINT [PK_PayScheduleCa] PRIMARY KEY CLUSTERED ([PayPlan] ASC, [Gradelevel] ASC, [LocationId] ASC, [AmcosVersionId] ASC)
);

