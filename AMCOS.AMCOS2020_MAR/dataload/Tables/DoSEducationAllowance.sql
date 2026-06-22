CREATE TABLE [dataload].[DoSEducationAllowance] (
    [LocationCode]   NVARCHAR (50)   NOT NULL,
    [Type]           NVARCHAR (50)   NOT NULL,
    [Attribute]      NVARCHAR (50)   NOT NULL,
    [Amount]         NUMERIC (18, 2) NOT NULL,
    [AmcosVersionId] INT             NOT NULL,
    CONSTRAINT [PK_DoSEducationAllowance] PRIMARY KEY CLUSTERED ([LocationCode] ASC, [Type] ASC, [Attribute] ASC, [AmcosVersionId] ASC)
);





