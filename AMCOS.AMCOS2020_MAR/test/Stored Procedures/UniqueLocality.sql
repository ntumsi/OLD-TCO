

-- =============================================
-- Author:		Dan Hogan
-- Create date: 12/21/2021
-- Description:	Each state,county,city combination FIPS code can exist in one and only one year
-- =============================================
CREATE PROCEDURE [test].[UniqueLocality]
AS
BEGIN

    SET NOCOUNT ON;
    DECLARE @AmcosVersionId INT = 194901;
    DROP TABLE IF EXISTS #temptable;
    CREATE TABLE #temptable
    (
        MyYear INT,
        LocalityCode NVARCHAR(6),
        StateCode NVARCHAR(2),
        CountyCode NVARCHAR(3),
        CityCode NVARCHAR(4),
        AmcosVersionId INT,
        MyCount INT
    );
    WHILE @AmcosVersionId < (SELECT MAX(AmcosVersionId)FROM lookup.AMCOSVersion)
    BEGIN
        INSERT INTO #temptable
        (
            MyYear,
            LocalityCode,
            StateCode,
            CountyCode,
            CityCode,
            AmcosVersionId,
            MyCount
        )
        SELECT MyYear,
               a.LocalityCode,
               a.StateCode,
               a.CountyCode,
               a.CityCode,
               a.AmcosVersionId,
               a.MyCount
        FROM
        (
            SELECT @AmcosVersionId AS MyYear,
                   *,
                   COUNT(LocalityCode) OVER (PARTITION BY StateCode, CountyCode, CityCode) AS MyCount
            FROM xwalk.LocalityPayAreaToFips
            WHERE @AmcosVersionId = AmcosVersionId
        ) AS a
        WHERE MyCount > 1;

        SET @AmcosVersionId = @AmcosVersionId + 100;
    END;

    IF
    (
        SELECT COUNT(*)FROM #temptable
    ) > 0
    BEGIN
        SELECT 'these records have two entries for a single year in xwalk.LocalityPayAreaToFips';
        SELECT *
        FROM #temptable
        ORDER BY MyYear,
                 LocalityCode,
                 StateCode,
                 CountyCode,
                 CityCode,
                 AmcosVersionId;
    END;
END;