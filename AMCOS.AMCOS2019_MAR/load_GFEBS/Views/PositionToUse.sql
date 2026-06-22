CREATE VIEW load_GFEBS.PositionToUse
AS
WITH TotalAmountPaidForPersonnelNumberByPosition_CTE
AS (
   SELECT Raw.PersonnelNumber,
          Raw.FunctionalAreaCode,
          Raw.CostCenterCode,
          SUM(Raw.AmountPaid) AS AmountPaid
   FROM load_GFEBS.Raw Raw
       INNER JOIN load_GFEBS.PersonnelNumberWithMultiplePositions Personnel
           ON Personnel.PersonnelNumber = Raw.PersonnelNumber
   GROUP BY Raw.PersonnelNumber,
            Raw.FunctionalAreaCode,
            Raw.CostCenterCode)
SELECT TotalAmountPaidForPersonnelNumberByPosition_CTE.PersonnelNumber,
       MAX(TotalAmountPaidForPersonnelNumberByPosition_CTE.AmountPaid) AS AmountPaid
FROM TotalAmountPaidForPersonnelNumberByPosition_CTE
GROUP BY TotalAmountPaidForPersonnelNumberByPosition_CTE.PersonnelNumber;