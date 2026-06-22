CREATE VIEW [quicksight].[PPXwalkLocations]
AS
SELECT *
FROM
(
    --get a list of all active locations as defined by the cost data view used in the qlik ppxwalk app
    SELECT LocationId,
           DisplayName + ' (' + LocationType + ')' AS DisplayName
    FROM warehouse.Location
    WHERE LocationId IN
          (
              SELECT DISTINCT LocationId FROM quicksight.PPXwalkCostData
          )
    UNION
    --add in SES
    SELECT -1,
           'U.S. Wide (SES)' AS DisplayName
) AS a;
--!!! REMOVE ME LATER, I"M FOR TESTING ONLY TO REDUCE THE DATASET SIZE WITH QUICKSIGHT
--where displayname like  '%FORT BELVOIR%'