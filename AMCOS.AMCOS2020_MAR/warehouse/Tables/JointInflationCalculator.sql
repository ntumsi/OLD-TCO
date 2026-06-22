CREATE TABLE [warehouse].[JointInflationCalculator] (
    [ConversionType] NVARCHAR (25)    NOT NULL,
    [BaseYear]       NVARCHAR (4)     NOT NULL,
    [TargetYear]     NVARCHAR (4)     NOT NULL,
    [Appropriation]  NVARCHAR (25)    NOT NULL,
    [Amount]         NUMERIC (18, 15) NOT NULL,
    CONSTRAINT [PK_JointInflationCalculator] PRIMARY KEY CLUSTERED ([ConversionType] ASC, [BaseYear] ASC, [TargetYear] ASC, [Appropriation] ASC)
);

