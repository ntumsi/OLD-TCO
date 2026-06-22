

-- =============================================
-- Author:		Dan Hogan
-- Create date: 12/21/2021
-- Description:	For each year there is an entry of locality pay, that acronym should also have a corresponding
-- entry in the xwalk table otherwise there will be no zip that applies to it
-- =============================================
CREATE PROCEDURE [test].[FIPSforLocalityExists]
AS
BEGIN
    /*
		EXEC crunch.CalculatePayPlanMinMax @AmcosVersionId = 202101,@debug = 0          
		exec test.minmaxpay @amcosversionid=202101
	*/
    SET NOCOUNT ON;


    DECLARE @AmcosVersionId INT = 194901;
    WHILE @AmcosVersionId < (SELECT MAX(AmcosVersionId)FROM lookup.AMCOSVersion)
    BEGIN
        DROP TABLE IF EXISTS #mytemp;

        SELECT @AmcosVersionId AS myversion,
               *
        INTO #mytemp
        FROM
        (
            SELECT DISTINCT
                   LocalityCode AS XwalkLocalityCode,
                   AmcosVersionId AS XwalkAmcosVersionId
            FROM xwalk.LocalityPayAreaToFips
            WHERE @AmcosVersionId = AmcosVersionId
        ) AS a
            FULL OUTER JOIN
            (
                SELECT *
                FROM PaySchedule.LocalityPay
                WHERE @AmcosVersionId = AmcosVersionId
                      AND LocalityCode <> 'RUS'
            ) AS b
                ON b.LocalityCode = a.XwalkLocalityCode
        WHERE a.XwalkLocalityCode IS NULL
              OR b.LocalityCode IS NULL;
        IF
        (
            SELECT COUNT(*)FROM #mytemp
        ) > 0
        BEGIN
            SELECT *
            FROM #mytemp;
        END;

        SET @AmcosVersionId = @AmcosVersionId + 100;
    END;
END;