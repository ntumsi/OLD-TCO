
CREATE VIEW [load_GFEBS].[MultiplePositionsByPersonnelNumber]
AS
SELECT Raw.PersonnelNumber,
       Raw.FunctionalAreaCode,
       Raw.CostCenterCode,
       SUM(Raw.AmountPaid) AS AmountPaid
FROM load_GFEBS.Raw Raw
    INNER JOIN load_GFEBS.PersonnelNumberWithMultiplePositions Personnel
        ON Personnel.PersonnelNumber = Raw.PersonnelNumber
GROUP BY Raw.PersonnelNumber,
         Raw.FunctionalAreaCode,
         Raw.CostCenterCode;