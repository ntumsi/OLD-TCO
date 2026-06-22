CREATE TABLE [data].[AsafmcJointInflationRates] (
    [ConversionType] NVARCHAR (25)    NOT NULL,
    [BaseYear]       NVARCHAR (4)     NOT NULL,
    [TargetYear]     NVARCHAR (4)     NOT NULL,
    [Appropriation]  NVARCHAR (25)    NOT NULL,
    [Amount]         NUMERIC (18, 15) NOT NULL,
    [AmcosVersionId] INT              NOT NULL,
    CONSTRAINT [PK_AsafmcJointInflationRates] PRIMARY KEY CLUSTERED ([ConversionType] ASC, [BaseYear] ASC, [TargetYear] ASC, [Appropriation] ASC, [AmcosVersionId] ASC)
);

