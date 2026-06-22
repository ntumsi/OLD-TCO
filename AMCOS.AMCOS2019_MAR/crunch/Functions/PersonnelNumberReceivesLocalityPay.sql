-- ========================================================================================================
--Description:  If any of the following cost elements exist for the personnel number, locality pay should
--				 not be computed
--					Civ Physical Comparability Pay (Market Pay) (6100.11T0)
--					Civ Post Differential Pay (O/S Hardship Post) (6100.11J0)
--					Civ Overseas Allowances (Civ Quarters, COLA, LQA, & Other not classified) (6100.12B0)
-- ========================================================================================================

CREATE FUNCTION crunch.PersonnelNumberReceivesLocalityPay (@PersonnelNumber NVARCHAR(10))
RETURNS BIT
AS
    BEGIN
        DECLARE @Result BIT = 1;

        WITH CostElementsForPersonnelNumber_CTE
        AS (
               SELECT
                   PersonnelNumber,
                   CostElementCode
               FROM
                   load_GFEBS.Processed
               GROUP BY
                   PersonnelNumber,
                   CostElementCode
           )
        SELECT
            @Result = 0
        FROM
            CostElementsForPersonnelNumber_CTE AS a
        WHERE
            EXISTS
            (
                SELECT
                    PersonnelNumber,
                    CostElementCode
                FROM
                    CostElementsForPersonnelNumber_CTE AS b
                WHERE
                    a.PersonnelNumber = b.PersonnelNumber
                    AND b.CostElementCode IN (
                                                 '6100.11T0', '6100.11J0', '6100.12B0'
                                             )
            )
            AND a.PersonnelNumber = @PersonnelNumber;

        RETURN @Result;

    END;