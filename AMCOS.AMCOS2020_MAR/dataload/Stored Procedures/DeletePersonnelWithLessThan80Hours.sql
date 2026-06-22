-- =============================================
-- Description:	Delete records for personnel with less than 80 total paid hours.
-- =============================================
CREATE PROCEDURE [dataload].[DeletePersonnelWithLessThan80Hours] @AmcosVersionId INT
AS
BEGIN
    SET NOCOUNT ON;

    WITH PersonnelNumberWithLessThan80Hours
    AS (SELECT PersonnelNumber,
               SUM(PaidHours) AS TotalHours
        FROM load_GFEBS.Cleaned
        WHERE PayPlan NOT IN ( 'EE', 'EF' ) and AmcosVersionId = @AmcosVersionId
        GROUP BY PersonnelNumber
        HAVING SUM(PaidHours) < 80)
    DELETE FROM load_GFEBS.Cleaned
    WHERE AmcosVersionId = @AmcosVersionId
          AND EXISTS
    (
        SELECT PersonnelNumber
        FROM PersonnelNumberWithLessThan80Hours
        WHERE PersonnelNumberWithLessThan80Hours.PersonnelNumber = Cleaned.PersonnelNumber
    );
END;