

CREATE PROCEDURE [crunch].[CopyValues]
    @AmcosVersionIdNew INT = -1,   --the new version of data you want to create
    @AmcosVersionIdPrior INT = -1, --the version of data you want to copy
    @Debug BINARY = 1              --1=only print the statements to be run; 0=execute the statements

/* Copy values from one version and insert them as a new version.
   This facilitates running the next version's crunches without having all of the next version's data */
AS
BEGIN
    IF @AmcosVersionIdNew <= @AmcosVersionIdPrior
        RAISERROR('copy to (new) must be greater than the prior versionid', 18, 1);
    ELSE
    BEGIN
        DECLARE @data_table VARCHAR(50);
        DECLARE data CURSOR FOR

        /* get a list of all tables with the amcosversionid column for particular schemas */
        SELECT TABLE_SCHEMA + '.' + TABLE_NAME
        FROM INFORMATION_SCHEMA.COLUMNS
        WHERE TABLE_SCHEMA IN ( 'crunch', 'dataload', 'data', 'DMDC', 'load_inventory', 'PaySchedule',
                                'load_training', 'lookup', 'xwalk', 'BLS_OES', 'BLS_ECT', 'load_GFEBS', 'PaySchedule'
                              )
              AND COLUMN_NAME = 'amcosversionid'
              -- don't try to do an insert on a view
              AND TABLE_NAME IN
                  (
                      SELECT TABLE_NAME
                      FROM INFORMATION_SCHEMA.TABLES
                      WHERE TABLE_TYPE <> 'VIEW'
                  )
        ORDER BY TABLE_SCHEMA,
                 TABLE_NAME;
        /* begin iterating through the list of tables */
        OPEN data;
        FETCH NEXT FROM data
        INTO @data_table;

        DECLARE @outerloop INT = @@fetch_status;
        WHILE (@outerloop = 0)
        BEGIN
            DECLARE @tableschema VARCHAR(50) = LEFT(@data_table, CHARINDEX('.', @data_table) - 1);
            DECLARE @tablename VARCHAR(50) = RIGHT(@data_table, LEN(@data_table) - CHARINDEX('.', @data_table));
            DECLARE @insertsql VARCHAR(MAX);
            DECLARE @selectsql VARCHAR(MAX);
            DECLARE @deletesql VARCHAR(MAX);
            DECLARE @finalsql VARCHAR(MAX);

            --first step is to clear out any data already there for the insertversion
            SET @deletesql
                = 'DELETE FROM ' + @data_table + ' WHERE AmcosVersionId=' + CAST(@AmcosVersionIdNew AS VARCHAR(6));
            --IF @Debug = 1
            PRINT @deletesql;
            IF @Debug = 0
                EXEC (@deletesql);

            /* prepare for the insert script */
            SET @insertsql = 'INSERT INTO ' + @data_table + '( ';
            SET @selectsql = ' SELECT ';

            /* begin iterating through the list of columns in the current table */
            DECLARE @mycolumn AS VARCHAR(50);
            DECLARE mycolumns CURSOR FOR
            SELECT COLUMN_NAME
            FROM INFORMATION_SCHEMA.COLUMNS
            WHERE TABLE_NAME = @tablename
                  AND TABLE_SCHEMA = @tableschema;

            OPEN mycolumns;
            FETCH NEXT FROM mycolumns
            INTO @mycolumn;

            DECLARE @innerloop INT = @@fetch_status;
            WHILE (@innerloop = 0)
            BEGIN
                DECLARE @validcolumn BIT = 1; --tell us whether we used the current column
                /* if the current column is amcosversionid then we don't want the table's value
                 as that would be last year's version so we manually change it to the insertversion */

                IF @mycolumn = 'AmcosVersionId'
                BEGIN
                    SET @selectsql = @selectsql + CAST(@AmcosVersionIdNew AS VARCHAR(6));
                    SET @insertsql = @insertsql + '[' + @mycolumn + ']';

                END;
                ELSE IF
                (
                    SELECT COLUMNPROPERTY(OBJECT_ID(@data_table), @mycolumn, 'IsIdentity')
                ) = 0 --no identify inserts
                BEGIN
                    --PRINT @data_table + @mycolumn + ' is not identify'
                    SET @selectsql = @selectsql + '[' + @mycolumn + ']';
                    SET @insertsql = @insertsql + '[' + @mycolumn + ']';
                END;
                /*ELSE IF (select COLUMNPROPERTY(object_id(@data_table ), @mycolumn ,'IsIdentity')) IS NULL
					BEGIN
						PRINT @data_table + ' ' + @mycolumn + ' IDENTITY CHECK FAILED'
					end
					*/
                ELSE
                    SET @validcolumn = 0;


                FETCH NEXT FROM mycolumns
                INTO @mycolumn;
                SET @innerloop = @@fetch_status;
                /* if there are more columns then we need a comma in the insert statement */
                IF @innerloop = 0
                   AND @validcolumn = 1
                BEGIN
                    SET @selectsql = @selectsql + ',';
                    SET @insertsql = @insertsql + ',';
                END;
            END;
            CLOSE mycolumns;
            DEALLOCATE mycolumns;
            /* finalize the insert by adding the from and where */
            SET @selectsql
                = @selectsql + ' FROM ' + @data_table + ' WHERE AmcosVersionId='
                  + CAST(@AmcosVersionIdPrior AS VARCHAR(6));

            SET @finalsql = @insertsql + ') ' + @selectsql;
            /* run/print the insert statement */
            --IF @Debug = 1
            PRINT @finalsql;
            IF @Debug = 0
                EXEC (@finalsql);

            FETCH NEXT FROM data
            INTO @data_table;
            SET @outerloop = @@fetch_status;
        END;

        CLOSE data;
        DEALLOCATE data;
    END; --end else
END;