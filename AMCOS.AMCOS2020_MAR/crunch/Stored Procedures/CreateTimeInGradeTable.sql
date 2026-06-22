

-- =============================================
-- Author:Dan Hogan
-- Create date: 10/2/2019
-- Description:	Compute an estimate of the Time in Grade (TIG) by GL for each Pay Plan
-- Because we do not have personnel data over time (the data needed to do this with precision and accuracy) we use
-- inventory data and a Median Yos.  But because a median calculation requires record to be its own row we need to un group
-- the inventory table which is really a frequency table.  This crunch facilitates that
-- =============================================

CREATE PROCEDURE [crunch].[CreateTimeInGradeTable]
    @AmcosVersionId INT = -1,
    @Debug AS BIT = 1
AS
BEGIN
    SET NOCOUNT ON;

    --this table will hold our row (non-frequency) based inventory data
    DROP TABLE IF EXISTS #tempinv;
    CREATE TABLE #tempinv
    (
        AmcosVersionId INT NOT NULL,
        pp NVARCHAR(3) NOT NULL,
        gl INT NOT NULL,
        YOS INT NOT NULL
    );

    -- to transform the inventory frequency table to a row based inventory we need to iterate through it
    DECLARE @MyCursor CURSOR,
            @tableversion AS INT,
            @pp AS NVARCHAR(3),
            @gl AS INT,
            @YOS AS INT,
            @inv AS INT;
    BEGIN
        SET @MyCursor = CURSOR FOR
        SELECT @AmcosVersionId,
               PayPlan,
               GradeLevel,
               --Step,
               YOS,
               SUM(Inventory) AS inventory
        FROM data.Inventory
        WHERE PayPlan IN ( 'AE', 'AO', 'AWO', 'RE', 'RO', 'RWO', 'NE', 'NO', 'NWO' )
              AND YOS <> 99
              AND AmcosVersionId = @AmcosVersionId --and CategorySubgroupCode='18D'
        GROUP BY PayPlan,
                 GradeLevel,
                 --Step,
                 YOS;


        OPEN @MyCursor;
        FETCH NEXT FROM @MyCursor
        INTO @tableversion,
             @pp,
             @gl,
             @YOS,
             @inv;

        WHILE @@FETCH_STATUS = 0
        BEGIN
            DECLARE @i INT;
            SET @i = 1;
            --insert into our new table for each number of people in inventory
            WHILE @i <= @inv
            BEGIN

                INSERT INTO #tempinv
                (
                    AmcosVersionId,
                    pp,
                    gl,
                    YOS
                )
                VALUES
                (@tableversion, @pp, @gl, @YOS);
                SET @i = @i + 1;
            END;
            FETCH NEXT FROM @MyCursor
            INTO @tableversion,
                 @pp,
                 @gl,
                 @YOS,
                 @inv;
        END;

        -- create our table to hold the TIG calculation
        DROP TABLE IF EXISTS #TIG;
        CREATE TABLE #TIG
        (
            AmcosVersionId INT NOT NULL,
            pp NVARCHAR(3) NOT NULL,
            gl INT NOT NULL,
            median NUMERIC(6, 1) NOT NULL,
            myTIG NUMERIC(6, 1) NULL
        );
        -- we are using the median (50th percentile) calculation for YoS by PP and GL
        INSERT INTO #TIG
        (
            AmcosVersionId,
            pp,
            gl,
            median
        )
        SELECT DISTINCT
               AmcosVersionId,
               pp,
               gl,
               PERCENTILE_DISC(.5) WITHIN GROUP(ORDER BY YOS) OVER (PARTITION BY AmcosVersionId, pp, gl) AS median
        FROM #tempinv;


        -- calculate the TIG
        UPDATE #TIG
        SET myTIG = b.mytig
        FROM #TIG AS a
            INNER JOIN
            -- the calculation subtracts the median YoS from the median YoS at the next higher GL to estimate the TIG 
            (
                SELECT AmcosVersionId,
                       pp,
                       gl,
                       median,
                       LEAD(median, 1, 0) OVER (PARTITION BY AmcosVersionId, pp ORDER BY AmcosVersionId, pp, gl)
                       - median AS mytig
                FROM #TIG
            ) AS b
                ON a.AmcosVersionId = b.AmcosVersionId
                   AND a.pp = b.pp
                   AND a.gl = b.gl
                   AND a.median = b.median;

        -- special cases we need to handle
        -- AE folks tend to be an E2/E3 by the end of year 1 so we assume their TIG is .5 each for GL1 & 2
        UPDATE #TIG
        SET myTIG = .5
        WHERE gl IN ( 1, 2 )
              AND pp = 'AE';

        -- AO folks tend to be an O2 after 18 months and O3 after 4 years
        UPDATE #TIG
        SET myTIG = 1.5
        WHERE gl IN ( 1 )
              AND pp = 'AO';
        UPDATE #TIG
        SET myTIG = 4 - 1.5
        WHERE gl IN ( 2 )
              AND pp = 'AO';

        -- Since the math uses the next higher GL we need to do something for the max GLs
        -- for officers use the mandatory retirement age and an assumption on their age at comission
        UPDATE #TIG
        SET myTIG = 62 - 22 - median
        WHERE gl = 10
              AND pp = 'AO';
        -- for enlisted assume they have a 30 year max career
        UPDATE #TIG
        SET myTIG = CASE
                        WHEN median > 30 THEN
                            30
                        ELSE
                            30 - median
                    END
        WHERE gl = 9
              AND pp = 'AE';
        -- for any TIG less than 0 set it to a uniform -1 meaning we don't know what the TIG is/should be
        UPDATE #TIG
        SET myTIG = -1
        WHERE myTIG < 0;

        -- for warrants they spend a lot of time in GL1 and so the usual math won't work so we just use the median YoS
        UPDATE #TIG
        SET myTIG = median
        WHERE gl = 1
              AND pp IN ( 'AWO', 'NWO', 'RWO' );


        IF @Debug = 1
           OR @Debug = 0 --let's show the result regardless 
        BEGIN
            SELECT *
            FROM #TIG
            ORDER BY AmcosVersionId,
                     pp,
                     gl;
        END;

        --insert the table into the crunch table
        IF @Debug = 0
        BEGIN
            DELETE FROM crunch.TimeInGrade
            WHERE AmcosVersionId = @AmcosVersionId;

            INSERT INTO crunch.TimeInGrade
            (
                AmcosVersionId,
                PayPlan,
                GradeLevel,
                MedianYoS,
                TIG
            )
            SELECT AmcosVersionId,
                   pp,
                   gl,
                   median,
                   myTIG
            FROM #TIG;
        END;
    END;

    CLOSE @MyCursor;
    DEALLOCATE @MyCursor;
END;