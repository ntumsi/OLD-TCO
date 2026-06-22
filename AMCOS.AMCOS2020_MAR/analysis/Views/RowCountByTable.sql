
CREATE VIEW [analysis].[RowCountByTable]
AS
SELECT QUOTENAME(SCHEMA_NAME(sOBJ.schema_id)) + '.' + QUOTENAME(sOBJ.name) AS [TableName],
       SUM(sPTN.rows) AS [RowCount]
FROM sys.objects AS sOBJ
    INNER JOIN sys.partitions AS sPTN
        ON sOBJ.object_id = sPTN.object_id
WHERE sOBJ.type = 'U'
      AND sOBJ.is_ms_shipped = 0x0
      AND sPTN.index_id < 2 -- 0:Heap, 1:Clustered
GROUP BY sOBJ.schema_id,
         sOBJ.name;