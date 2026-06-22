CREATE TABLE [analysis].[RowCounts] (
    [SchemaName]    NVARCHAR (50) NOT NULL,
    [TableName]     NVARCHAR (50) NOT NULL,
    [TotalRowCount] BIGINT        NULL,
    CONSTRAINT [PK_RowCounts] PRIMARY KEY CLUSTERED ([SchemaName] ASC, [TableName] ASC)
);

