CREATE TABLE [xwalk].[ZIPToMHA] (
    [ZIPCode]        NVARCHAR (5) NOT NULL,
    [MHA]            NVARCHAR (5) NOT NULL,
    [AmcosVersionId] INT          NOT NULL,
    CONSTRAINT [PK_ZIPToMHA] PRIMARY KEY CLUSTERED ([ZIPCode] ASC, [MHA] ASC, [AmcosVersionId] ASC)
);










GO



GO


