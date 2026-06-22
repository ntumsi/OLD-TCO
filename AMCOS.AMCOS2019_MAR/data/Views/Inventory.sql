

CREATE VIEW [data].[Inventory]
AS
SELECT PayPlan,
       OccupationalGroupNumber AS CategoryGroupCode,
       OccupationalSeriesNumber AS CategorySubGroupCode,
       NULL AS WageArea,
       NULL AS Quality,
       StateCountry,
       FunctionalAreaCode,
       CostCenterCode,
       GradeType,
       GradeLevel,
       YOS AS Step_YOS,
       Inventory
FROM load_inventory.Inventory_CivilianAcquisition2019
UNION ALL
SELECT PayPlan,
       OccupationalGroupNumber AS CategoryGroupCode,
       OccupationalSeriesNumber AS CategorySubGroupCode,
       NULL AS WageArea,
       NULL AS Quality,
       StateCountry,
       FunctionalAreaCode,
       CostCenterCode,
       GradeType,
       GradeLevel,
       Step AS Step_YOS,
       Inventory
FROM load_inventory.Inventory_CivilianDemonstration2019
UNION ALL
SELECT PayPlan,
       OccupationalGroupNumber AS CategoryGroupCode,
       OccupationalSeriesNumber AS CategorySubGroupCode,
       NULL AS WageArea,
       NULL AS Quality,
       NULL AS StateCountry,
       NULL AS FunctionalAreaCode,
       NULL AS CostCenterCode,
       GradeType,
       GradeLevel,
       Step AS Step_YOS,
       Inventory
FROM load_inventory.Inventory_CivilianGP2019
UNION ALL
SELECT PayPlan,
       OccupationalGroupNumber AS CategoryGroupCode,
       OccupationalSeriesNumber AS CategorySubGroupCode,
       NULL AS WageArea,
       NULL AS Quality,
       NULL AS StateCountry,
       NULL AS FunctionalAreaCode,
       NULL AS CostCenterCode,
       GradeType,
       GradeLevel,
       Step AS Step_YOS,
       SUM(Inventory) AS Inventory
FROM load_inventory.Inventory_CivilianGS
WHERE PayPlan <> 'GP'
GROUP BY PayPlan,
         OccupationalGroupNumber,
         OccupationalSeriesNumber,
         GradeType,
         GradeLevel,
         Step
UNION ALL
SELECT PayPlan,
       OccupationalGroupNumber AS CategoryGroupCode,
       OccupationalSeriesNumber AS CategorySubGroupCode,
       NULL AS WageArea,
       NULL AS Quality,
       NULL AS StateCountry,
       NULL AS FunctionalAreaCode,
       NULL AS CostCenterCode,
       GradeType,
       GradeLevel,
       YOS AS Step_YOS,
       Inventory
FROM load_inventory.Inventory_CivilianSES
UNION ALL
SELECT PayPlan,
       WageArea AS CategoryGroupCode,
       WageArea AS CategorySubGroupCode,
       WageArea,
       NULL AS Quality,
       NULL AS StateCountry,
       NULL AS FunctionalAreaCode,
       NULL AS CostCenterCode,
       GradeType,
       GradeLevel,
       Step AS Step_YOS,
       SUM(Inventory)
FROM load_inventory.Inventory_CivilianWage
GROUP BY PayPlan,
         WageArea,
         GradeType,
         GradeLevel,
         Step
UNION ALL
SELECT PayPlan,
       CMF AS CategoryGroupCode,
       MOS AS CategorySubGroupCode,
       NULL AS WageArea,
       Quality,
       NULL AS StateCountry,
       NULL AS FunctionalAreaCode,
       NULL AS CostCenterCode,
       GradeType,
       GradeLevel,
       YOS AS Step_YOS,
       Inventory
FROM load_inventory.Inventory_Military_Enlisted
UNION ALL
SELECT PayPlan,
       BranchFA AS CategoryGroupCode,
       AOC AS CategorySubGroupCode,
       NULL AS WageArea,
       Quality,
       NULL AS StateCountry,
       NULL AS FunctionalAreaCode,
       NULL AS CostCenterCode,
       GradeType,
       GradeLevel,
       YOS AS Step_YOS,
       Inventory
FROM load_inventory.Inventory_Military_Officer
UNION ALL
SELECT PayPlan,
       Branch AS CategoryGroupCode,
       WOMOS AS CategorySubGroupCode,
       NULL AS WageArea,
       Quality,
       NULL AS StateCountry,
       NULL AS FunctionalAreaCode,
       NULL AS CostCenterCode,
       GradeType,
       GradeLevel,
       YOS AS Step_YOS,
       Inventory
FROM load_inventory.Inventory_Military_Warrant;