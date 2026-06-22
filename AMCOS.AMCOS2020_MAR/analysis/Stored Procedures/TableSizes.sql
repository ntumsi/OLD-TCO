

-- =============================================
-- Author:Dan Hogan
-- Create date: 8/18/2020
-- Description:	Computes and displays the table sizes on disk
-- =============================================

CREATE PROCEDURE [analysis].[TableSizes]
AS
BEGIN
    CREATE TABLE #tmpTableSizes
    (
        TableName VARCHAR(100),
        NumberOfRows VARCHAR(100),
        ReservedSize VARCHAR(50),
        DataSize VARCHAR(50),
        IndexSize VARCHAR(50),
        UnusedSize VARCHAR(50)
    );
    INSERT #tmpTableSizes
    EXEC sp_MSforeachtable @command1 = "EXEC sp_spaceused '?'";


    SELECT TableName,
           NumberOfRows,
           ReservedSize,
           DataSize,
           IndexSize,
           UnusedSize
    FROM #tmpTableSizes
    ORDER BY CAST(LEFT(ReservedSize, LEN(ReservedSize) - 4) AS INT) DESC;


END;