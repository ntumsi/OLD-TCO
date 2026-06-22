-- =============================================
-- Description:	Delete records for personnel with less than 80 total paid hours.
-- =============================================
CREATE PROCEDURE [dataload].[DeletePersonnelWithLessThan80Hours]
AS
BEGIN
    SET NOCOUNT ON;

    WITH PersonnelNumberWithLessThan80Hours
    AS (SELECT PersonnelNumber,
               SUM(PaidHours) AS TotalHours
        FROM load_GFEBS.Processed
        GROUP BY PersonnelNumber
        HAVING SUM(PaidHours) < 80)
    DELETE FROM load_GFEBS.Processed
    WHERE EXISTS
    (
        SELECT PersonnelNumber
        FROM PersonnelNumberWithLessThan80Hours
        WHERE PersonnelNumberWithLessThan80Hours.PersonnelNumber = Processed.PersonnelNumber
    );

END;